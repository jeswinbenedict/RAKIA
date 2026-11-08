// Schema migrations of the on-device store, against the exported schema of
// every released version (drift_schemas/, test/generated_migrations/).
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart' show SqliteException;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakia/storage/database.dart';
import 'package:rakia/storage/local_store.dart';

import 'generated_migrations/schema.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('every version upgrades to the current schema exactly', () async {
    for (var from = 1; from < RakiaDatabase.currentSchemaVersion; from++) {
      final connection = await verifier.startAt(from);
      final db = RakiaDatabase(connection);
      await verifier.migrateAndValidate(db, RakiaDatabase.currentSchemaVersion);
      await db.close();
    }
  });

  test('upgrading from version 1 keeps existing data and adds the '
      'wellbeing tables with their rules', () async {
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase.execute(
      "INSERT INTO settings (\"key\", value) VALUES ('theme_mode', 'light')",
    );

    final db = RakiaDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 2);
    final store = LocalStore(db, kind: StorageKind.memory);
    expect(await store.setting('theme_mode'), 'light');

    await store.addCheckIn(sleepiness: 4, stress: 2, mood: 4);
    expect(await store.checkIns(), hasLength(1));
    await expectLater(
      db.customStatement('UPDATE self_checkins SET mood = 1'),
      throwsA(isA<SqliteException>()),
    );
    await store.close();
  });

  test('a database from a newer build is refused, not reinterpreted', () async {
    final schema = await verifier.schemaAt(2);
    schema.rawDatabase.execute('PRAGMA user_version = 99');
    final db = RakiaDatabase(schema.newConnection());
    await expectLater(
      db.customSelect('SELECT 1').get(),
      throwsA(isA<UnsupportedError>()),
    );
    await db.close();
  });
}
