import 'dart:typed_data';

import 'package:sqlite3/common.dart';

import 'store_key.dart';

/// Raised when the key does not decrypt the file. Unlocking runs in the
/// database's isolate, so the error may arrive as text; it is recognised by
/// this message.
const String kKeyRejectedMessage =
    "The local database could not be decrypted with this device's key. It "
    'has been left untouched.';

/// Raised when the loaded SQLite cannot encrypt.
const String kNoCipherMessage =
    'This SQLite build has no encryption support, so the local database was '
    'not opened.';

/// Unlocks [db] with [key] before anything else touches it. With
/// [encryptExisting], [db] is an unencrypted database that is encrypted in
/// place first. Runs in the database's isolate, on every native open.
void unlockDatabase(
  CommonDatabase db,
  Uint8List key, {
  required bool encryptExisting,
}) {
  // Plain SQLite ignores unknown pragmas, so `key` alone would silently
  // leave the file unencrypted. Refuse to continue without a cipher.
  if (db.select('PRAGMA cipher').isEmpty) {
    throw const StoreOpenError(kNoCipherMessage);
  }
  // The literal is built from hex digits only, so it cannot break out of
  // the statement. Pragmas take no bound parameters.
  final literal = "\"x'${encodeStoreKey(key)}'\"";
  db.execute('PRAGMA ${encryptExisting ? 'rekey' : 'key'} = $literal');
  try {
    // A wrong key only shows on the first read of the file.
    db.select('SELECT count(*) FROM sqlite_schema');
  } on SqliteException catch (e) {
    if (e.resultCode == 26) {
      throw const StoreOpenError(kKeyRejectedMessage);
    }
    rethrow;
  }
}
