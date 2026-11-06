import 'dart:io';

import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import 'cipher.dart';
import 'database.dart';
import 'db_file.dart';
import 'local_store.dart';
import 'store_key.dart';

/// The database file in the app's private support directory (not the
/// documents folder, which some systems sync to the cloud).
Future<String> nativeDatabasePath() async {
  final dir = await getApplicationSupportDirectory();
  return '${dir.path}${Platform.pathSeparator}rakia.sqlite';
}

Future<DatabaseFileState> databaseFileState(String path) async {
  final file = File(path);
  if (!await file.exists()) return DatabaseFileState.absent;
  final raf = await file.open();
  try {
    return classifyDatabaseHeader(
      await raf.read(kSqlitePlaintextHeader.length),
    );
  } finally {
    await raf.close();
  }
}

/// Opens the encrypted database at [path] with the key from [vault],
/// encrypting a database left unencrypted by an earlier version in place.
Future<LocalStore> openNativeStore({
  required String path,
  required StoreKeyVault vault,
}) async {
  final before = await databaseFileState(path);
  final key = await obtainStoreKey(
    vault,
    encryptedDatabaseExists: before == DatabaseFileState.encrypted,
  );
  final encryptExisting = before == DatabaseFileState.plaintext;
  final db = RakiaDatabase(
    // A background isolate keeps database work off the UI thread. Temporary
    // tables live in memory (the bundled SQLite is built with
    // SQLITE_TEMP_STORE=2), so nothing unencrypted is spilled to disk.
    NativeDatabase.createInBackground(
      File(path),
      setup: (raw) =>
          unlockDatabase(raw, key, encryptExisting: encryptExisting),
    ),
  );
  try {
    // Opening is lazy; run a query so unlocking and migrations happen (and
    // fail) here.
    final cipher = await db.customSelect('PRAGMA cipher').getSingleOrNull();
    final after = await databaseFileState(path);
    if (cipher == null || after != DatabaseFileState.encrypted) {
      throw const StoreOpenError(
        'The local database is not encrypted on disk, so it was closed.',
      );
    }
    return LocalStore(
      db,
      kind: StorageKind.nativeFile,
      encryption: StoreEncryption.cipher(cipher.data.values.first as String),
    );
  } on Object catch (e) {
    await db.close();
    // Errors from the database isolate arrive wrapped; restore the plain
    // message for the ones meant for the user.
    final text = '$e';
    for (final message in [kKeyRejectedMessage, kNoCipherMessage]) {
      if (text.contains(message)) throw StoreOpenError(message);
    }
    rethrow;
  }
}
