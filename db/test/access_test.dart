// Row-level security and privileges, exercised as the API role on behalf of
// each kind of user: who can read and write whose health data.
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late Connection migrator;
  late Connection api;
  late World w;

  setUpAll(() async {
    if (skipReason != null) return;
    migrator = await migratorConfig.open();
    await resetSchema(migrator);
    w = await World.create(migrator);
    // A reading for each astronaut, written as the migrator.
    await w.measure('astro_a');
    await w.measure('astro_b', crew: w.crewB);
    api = await apiConfig.open();
  });
  tearDownAll(() async {
    if (skipReason != null) return;
    await api.close();
    await migrator.close();
  });

  Future<int> count(String? uid, String table) => asUser(api, uid, (tx) async {
    final r = await tx.execute('SELECT count(*) FROM rakia.$table');
    return r.single.single! as int;
  });

  Future<Set<String>> crewSeen(String uid) => asUser(api, uid, (tx) async {
    final r = await tx.execute(
      'SELECT DISTINCT crew_member_id::text FROM rakia.measurements',
    );
    return {for (final row in r) row[0]! as String};
  });

  group('reading health data', skip: skipReason, () {
    test('an astronaut sees only their own measurements', () async {
      expect(await crewSeen('astro_a'), {w.crewA});
      expect(await crewSeen('astro_b'), {w.crewB});
    });

    test('medical staff see the whole crew', () async {
      expect(await crewSeen('cmo'), {w.crewA, w.crewB});
      expect(await crewSeen('surgeon'), {w.crewA, w.crewB});
    });

    test('the mission admin and researchers see no health data', () async {
      expect(await count('admin', 'measurements'), 0);
      expect(await count('researcher', 'measurements'), 0);
    });

    test('someone outside the mission sees nothing at all', () async {
      for (final t in [
        'missions',
        'mission_members',
        'crew_members',
        'measurements',
        'alerts',
      ]) {
        expect(await count('outsider', t), 0, reason: t);
      }
    });

    test('without a verified caller nothing is visible', () async {
      for (final t in ['app_users', 'missions', 'measurements', 'clients']) {
        expect(await count(null, t), 0, reason: t);
      }
    });

    test('users see only their own account and clients', () async {
      expect(await count('astro_a', 'app_users'), 1);
      expect(await count('astro_a', 'clients'), 1);
    });
  });

  group('writing health data', skip: skipReason, () {
    test(
      'an astronaut records their own reading through their own client',
      () async {
        await asUser(
          api,
          'astro_a',
          (tx) => w.measure('astro_a', session: tx, value: 64),
        );
        expect(await crewSeen('astro_a'), {w.crewA});
      },
    );

    test("an astronaut cannot record another astronaut's reading", () async {
      await expectLater(
        asUser(
          api,
          'astro_a',
          (tx) => w.measure(
            'astro_a',
            session: tx,
            crew: w.crewB,
            client: w.clients['astro_a'],
          ),
        ),
        pgError('row-level security'),
      );
    });

    test("nobody can write through someone else's client", () async {
      await expectLater(
        asUser(api, 'cmo', (tx) => w.measure('astro_a', session: tx)),
        pgError('row-level security'),
      );
    });

    test('the crew medical officer records readings for the crew', () async {
      await asUser(
        api,
        'cmo',
        (tx) => w.measure('cmo', session: tx, crew: w.crewB, value: 70),
      );
    });

    test('measurements cannot be updated by the API at all', () async {
      await expectLater(
        asUser(
          api,
          'cmo',
          (tx) => tx.execute('UPDATE rakia.measurements SET value = 0'),
        ),
        pgCode('42501'),
      );
    });

    test('real measurements cannot be deleted, even by the admin', () async {
      final r = await asUser(
        api,
        'admin',
        (tx) => tx.execute('DELETE FROM rakia.measurements'),
      );
      expect(
        r.affectedRows,
        0,
        reason: 'policy hides real data from the admin',
      );
      await expectLater(
        migrator.execute(
          Sql.named('DELETE FROM rakia.measurements WHERE mission_id = @m'),
          parameters: {'m': w.mission},
        ),
        pgError('only simulated measurements can be deleted'),
      );
    });
  });

  group('missions and membership', skip: skipReason, () {
    test('a user creates a mission and becomes its admin, and nobody else can claim it', () async {
      final id = uuid();
      await asUser(api, 'outsider', (tx) async {
        await tx.execute(
          Sql.named(
            'INSERT INTO rakia.missions (id, name, is_simulation, starts_at, planned_days, created_by) '
            "VALUES (@i, 'New mission', false, now(), 30, rakia.current_user_id())",
          ),
          parameters: {'i': id},
        );
        await tx.execute(
          Sql.named(
            'INSERT INTO rakia.mission_members (mission_id, user_id, role) '
            "VALUES (@i, rakia.current_user_id(), 'mission_admin')",
          ),
          parameters: {'i': id},
        );
      });
      await expectLater(
        asUser(
          api,
          'astro_b',
          (tx) => tx.execute(
            Sql.named(
              'INSERT INTO rakia.mission_members (mission_id, user_id, role) '
              "VALUES (@i, rakia.current_user_id(), 'mission_admin')",
            ),
            parameters: {'i': id},
          ),
        ),
        pgError('row-level security'),
      );
    });

    test('a mission cannot be created in someone else\'s name', () async {
      await expectLater(
        asUser(
          api,
          'astro_a',
          (tx) => tx.execute(
            Sql.named(
              'INSERT INTO rakia.missions (id, name, is_simulation, starts_at, planned_days, created_by) '
              "VALUES (@i, 'X', false, now(), 30, @by)",
            ),
            parameters: {'i': uuid(), 'by': w.users['admin']},
          ),
        ),
        pgError('row-level security'),
      );
    });

    test('only the admin adds members', () async {
      Future<void> add(String as) => asUser(
        api,
        as,
        (tx) => tx.execute(
          Sql.named(
            'INSERT INTO rakia.mission_members (mission_id, user_id, role) '
            "VALUES (@m, @u, 'researcher')",
          ),
          parameters: {'m': w.mission, 'u': w.users['outsider']},
        ),
      );
      await expectLater(add('cmo'), pgError('row-level security'));
      await add('admin');
      expect(await count('outsider', 'missions'), greaterThanOrEqualTo(1));
    });
  });

  group('alerts', skip: skipReason, () {
    late String alert;

    setUpAll(() async {
      if (skipReason != null) return;
      alert = uuid();
      await migrator.execute(
        Sql.named(
          'INSERT INTO rakia.alerts (id, mission_id, crew_member_id, metric_code, level, '
          "explanation, engine_version) VALUES (@i, @m, @c, 'heart_rate.resting', 'act', "
          '@e, @v)',
        ),
        parameters: {
          'i': alert,
          'm': w.mission,
          'c': w.crewA,
          'e': TypedValue(Type.jsonb, {
            'what_changed': 'Resting heart rate rose',
            'by_how_much': '+2.1 SD',
            'since': 'Day 28',
            'evidence': '12 readings',
            'why_it_matters': 'Sustained change',
            'check_next': 'Repeat a resting measurement',
          }),
          'v': '0.1.0',
        },
      );
    });

    Future<void> event(String as, String from, String to) => asUser(
      api,
      as,
      (tx) => tx.execute(
        Sql.named(
          'INSERT INTO rakia.alert_events (alert_id, actor_id, from_status, to_status) '
          'VALUES (@a, rakia.current_user_id(), @f::rakia.alert_status, @t::rakia.alert_status)',
        ),
        parameters: {'a': alert, 'f': from, 't': to},
      ),
    );

    Future<String> status() async {
      final r = await migrator.execute(
        Sql.named('SELECT status::text FROM rakia.alerts WHERE id = @a'),
        parameters: {'a': alert},
      );
      return r.single.single! as String;
    }

    test(
      'the astronaut sees their alert; the other astronaut does not',
      () async {
        expect(await count('astro_a', 'alerts'), 1);
        expect(await count('astro_b', 'alerts'), 0);
      },
    );

    test('medical staff change its status through an event', () async {
      await event('cmo', 'open', 'acknowledged');
      expect(await status(), 'acknowledged');
    });

    test('an event from a stale status is refused', () async {
      await expectLater(event('surgeon', 'open', 'resolved'), pgCode('40001'));
    });

    test('an astronaut cannot change its status', () async {
      await expectLater(
        event('astro_a', 'acknowledged', 'dismissed'),
        pgError('row-level security'),
      );
    });

    test('the status cannot be changed directly', () async {
      await expectLater(
        asUser(
          api,
          'cmo',
          (tx) => tx.execute("UPDATE rakia.alerts SET status = 'resolved'"),
        ),
        pgCode('42501'),
      );
    });
  });

  group('privileges of the API role', skip: skipReason, () {
    test('cannot create objects', () async {
      await expectLater(
        api.execute('CREATE TABLE rakia.x (i int)'),
        pgCode('42501'),
      );
      await expectLater(
        api.execute('CREATE TABLE public.x (i int)'),
        pgCode('42501'),
      );
    });

    test('cannot read the audit log or verify it', () async {
      await expectLater(
        asUser(
          api,
          'admin',
          (tx) => tx.execute('SELECT * FROM rakia.audit_log'),
        ),
        pgCode('42501'),
      );
      await expectLater(
        api.execute('SELECT rakia.verify_audit_chain()'),
        pgCode('42501'),
      );
    });

    test('cannot change reference data', () async {
      await expectLater(
        api.execute("UPDATE rakia.metric_definitions SET unit = 'x'"),
        pgCode('42501'),
      );
    });

    test('cannot read or change the migration history', () async {
      await expectLater(
        api.execute('SELECT * FROM rakia.schema_migrations'),
        pgCode('42501'),
      );
    });
  });
}
