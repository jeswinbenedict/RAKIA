// Encryption at rest of the native store: the file on disk is ciphertext,
// the key comes from the keystore and is never replaced, a wrong or missing
// key leaves the data untouched, and a database written before encryption
// is encrypted in place without losing anything.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakia/simulation/simulated_mission.dart';
import 'package:rakia/storage/database.dart';
import 'package:rakia/storage/db_file.dart';
import 'package:rakia/storage/local_store.dart';
import 'package:rakia/storage/native_store_io.dart';
import 'package:rakia/storage/store_key.dart';
import 'package:rakia_core/rakia_core.dart';

/// A keystore kept in memory. [keeps] false models one that accepts a write
/// but does not retain it.
class MemoryVault implements StoreKeyVault {
  MemoryVault({this.keeps = true});

  final bool keeps;
  Uint8List? key;
  int writes = 0;

  @override
  Future<Uint8List?> read() async => key;

  @override
  Future<void> write(Uint8List value) async {
    writes++;
    if (keeps) key = Uint8List.fromList(value);
  }
}

void main() {
  late RakiaCore core;
  late Directory tmp;
  var n = 0;

  setUpAll(() async {
    core = await loadRakiaCore();
    tmp = await Directory.systemTemp.createTemp('rakia_encryption_test');
  });
  tearDownAll(() => tmp.delete(recursive: true));

  String newPath() => '${tmp.path}${Platform.pathSeparator}db${n++}.sqlite';

  Future<List<int>> header(String path) async =>
      (await File(path).readAsBytes()).sublist(0, 16);

  Matcher failsWith(String text) => throwsA(
    isA<StoreOpenError>().having((e) => e.message, 'message', contains(text)),
  );

  test(
    'a new database is encrypted on disk with a key from the keystore',
    () async {
      final path = newPath();
      final vault = MemoryVault();
      final store = await openNativeStore(path: path, vault: vault);
      final saved = await store.saveSimulation(
        SimulatedMission.generate(),
        core,
      );
      expect(store.encryption.encrypted, isTrue);
      expect(store.encryption.cipher, 'chacha20');
      expect(store.encryption.label, 'ChaCha20-Poly1305');
      await store.close();

      expect(vault.key, hasLength(kStoreKeyBytes));
      expect(vault.writes, 1);
      final bytes = await File(path).readAsBytes();
      expect(classifyDatabaseHeader(bytes), DatabaseFileState.encrypted);
      // Neither the schema nor stored text appears in the file.
      final raw = String.fromCharCodes(bytes);
      expect(raw, isNot(contains('CREATE TABLE')));
      expect(raw, isNot(contains(saved.missionId)));

      final reopened = await openNativeStore(path: path, vault: vault);
      expect(
        vault.writes,
        1,
        reason: 'the saved key is reused, never replaced',
      );
      final back = await reopened.activeSimulation();
      expect(back?.missionId, saved.missionId);
      expect(
        (await reopened.verifyLedger(saved.missionId, core)).verified,
        isTrue,
      );
      await reopened.close();
    },
  );

  test('a wrong key is rejected and the file is left untouched', () async {
    final path = newPath();
    final store = await openNativeStore(path: path, vault: MemoryVault());
    await store.saveSimulation(SimulatedMission.generate(), core);
    await store.close();
    final before = await File(path).readAsBytes();

    final other = MemoryVault()..key = generateStoreKey();
    await expectLater(
      openNativeStore(path: path, vault: other),
      failsWith('could not be decrypted'),
    );
    expect(await File(path).readAsBytes(), before);
    expect(other.writes, 0);
  });

  test('a missing key is reported and no new key replaces it', () async {
    final path = newPath();
    final store = await openNativeStore(path: path, vault: MemoryVault());
    await store.close();
    final before = await File(path).readAsBytes();

    final empty = MemoryVault();
    await expectLater(
      openNativeStore(path: path, vault: empty),
      throwsA(isA<StoreKeyMissingError>()),
    );
    expect(empty.writes, 0);
    expect(empty.key, isNull);
    expect(await File(path).readAsBytes(), before);
  });

  test('nothing is created when the keystore does not keep the key', () async {
    final path = newPath();
    await expectLater(
      openNativeStore(path: path, vault: MemoryVault(keeps: false)),
      failsWith('did not keep the storage key'),
    );
    expect(File(path).existsSync(), isFalse);
  });

  test(
    'a malformed saved key is an error, not a reason to replace it',
    () async {
      final path = newPath();
      final vault = _BrokenVault();
      await expectLater(
        openNativeStore(path: path, vault: vault),
        throwsA(isA<FormatException>()),
      );
      expect(vault.writes, 0);
      expect(File(path).existsSync(), isFalse);
    },
  );

  test('a database written before encryption is encrypted in place', () async {
    final path = newPath();
    final plain = LocalStore(
      RakiaDatabase(NativeDatabase(File(path))),
      kind: StorageKind.nativeFile,
    );
    final saved = await plain.saveSimulation(SimulatedMission.generate(), core);
    await plain.setSetting('theme_mode', 'light');
    expect(plain.encryption.encrypted, isFalse);
    await plain.close();
    expect(
      classifyDatabaseHeader(await header(path)),
      DatabaseFileState.plaintext,
    );

    final vault = MemoryVault();
    final store = await openNativeStore(path: path, vault: vault);
    expect(store.encryption.encrypted, isTrue);
    expect(
      classifyDatabaseHeader(await header(path)),
      DatabaseFileState.encrypted,
    );
    expect(await store.setting('theme_mode'), 'light');
    expect(await store.recordCount(saved.missionId), saved.records);
    expect((await store.verifyLedger(saved.missionId, core)).verified, isTrue);
    await store.close();

    // Later launches open it as an encrypted database with the same key.
    final again = await openNativeStore(path: path, vault: vault);
    expect(await again.recordCount(saved.missionId), saved.records);
    await again.close();
    expect(vault.writes, 1);
  });

  group('keys', () {
    test('are 256 bits from a secure generator and differ each time', () {
      final a = generateStoreKey();
      final b = generateStoreKey();
      expect(a, hasLength(32));
      expect(a, isNot(b));
    });

    test('round-trip through their saved text form', () {
      final key = generateStoreKey(Random(7));
      final hex = encodeStoreKey(key);
      expect(hex, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(decodeStoreKey(hex), key);
    });

    test('of the wrong length or form are rejected', () {
      expect(() => decodeStoreKey('ab' * 16), throwsFormatException);
      expect(() => decodeStoreKey('zz' * 32), throwsFormatException);
      expect(() => decodeStoreKey('AB' * 32), throwsFormatException);
      expect(() => encodeStoreKey(Uint8List(16)), throwsFormatException);
    });
  });

  test('file headers are classified', () {
    expect(classifyDatabaseHeader(const []), DatabaseFileState.absent);
    expect(
      classifyDatabaseHeader('SQLite format 3\x00rest'.codeUnits),
      DatabaseFileState.plaintext,
    );
    expect(
      classifyDatabaseHeader(List.filled(16, 0xa5)),
      DatabaseFileState.encrypted,
    );
  });
}

class _BrokenVault implements StoreKeyVault {
  int writes = 0;

  @override
  Future<Uint8List?> read() async => decodeStoreKey('not a key');

  @override
  Future<void> write(Uint8List key) async => writes++;
}
