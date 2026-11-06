import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Length of the database key: 256 bits.
const int kStoreKeyBytes = 32;

/// Holds the key that encrypts the on-device database. The key never leaves
/// the device and is never written into the database file or the app.
abstract interface class StoreKeyVault {
  /// The saved key, or null when none has been saved yet.
  Future<Uint8List?> read();

  Future<void> write(Uint8List key);
}

/// Why the local database was not opened, in words for the user.
class StoreOpenError implements Exception {
  const StoreOpenError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The encrypted database exists, but its key is gone (for example after the
/// system keystore was reset, or the file was restored onto another device).
/// The data is left untouched: it cannot be read, and is never overwritten.
class StoreKeyMissingError extends StoreOpenError {
  const StoreKeyMissingError()
    : super(
        'The key for the encrypted local database is missing from this '
        "device's keystore, so the stored data cannot be read. It has been "
        'left untouched.',
      );
}

/// A new random key from the platform's cryptographically secure generator.
Uint8List generateStoreKey([Random? random]) {
  final rng = random ?? Random.secure();
  return Uint8List.fromList(
    List<int>.generate(kStoreKeyBytes, (_) => rng.nextInt(256)),
  );
}

String encodeStoreKey(Uint8List key) {
  _checkLength(key.length);
  return [for (final b in key) b.toRadixString(16).padLeft(2, '0')].join();
}

Uint8List decodeStoreKey(String hex) {
  if (!RegExp(r'^[0-9a-f]*$').hasMatch(hex) || hex.length.isOdd) {
    throw const FormatException('The saved storage key is malformed.');
  }
  _checkLength(hex.length ~/ 2);
  return Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}

void _checkLength(int bytes) {
  if (bytes != kStoreKeyBytes) {
    throw FormatException(
      'A storage key has $kStoreKeyBytes bytes, not $bytes.',
    );
  }
}

/// The key for a database: the saved one, or for a database that does not
/// exist yet, a new one that is saved first and read back, so data is never
/// encrypted with a key the keystore did not keep.
Future<Uint8List> obtainStoreKey(
  StoreKeyVault vault, {
  required bool encryptedDatabaseExists,
}) async {
  final saved = await vault.read();
  if (saved != null) return saved;
  if (encryptedDatabaseExists) throw const StoreKeyMissingError();
  final key = generateStoreKey();
  await vault.write(key);
  final kept = await vault.read();
  if (kept == null || !_equal(kept, key)) {
    throw const StoreOpenError(
      "This device's keystore did not keep the storage key, so the local "
      'database was not created.',
    );
  }
  return key;
}

bool _equal(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// The system keystore: Keychain on iOS and macOS, a Keystore-protected
/// store on Android, DPAPI on Windows and libsecret on Linux.
class SecureStoreKeyVault implements StoreKeyVault {
  SecureStoreKeyVault([FlutterSecureStorage? storage])
    : _storage = storage ?? _defaultStorage;

  static const String entryName = 'rakia.store.key.v1';

  static const FlutterSecureStorage _defaultStorage = FlutterSecureStorage(
    // Never erase the entry on a read error: that would lose the data the
    // key protects. An error surfaces as unavailable storage instead.
    aOptions: AndroidOptions(resetOnError: false, migrateWithBackup: true),
    // Readable once the device has been unlocked after a restart, never
    // synchronised to iCloud or restored onto another device.
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    // The login keychain, which needs no signing entitlement.
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      usesDataProtectionKeychain: false,
    ),
  );

  final FlutterSecureStorage _storage;

  @override
  Future<Uint8List?> read() async {
    final hex = await _storage.read(key: entryName);
    return hex == null ? null : decodeStoreKey(hex);
  }

  @override
  Future<void> write(Uint8List key) =>
      _storage.write(key: entryName, value: encodeStoreKey(key));
}
