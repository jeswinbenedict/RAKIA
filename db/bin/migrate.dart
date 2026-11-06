// Applies or reverts RAKIA's database migrations as rakia_migrator, with the
// connection settings from the repository's .env (written by
// db/bootstrap/bootstrap-local.ps1 or .sh) or the process environment.
//
// Usage (from db/):
//   dart run bin/migrate.dart status
//   dart run bin/migrate.dart up [--to N]
//   dart run bin/migrate.dart down [--steps N]
//   options: --env-file PATH (default ../.env)
import 'dart:io';

import 'package:postgres/postgres.dart' show ServerException;
import 'package:rakia_db/rakia_db.dart';

Future<void> main(List<String> args) async {
  final here = File.fromUri(Platform.script).parent.parent;
  var envPath = '${here.parent.path}${Platform.pathSeparator}.env';
  int? to;
  var steps = 1;
  String? command;
  try {
    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--env-file':
          envPath = args[++i];
        case '--to':
          to = int.parse(args[++i]);
        case '--steps':
          steps = int.parse(args[++i]);
        case 'status' || 'up' || 'down' when command == null:
          command = args[i];
        default:
          throw FormatException('Unexpected argument: ${args[i]}');
      }
    }
    if (command == null) throw const FormatException('Missing command');
  } on Object catch (e) {
    stderr
      ..writeln(e)
      ..writeln(
        'Usage: dart run bin/migrate.dart status | up [--to N] | down '
        '[--steps N]  [--env-file PATH]',
      );
    exitCode = 64;
    return;
  }

  try {
    final config = DbConfig.fromEnvironment(envFile: readEnvFile(envPath));
    final migrations = loadMigrations(
      Directory('${here.path}${Platform.pathSeparator}migrations'),
    );
    final conn = await config.open();
    try {
      final migrator = Migrator(conn, migrations);
      switch (command) {
        case 'status':
          final applied = await migrator.status();
          for (final m in migrations) {
            final a = applied.where((a) => a.version == m.version).firstOrNull;
            stdout.writeln(
              '${a == null ? 'pending' : 'applied'}  ${m.label}'
              '${a == null ? '' : '  ${a.appliedAt.toUtc().toIso8601String()}'}',
            );
          }
        case 'up':
          final n = await migrator.up(target: to);
          stdout.writeln(n == 0 ? 'Up to date.' : 'Applied $n.');
        case 'down':
          final n = await migrator.down(steps: steps);
          stdout.writeln(n == 0 ? 'Nothing to revert.' : 'Reverted $n.');
      }
    } finally {
      await conn.close();
    }
  } on MigrationError catch (e) {
    stderr.writeln(e);
    exitCode = 1;
  } on StateError catch (e) {
    stderr.writeln(e.message);
    exitCode = 1;
  } on ServerException catch (e) {
    stderr.writeln('PostgreSQL: ${e.message}');
    exitCode = 1;
  }
}
