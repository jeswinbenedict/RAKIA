// Entry point of the web worker that hosts the local SQLite database in a
// browser. Compiled by tool/build_web_sqlite.sh from the locked `drift` and
// `sqlite3` packages, so it always matches the sqlite3.wasm fetched there.
import 'package:drift/wasm.dart';

void main() => WasmDatabase.workerMainForOpen();
