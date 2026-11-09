import 'local_store.dart';
import 'memory_store_io.dart'
    if (dart.library.js_interop) 'memory_store_web.dart'
    as impl;

/// A fresh SQLite database that lives only in memory, with the production
/// schema and triggers. Used for the session when persistent storage cannot
/// be opened, so features keep working and say that nothing will be kept.
Future<LocalStore> openMemoryStore() => impl.openMemoryStore();
