import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'database.dart';
import 'local_store.dart';

/// Web assets fetched by tool/fetch_web_sqlite.sh, served next to the app.
/// Resolved against the page: the worker would otherwise resolve a relative
/// module URL against its own location.
Uri get kSqliteWasmUri => Uri.base.resolve('sqlite3/sqlite3.wasm');
Uri get kDriftWorkerUri => Uri.base.resolve('sqlite3/drift_worker.js');

/// Opens the platform's persistent store: a SQLite file in the app's private
/// support directory on native targets (not the documents folder, which some
/// systems sync to the cloud), or SQLite WebAssembly on OPFS or IndexedDB in
/// a browser.
Future<LocalStore> openLocalStore() async {
  var kind = kIsWeb ? StorageKind.memory : StorageKind.nativeFile;
  final db = RakiaDatabase(
    driftDatabase(
      name: 'rakia',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
      web: DriftWebOptions(
        sqlite3Wasm: kSqliteWasmUri,
        driftWorker: kDriftWorkerUri,
        onResult: (result) {
          kind = switch (result.chosenImplementation.storageApi) {
            WebStorageApi.opfs => StorageKind.browserOpfs,
            WebStorageApi.indexedDb => StorageKind.browserIndexedDb,
            null => StorageKind.memory,
          };
        },
      ),
    ),
  );
  try {
    // Opening is lazy; run a query so migrations happen (and fail) here.
    await db.customSelect('SELECT 1').get();
  } on Object {
    await db.close();
    rethrow;
  }
  return LocalStore(db, kind: kind);
}

/// An empty store that lives only in memory, over [executor].
LocalStore memoryStore(QueryExecutor executor) =>
    LocalStore(RakiaDatabase(executor), kind: StorageKind.memory);
