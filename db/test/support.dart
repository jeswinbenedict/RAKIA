// Shared set-up for the database tests. They need a PostgreSQL prepared by
// db/bootstrap (roles, database, .env) and they DESTROY the schema's data:
// they run only when RAKIA_DB_ALLOW_RESET=1, which must never be set for a
// database holding anything of value. CI sets it for its disposable server.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:postgres/postgres.dart';
import 'package:rakia_db/rakia_db.dart';
import 'package:test/test.dart';

final _env = Platform.environment;

String get envFilePath =>
    _env['RAKIA_ENV_FILE'] ??
    '${Directory.current.parent.path}${Platform.pathSeparator}.env';

/// Why the database tests cannot run here, or null when they can.
String? get skipReason {
  if (_env['RAKIA_DB_ALLOW_RESET'] != '1') {
    return 'database tests reset the schema; set RAKIA_DB_ALLOW_RESET=1 '
        'only for a disposable database';
  }
  return null;
}

List<Migration> get migrations => loadMigrations(Directory('migrations'));

final _file = readEnvFile(envFilePath);
DbConfig get migratorConfig => DbConfig.fromEnvironment(envFile: _file);
DbConfig get apiConfig => DbConfig.fromEnvironment(envFile: _file, api: true);

/// Reverts every migration and applies them again: an empty schema with
/// the seed data only.
Future<void> resetSchema(Connection migrator) async {
  final m = Migrator(migrator, migrations, log: (_) {});
  await m.down(steps: 1 << 20);
  await m.up();
}

final _rng = Random.secure();

String uuid() {
  final b = List<int>.generate(16, (_) => _rng.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

Uint8List randomHash() =>
    Uint8List.fromList(List<int>.generate(32, (_) => _rng.nextInt(256)));

final Uint8List zeroHash = Uint8List(32);

/// Runs [body] in a transaction as the API acting for the Firebase user
/// [uid] (null: outside any request), exactly as the API will.
Future<T> asUser<T>(
  Connection api,
  String? uid,
  Future<T> Function(TxSession tx) body,
) => api.runTx((tx) async {
  if (uid != null) {
    await tx.execute(
      Sql.named("SELECT set_config('request.jwt.claims', @c, true)"),
      parameters: {'c': '{"sub":"$uid"}'},
    );
  }
  return body(tx);
});

/// Matches a PostgreSQL error whose message contains [text].
Matcher pgError(String text) => throwsA(
  isA<ServerException>().having((e) => e.message, 'message', contains(text)),
);

/// Matches a PostgreSQL error with SQLSTATE [code].
Matcher pgCode(String code) =>
    throwsA(isA<ServerException>().having((e) => e.code, 'code', code));

/// A mission with its people, created as the migrator (the owner, which
/// row-level security does not restrict).
class World {
  World._(this.migrator, this.tag);

  final Connection migrator;

  /// Prefix of every Firebase uid in this world, so several can coexist.
  final String tag;

  final users = <String, String>{}; // name -> app_users.id; uid is the name
  late final String mission;
  late final String simMission;
  late final String crewA; // linked to astro_a
  late final String crewB; // linked to astro_b
  late final String simCrew;
  final clients = <String, String>{}; // user name -> client id

  static const people = [
    'astro_a',
    'astro_b',
    'cmo',
    'surgeon',
    'admin',
    'researcher',
    'outsider',
  ];

  static Future<World> create(Connection migrator, {String tag = ''}) async {
    final w = World._(migrator, tag);
    for (final p in people) {
      final id = uuid();
      w.users[p] = id;
      await migrator.execute(
        Sql.named(
          'INSERT INTO rakia.app_users (id, firebase_uid) VALUES (@i, @u)',
        ),
        parameters: {'i': id, 'u': '$tag$p'},
      );
      final c = uuid();
      w.clients[p] = c;
      await migrator.execute(
        Sql.named('INSERT INTO rakia.clients (id, user_id) VALUES (@c, @u)'),
        parameters: {'c': c, 'u': id},
      );
    }
    w.mission = await w._mission(simulation: false);
    w.simMission = await w._mission(simulation: true);
    for (final m in [w.mission, w.simMission]) {
      for (final (who, role) in [
        ('astro_a', 'astronaut'),
        ('astro_b', 'astronaut'),
        ('cmo', 'crew_medical_officer'),
        ('surgeon', 'flight_surgeon'),
        ('admin', 'mission_admin'),
        ('researcher', 'researcher'),
      ]) {
        await migrator.execute(
          Sql.named(
            'INSERT INTO rakia.mission_members (mission_id, user_id, role) '
            'VALUES (@m, @u, @r::rakia.member_role)',
          ),
          parameters: {'m': m, 'u': w.users[who], 'r': role},
        );
      }
    }
    w.crewA = await w._crew(w.mission, 'Crew A', 'astro_a');
    w.crewB = await w._crew(w.mission, 'Crew B', 'astro_b');
    w.simCrew = await w._crew(w.simMission, 'Simulated crew', 'astro_a');
    return w;
  }

  Future<String> _mission({required bool simulation}) async {
    final id = uuid();
    await migrator.execute(
      Sql.named(
        'INSERT INTO rakia.missions (id, name, is_simulation, simulation_seed, '
        'starts_at, planned_days, created_by) VALUES (@i, @n, @s, @seed, '
        "now() - interval '30 days', 180, @by)",
      ),
      parameters: {
        'i': id,
        'n': simulation ? 'Simulation' : 'Analog mission',
        's': simulation,
        'seed': simulation ? 42 : null,
        'by': users['admin'],
      },
    );
    return id;
  }

  Future<String> _crew(String mission, String label, String who) async {
    final id = uuid();
    await migrator.execute(
      Sql.named(
        'INSERT INTO rakia.crew_members (id, mission_id, user_id, label) '
        'VALUES (@i, @m, @u, @l)',
      ),
      parameters: {'i': id, 'm': mission, 'u': users[who], 'l': label},
    );
    return id;
  }

  /// Per (client, mission): the last sequence number and hash, so helpers
  /// can extend each chain correctly.
  final _chains = <String, (int, Uint8List)>{};

  /// Inserts the next measurement of [by]'s client chain for [crew] in
  /// [mission], through [session] (the migrator by default). Fields can be
  /// overridden to break a rule on purpose.
  Future<String> measure(
    String by, {
    Session? session,
    String? mission,
    String? crew,
    String metric = 'heart_rate.resting',
    String unit = 'bpm',
    double value = 62,
    String? provenance,
    int? seq,
    Uint8List? prevHash,
    String? supersedes,
    String? client,
    String? valueSql,
  }) async {
    final m = mission ?? this.mission;
    final c = client ?? clients[by]!;
    final key = '$c/$m';
    final (last, lastHash) = _chains[key] ?? (0, zeroHash);
    final id = uuid();
    final hash = randomHash();
    await (session ?? migrator).execute(
      Sql.named(
        'INSERT INTO rakia.measurements (id, mission_id, crew_member_id, '
        'metric_code, value, unit, observed_at, method, provenance, client_id, '
        'client_seq, prev_hash, hash, supersedes_id) VALUES (@i, @m, @cr, @mc, '
        "${valueSql ?? '@v'}, @u, now() - interval '1 hour', 'measured', @p::rakia.provenance, "
        '@cl, @seq, @prev, @h, @sup)',
      ),
      parameters: {
        'i': id,
        'm': m,
        'cr': crew ?? (m == simMission ? simCrew : crewA),
        'mc': metric,
        if (valueSql == null) 'v': value,
        'u': unit,
        'p': provenance ?? (m == simMission ? 'simulated' : 'real'),
        'cl': c,
        'seq': seq ?? last + 1,
        'prev': TypedValue(Type.byteArray, prevHash ?? lastHash),
        'h': TypedValue(Type.byteArray, hash),
        'sup': supersedes,
      },
    );
    _chains[key] = (seq ?? last + 1, hash);
    return id;
  }
}
