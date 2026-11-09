import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';

import 'local_store.dart';
import 'open_store.dart';

/// SQLite WebAssembly on the page's own thread, in memory: independent of
/// the storage worker, so it works even when that worker does not answer.
Future<LocalStore> openMemoryStore() async {
  final sqlite3 = await WasmSqlite3.loadFromUrl(kSqliteWasmUri);
  // SQLite needs a file system even for an in-memory database.
  sqlite3.registerVirtualFileSystem(InMemoryFileSystem(), makeDefault: true);
  return memoryStore(WasmDatabase.inMemory(sqlite3));
}
