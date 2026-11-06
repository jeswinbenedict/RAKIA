// The migration files and runner: numbering, a clean round trip, and
// refusal to run over an edited or unknown migration.
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:rakia_db/rakia_db.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('migration files', () {
    test('are numbered without gaps and each can be reverted', () {
      final all = migrations;
      expect(all, isNotEmpty);
      for (var i = 0; i < all.length; i++) {
        expect(all[i].version, i + 1);
        expect(all[i].down.trim(), isNotEmpty);
      }
    });

    test('checksums ignore line endings', () {
      final lf = Migration(version: 1, name: 'x', up: 'a\nb\n', down: '');
      final crlf = Migration(version: 1, name: 'x', up: 'a\r\nb\r\n', down: '');
      expect(lf.checksum, crlf.checksum);
    });

    test('a gap in the numbering is refused', () {
      final dir = Directory.systemTemp.createTempSync('rakia_migrations');
      addTearDown(() => dir.deleteSync(recursive: true));
      for (final f in [
        '0001_a.up.sql',
        '0001_a.down.sql',
        '0003_c.up.sql',
        '0003_c.down.sql',
      ]) {
        File('${dir.path}/$f').writeAsStringSync('SELECT 1;');
      }
      expect(() => loadMigrations(dir), throwsA(isA<MigrationError>()));
    });

    test('a migration without a down script is refused', () {
      final dir = Directory.systemTemp.createTempSync('rakia_migrations');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/0001_a.up.sql').writeAsStringSync('SELECT 1;');
      expect(() => loadMigrations(dir), throwsA(isA<MigrationError>()));
    });
  });

  group('runner', skip: skipReason, () {
    late Connection migrator;

    setUpAll(() async => migrator = await migratorConfig.open());
    tearDownAll(() async {
      await resetSchema(migrator);
      await migrator.close();
    });

    Future<List<String>> rakiaTables() async => [
      for (final r in await migrator.execute(
        "SELECT tablename FROM pg_tables WHERE schemaname = 'rakia' ORDER BY 1",
      ))
        r[0]! as String,
    ];

    test('down then up is a clean round trip', () async {
      final m = Migrator(migrator, migrations, log: (_) {});
      await m.up();
      expect(await rakiaTables(), contains('measurements'));
      await m.down(steps: migrations.length);
      expect(await rakiaTables(), ['schema_migrations']);
      final types = await migrator.execute(
        'SELECT count(*) FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace '
        "WHERE n.nspname = 'rakia' AND t.typtype = 'e'",
      );
      expect(types.single.single, 0);
      expect(await m.up(), migrations.length);
      expect(await m.up(), 0);
      expect((await m.status()).length, migrations.length);
    });

    test('an applied migration that was edited stops the runner', () async {
      final edited = [
        Migration(
          version: 1,
          name: migrations.first.name,
          up: '${migrations.first.up}\n-- edited',
          down: migrations.first.down,
        ),
        ...migrations.skip(1),
      ];
      final m = Migrator(migrator, edited, log: (_) {});
      await expectLater(
        m.status(),
        throwsA(
          isA<MigrationError>().having(
            (e) => e.message,
            'message',
            contains('changed after it was applied'),
          ),
        ),
      );
      await expectLater(m.up(), throwsA(isA<MigrationError>()));
    });

    test('a database ahead of the checkout stops the runner', () async {
      final m = Migrator(migrator, const [], log: (_) {});
      await expectLater(
        m.status(),
        throwsA(
          isA<MigrationError>().having(
            (e) => e.message,
            'message',
            contains('not in this checkout'),
          ),
        ),
      );
    });
  });
}
