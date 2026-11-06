import 'local_store.dart';
import 'store_key.dart';

// Browsers have no native database file; see open_store.dart.

Future<String> nativeDatabasePath() =>
    throw UnsupportedError('No native database file in a browser.');

Future<LocalStore> openNativeStore({
  required String path,
  required StoreKeyVault vault,
}) => throw UnsupportedError('No native database file in a browser.');
