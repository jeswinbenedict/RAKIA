// Rules the database enforces whoever writes: the simulation firewall,
// units, the per-client hash chain, immutability, corrections, and the
// append-only, hash-chained audit log.
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late Connection migrator;
  late World w;

  setUpAll(() async {
    if (skipReason != null) return;
    migrator = await migratorConfig.open();
    await resetSchema(migrator);
    w = await World.create(migrator);
  });
  tearDownAll(() async {
    if (skipReason != null) return;
    await migrator.close();
  });

  group('simulation firewall', skip: skipReason, () {
    test('a real mission refuses simulated measurements', () async {
      await expectLater(
        w.measure('astro_a', provenance: 'simulated'),
        pgError('simulated measurements are not accepted in a real mission'),
      );
    });

    test(
      'a simulation mission refuses real and imported measurements',
      () async {
        for (final p in ['real', 'imported']) {
          await expectLater(
            w.measure('astro_a', mission: w.simMission, provenance: p),
            pgError('accepts only simulated measurements'),
          );
        }
      },
    );

    test("a mission's simulation status cannot change", () async {
      await expectLater(
        migrator.execute(
          Sql.named(
            'UPDATE rakia.missions SET is_simulation = true WHERE id = @m',
          ),
          parameters: {'m': w.mission},
        ),
        pgError('identity and simulation status cannot change'),
      );
    });

    test(
      'a real mission cannot be deleted; a simulation can, with its data',
      () async {
        await w.measure('astro_a', mission: w.simMission);
        await expectLater(
          migrator.execute(
            Sql.named('DELETE FROM rakia.missions WHERE id = @m'),
            parameters: {'m': w.mission},
          ),
          pgError('only simulation missions can be deleted'),
        );
        final sim = await World.create(migrator, tag: 'second_');
        await sim.measure('astro_a', mission: sim.simMission);
        await migrator.execute(
          Sql.named('DELETE FROM rakia.missions WHERE id = @m'),
          parameters: {'m': sim.simMission},
        );
        final left = await migrator.execute(
          Sql.named(
            'SELECT count(*) FROM rakia.measurements WHERE mission_id = @m',
          ),
          parameters: {'m': sim.simMission},
        );
        expect(left.single.single, 0);
      },
    );
  });

  group('measurement values', skip: skipReason, () {
    test('must use the indicator\'s unit', () async {
      await expectLater(
        w.measure('astro_a', unit: 'Hz'),
        pgError('heart_rate.resting is recorded in bpm, not Hz'),
      );
    });

    test('must be finite numbers', () async {
      // Written as SQL literals: the driver cannot send NaN as a parameter.
      for (final v in ['NaN', 'Infinity', '-Infinity']) {
        await expectLater(
          w.measure('astro_a', valueSql: "'$v'::float8"),
          pgCode('23514'),
        );
      }
    });

    test('must belong to a crew member of the same mission', () async {
      await expectLater(w.measure('astro_a', crew: w.simCrew), pgCode('23503'));
    });

    test('must reference a known indicator', () async {
      await expectLater(
        w.measure('astro_a', metric: 'heart_rate.unknown'),
        pgCode('23503'),
      );
    });
  });

  group('hash chain per client and mission', skip: skipReason, () {
    test('continues record by record', () async {
      for (var i = 0; i < 3; i++) {
        await w.measure('surgeon');
      }
    });

    test('refuses a gap in the sequence', () async {
      await w.measure('cmo');
      await expectLater(
        w.measure('cmo', seq: 5),
        pgError('chain gap: expected sequence 2, got 5'),
      );
    });

    test('refuses a record that does not link to the previous hash', () async {
      await expectLater(
        w.measure('cmo', prevHash: randomHash()),
        pgError('prev_hash does not match'),
      );
    });

    test('starts from the all-zero hash', () async {
      await expectLater(
        w.measure('researcher', prevHash: randomHash()),
        pgError('chain break at sequence 1'),
      );
    });

    test('keeps separate chains per mission', () async {
      await w.measure('astro_b', crew: w.crewB);
      await w.measure('astro_b', mission: w.simMission);
    });
  });

  group('immutability and corrections', skip: skipReason, () {
    test('a measurement cannot be changed, even by the owner role', () async {
      final id = await w.measure('astro_a');
      await expectLater(
        migrator.execute(
          Sql.named('UPDATE rakia.measurements SET value = 1 WHERE id = @i'),
          parameters: {'i': id},
        ),
        pgError('measurements are immutable'),
      );
    });

    test('a correction supersedes a record of the same series', () async {
      final id = await w.measure('astro_a');
      await w.measure('astro_a', supersedes: id, value: 63);
    });

    test('a correction cannot supersede another indicator', () async {
      final id = await w.measure('astro_a');
      await expectLater(
        w.measure(
          'astro_a',
          supersedes: id,
          metric: 'spo2',
          unit: '%',
          value: 97,
        ),
        pgError('same series'),
      );
    });
  });

  group('alerts', skip: skipReason, () {
    Future<void> insert(Object explanation) => migrator.execute(
      Sql.named(
        'INSERT INTO rakia.alerts (id, mission_id, crew_member_id, metric_code, level, '
        "explanation, engine_version) VALUES (@i, @m, @c, 'spo2', 'watch', @e, '0.1.0')",
      ),
      parameters: {
        'i': uuid(),
        'm': w.mission,
        'c': w.crewA,
        'e': TypedValue(Type.jsonb, explanation),
      },
    );

    test('need all six parts of the explanation', () async {
      await expectLater(insert({'what_changed': 'x'}), pgCode('23514'));
      await insert({
        for (final k in [
          'what_changed',
          'by_how_much',
          'since',
          'evidence',
          'why_it_matters',
          'check_next',
        ])
          k: 'text',
      });
    });

    test('only the status of an alert may change', () async {
      await expectLater(
        migrator.execute("UPDATE rakia.alerts SET level = 'act'"),
        pgError("only an alert's status can change"),
      );
    });
  });

  group('audit log', skip: skipReason, () {
    test('records changes to missions, membership and crew', () async {
      final r = await migrator.execute(
        'SELECT DISTINCT table_name FROM rakia.audit_log ORDER BY 1',
      );
      expect([
        for (final row in r) row[0],
      ], containsAll(['crew_members', 'mission_members', 'missions']));
    });

    test('is hash-chained and verifies', () async {
      final r = await migrator.execute('SELECT rakia.verify_audit_chain()');
      expect(r.single.single, isNull);
    });

    test('is append-only', () async {
      await expectLater(
        migrator.execute("UPDATE rakia.audit_log SET actor = 'someone'"),
        pgError('append-only'),
      );
      await expectLater(
        migrator.execute('DELETE FROM rakia.audit_log'),
        pgError('append-only'),
      );
      await expectLater(
        migrator.execute('TRUNCATE rakia.audit_log'),
        pgError('append-only'),
      );
    });

    test('detects an entry altered behind its back', () async {
      Object? detected;
      // Tamper inside a transaction that is then rolled back, leaving the
      // log as it was.
      await expectLater(
        migrator.runTx((tx) async {
          await tx.execute(
            'ALTER TABLE rakia.audit_log DISABLE TRIGGER audit_log_append_only',
          );
          final target = await tx.execute(
            'SELECT min(id) + 1 FROM rakia.audit_log',
          );
          await tx.execute(
            Sql.named(
              "UPDATE rakia.audit_log SET actor = 'forged' WHERE id = @i",
            ),
            parameters: {'i': target.single.single},
          );
          final r = await tx.execute('SELECT rakia.verify_audit_chain()');
          detected = r.single.single;
          expect(detected, target.single.single);
          throw const _RollBack();
        }),
        throwsA(isA<_RollBack>()),
      );
      expect(detected, isNotNull);
      final r = await migrator.execute('SELECT rakia.verify_audit_chain()');
      expect(r.single.single, isNull);
    });
  });

  group('Turnstile replay protection', skip: skipReason, () {
    test('a token hash is accepted once', () async {
      final h = randomHash();
      Future<void> put() => migrator.execute(
        Sql.named(
          'INSERT INTO rakia.turnstile_replay (token_hash, expires_at) '
          "VALUES (@h, now() + interval '10 minutes')",
        ),
        parameters: {'h': TypedValue(Type.byteArray, h)},
      );
      await put();
      await expectLater(put(), pgCode('23505'));
    });
  });
}

class _RollBack implements Exception {
  const _RollBack();
}
