import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';

/// One numbered migration: `NNNN_name.up.sql` and `NNNN_name.down.sql`.
class Migration {
  Migration({
    required this.version,
    required this.name,
    required this.up,
    required this.down,
  });

  final int version;
  final String name;
  final String up;
  final String down;

  /// SHA-256 of the up script with line endings normalised, so a checkout
  /// with CRLF endings has the same checksum.
  late final String checksum = sha256
      .convert(utf8.encode(up.replaceAll('\r\n', '\n')))
      .toString();

  String get label => '${version.toString().padLeft(4, '0')}_$name';
}

class MigrationError implements Exception {
  const MigrationError(this.message);
  final String message;
  @override
  String toString() => message;
}

final _file = RegExp(r'^(\d{4})_([a-z0-9_]+)\.(up|down)\.sql$');

/// Loads the migrations in [dir], numbered 0001, 0002, ... without gaps,
/// each with both an up and a down script.
List<Migration> loadMigrations(Directory dir) {
  final parts = <int, Map<String, String>>{};
  final names = <int, String>{};
  for (final f in dir.listSync().whereType<File>()) {
    final base = f.uri.pathSegments.last;
    final m = _file.firstMatch(base);
    if (m == null) {
      if (base.endsWith('.sql')) {
        throw MigrationError('Unexpected file name: $base');
      }
      continue;
    }
    final version = int.parse(m[1]!);
    if (names[version] case final n? when n != m[2]) {
      throw MigrationError('Migration $version has two names: $n and ${m[2]}');
    }
    names[version] = m[2]!;
    (parts[version] ??= {})[m[3]!] = f.readAsStringSync();
  }
  final versions = parts.keys.toList()..sort();
  for (var i = 0; i < versions.length; i++) {
    if (versions[i] != i + 1) {
      throw MigrationError(
        'Migrations must be numbered from 0001 without gaps',
      );
    }
    final p = parts[versions[i]]!;
    if (p['up'] == null || p['down'] == null) {
      throw MigrationError(
        'Migration ${versions[i]} needs both an up and a down script',
      );
    }
  }
  return [
    for (final v in versions)
      Migration(
        version: v,
        name: names[v]!,
        up: parts[v]!['up']!,
        down: parts[v]!['down']!,
      ),
  ];
}

class AppliedMigration {
  const AppliedMigration(
    this.version,
    this.name,
    this.checksum,
    this.appliedAt,
  );
  final int version;
  final String name;
  final String checksum;
  final DateTime appliedAt;
}

/// Applies and reverts [migrations] on a connection made as the migrator.
/// Each migration runs in its own transaction, under an advisory lock so two
/// runners never interleave. A migration that was changed after it was
/// applied, or an applied one with no script, stops everything.
class Migrator {
  Migrator(this.conn, this.migrations, {this.log = _print});

  final Connection conn;
  final List<Migration> migrations;
  final void Function(String) log;

  static void _print(String line) => stdout.writeln(line);

  static const _lockKey = 'rakia.schema_migrations';

  Future<void> _ensureTable(Session s) async {
    await s.execute('''
      CREATE TABLE IF NOT EXISTS rakia.schema_migrations (
        version    integer PRIMARY KEY CHECK (version > 0),
        name       text NOT NULL,
        checksum   text NOT NULL CHECK (checksum ~ '^[0-9a-f]{64}\$'),
        applied_at timestamptz NOT NULL DEFAULT now()
      )''');
  }

  Future<List<AppliedMigration>> _applied(Session s) async {
    final rows = await s.execute(
      'SELECT version, name, checksum, applied_at FROM rakia.schema_migrations '
      'ORDER BY version',
    );
    return [
      for (final r in rows)
        AppliedMigration(
          r[0]! as int,
          r[1]! as String,
          r[2]! as String,
          r[3]! as DateTime,
        ),
    ];
  }

  void _check(List<AppliedMigration> applied) {
    for (final a in applied) {
      if (a.version > migrations.length) {
        throw MigrationError(
          'The database has migration ${a.version} (${a.name}), which is not '
          'in this checkout. Update your checkout first.',
        );
      }
      final m = migrations[a.version - 1];
      if (m.checksum != a.checksum) {
        throw MigrationError(
          'Migration ${m.label} was changed after it was applied. Never edit '
          'an applied migration; add a new one.',
        );
      }
    }
  }

  Future<T> _locked<T>(Future<T> Function(TxSession tx) body) =>
      conn.runTx((tx) async {
        await tx.execute(
          Sql.named('SELECT pg_advisory_xact_lock(hashtext(@k))'),
          parameters: {'k': _lockKey},
        );
        await _ensureTable(tx);
        return body(tx);
      });

  /// Applied migrations, after checking them against the scripts.
  Future<List<AppliedMigration>> status() => _locked((tx) async {
    final applied = await _applied(tx);
    _check(applied);
    return applied;
  });

  /// Applies pending migrations, up to [target] (default: all). Returns how
  /// many were applied.
  Future<int> up({int? target}) async {
    final goal = target ?? migrations.length;
    if (goal < 0 || goal > migrations.length) {
      throw MigrationError('No migration $goal');
    }
    var count = 0;
    while (true) {
      final done = await _locked((tx) async {
        final applied = await _applied(tx);
        _check(applied);
        if (applied.length >= goal) return true;
        final m = migrations[applied.length];
        log('apply  ${m.label}');
        await tx.execute(m.up, queryMode: QueryMode.simple);
        await tx.execute(
          Sql.named(
            'INSERT INTO rakia.schema_migrations (version, name, checksum) '
            'VALUES (@v, @n, @c)',
          ),
          parameters: {'v': m.version, 'n': m.name, 'c': m.checksum},
        );
        return false;
      });
      if (done) return count;
      count++;
    }
  }

  /// Reverts the last [steps] applied migrations. Returns how many were
  /// reverted.
  Future<int> down({int steps = 1}) async {
    var count = 0;
    while (count < steps) {
      final done = await _locked((tx) async {
        final applied = await _applied(tx);
        _check(applied);
        if (applied.isEmpty) return true;
        final m = migrations[applied.last.version - 1];
        log('revert ${m.label}');
        await tx.execute(m.down, queryMode: QueryMode.simple);
        await tx.execute(
          Sql.named('DELETE FROM rakia.schema_migrations WHERE version = @v'),
          parameters: {'v': m.version},
        );
        return false;
      });
      if (done) break;
      count++;
    }
    return count;
  }
}
