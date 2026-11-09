import 'package:drift/native.dart';

import 'local_store.dart';
import 'open_store.dart';

Future<LocalStore> openMemoryStore() async =>
    memoryStore(NativeDatabase.memory());
