// The on-device store: schema rules enforced by SQLite, an exact round trip
// of the simulation mission, and librakia verification of the hash chain.
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakia/simulation/simulated_mission.dart';
import 'package:rakia/storage/database.dart';
import 'package:rakia/storage/local_store.dart';
import 'package:rakia/storage/uuid.dart';
import 'package:rakia_core/rakia_core.dart';

import 'helpers.dart';

void main() {
  late RakiaCore core;
  late LocalStore store;
  late Directory tmp;
  final now = DateTime.utc(2026, 11, 6, 15, 30);

  setUpAll(() async {
    core = await loadRakiaCore();
    tmp = await Directory.systemTemp.createTemp('rakia_store_test');
  });
  tearDownAll(() => tmp.delete(recursive: true));

  setUp(() => store = newMemoryStore());
  tearDown(() => store.close());

  Matcher abortsWith(String message) => throwsA(
    isA<SqliteException>().having(
      (e) => e.message,
      'message',
      contains(message),
    ),
  );

  Future<StoredSimulation> saved() =>
      store.saveSimulation(SimulatedMission.generate(), core, now: now);

  /// Inserts a real mission directly (the app cannot create one yet; ingest
  /// will), returning its id and subject.
  Future<(String, Uint8List)> realMission() async {
    final id = uuidToString(uuidV7());
    final subject = uuidV7();
    await store.db
        .into(store.db.missions)
        .insert(
          MissionsCompanion.insert(
            id: id,
            name: 'Real mission',
            isSimulation: 0,
            subjectId: subject,
            subjectLabel: 'Crew member',
            startAtUs: 0,
            referenceDays: 0,
            plannedDays: 30,
            createdAtUs: 0,
          ),
        );
    return (id, subject);
  }

  /// A correctly chained record for [missionId] after its last record.
  Future<MeasurementsCompanion> nextRecord(
    String missionId,
    Uint8List subject, {
    Provenance provenance = Provenance.real,
    String unit = '/min',
    double value = 60,
  }) async {
    final last =
        await (store.db.select(store.db.measurements)
              ..where((m) => m.missionId.equals(missionId))
              ..orderBy([(m) => OrderingTerm.desc(m.clientSeq)])
              ..limit(1))
            .getSingleOrNull();
    final seq = (last?.clientSeq ?? 0) + 1;
    final prev = last?.hash ?? Uint8List(32);
    final id = uuidV7();
    const observedAtUs = 1762412400000000;
    final hash = core.recordHash(
      LedgerRecord(
        id: id,
        subjectId: subject,
        metricCode: 'heart_rate.resting',
        value: value,
        unit: unit,
        observedAtUs: observedAtUs,
        method: MeasurementMethod.measured,
        provenance: provenance,
        clientSeq: seq,
        prevHash: prev,
      ),
    );
    return MeasurementsCompanion.insert(
      id: id,
      missionId: missionId,
      subjectId: subject,
      metricCode: 'heart_rate.resting',
      value: value,
      unit: unit,
      observedAtUs: observedAtUs,
      method: MeasurementMethod.measured.code,
      provenance: provenance.code,
      clientSeq: seq,
      prevHash: prev,
      hash: hash,
    );
  }

  group('schema', () {
    test('opens at version 1 with foreign keys enforced', () async {
      expect(store.schemaVersion, RakiaDatabase.currentSchemaVersion);
      final fk = await store.db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(fk.data.values.single, 1);
    });

    test('refuses a database written by a newer schema', () async {
      final file = File('${tmp.path}/newer.sqlite');
      final first = RakiaDatabase(NativeDatabase(file));
      await first.customSelect('SELECT 1').get();
      await first.customStatement('PRAGMA user_version = 2');
      await first.close();

      final second = RakiaDatabase(NativeDatabase(file));
      await expectLater(
        second.customSelect('SELECT 1').get(),
        throwsA(isA<UnsupportedError>()),
      );
      await second.close();
    });
  });

  group('settings', () {
    test('round-trip and overwrite', () async {
      expect(await store.setting('theme_mode'), isNull);
      await store.setSetting('theme_mode', 'light');
      await store.setSetting('theme_mode', 'dark');
      expect(await store.setting('theme_mode'), 'dark');
    });
  });

  group('simulation mission', () {
    test('round-trips every value exactly, gaps and flags included', () async {
      final generated = SimulatedMission.generate();
      final stored = await saved();
      final m = stored.mission;
      expect(m.seed, generated.seed);
      expect(m.missionDay, generated.missionDay);
      expect(m.referenceDays, generated.referenceDays);
      var finite = 0;
      for (var k = 0; k < generated.series.length; k++) {
        final g = generated.series[k];
        final s = m.series[k];
        expect(s.metric.code, g.metric.code);
        expect(s.reference, g.reference, reason: g.metric.code);
        expect(s.sensorFlags, g.sensorFlags, reason: g.metric.code);
        for (var d = 0; d < g.monitoring.length; d++) {
          final a = g.monitoring[d];
          final b = s.monitoring[d];
          expect(b.isNaN, a.isNaN, reason: '${g.metric.code} day ${d + 1}');
          if (a.isFinite) expect(b, a);
        }
        finite +=
            g.reference.where((v) => v.isFinite).length +
            g.monitoring.where((v) => v.isFinite).length;
      }
      expect(stored.records, finite);
      expect(await store.recordCount(stored.missionId), finite);
    });

    test('the ledger verifies with librakia', () async {
      final stored = await saved();
      final check = await store.verifyLedger(stored.missionId, core);
      expect(check.verified, isTrue, reason: check.reason);
      expect(check.records, stored.records);
    });

    test('readings are dated relative to today', () async {
      final stored = await saved();
      final rows = await (store.db.select(
        store.db.measurements,
      )..orderBy([(m) => OrderingTerm.desc(m.observedAtUs)])).get();
      final latest = DateTime.fromMicrosecondsSinceEpoch(
        rows.first.observedAtUs,
        isUtc: true,
      );
      expect(latest, DateTime.utc(2026, 11, 6, 7));
      expect(stored.mission.missionDay, 45);
    });

    test('survives closing and reopening the database file', () async {
      final file = File('${tmp.path}/reopen.sqlite');
      final first = LocalStore(
        RakiaDatabase(NativeDatabase(file)),
        kind: StorageKind.nativeFile,
      );
      final original = await first.saveSimulation(
        SimulatedMission.generate(),
        core,
        now: now,
      );
      await first.close();

      final second = LocalStore(
        RakiaDatabase(NativeDatabase(file)),
        kind: StorageKind.nativeFile,
      );
      final restored = await second.activeSimulation();
      expect(restored, isNotNull);
      expect(restored!.missionId, original.missionId);
      expect(restored.records, original.records);
      expect(
        restored.mission.series.first.reference,
        original.mission.series.first.reference,
      );
      expect(
        (await second.verifyLedger(restored.missionId, core)).verified,
        isTrue,
      );
      await second.close();
    });

    test('starting again replaces the previous simulation', () async {
      final a = await saved();
      final b = await saved();
      expect(b.missionId, isNot(a.missionId));
      expect(await store.recordCount(a.missionId), 0);
      expect((await store.activeSimulation())!.missionId, b.missionId);
    });

    test('ending it deletes the mission and every record', () async {
      final stored = await saved();
      await store.deleteSimulation(stored.missionId);
      expect(await store.activeSimulation(), isNull);
      expect(await store.recordCount(stored.missionId), 0);
    });

    test('stored data with the wrong unit is refused, not guessed', () async {
      final stored = await saved();
      final mission = await (store.db.select(
        store.db.missions,
      )..where((m) => m.id.equals(stored.missionId))).getSingle();
      await store.db
          .into(store.db.measurements)
          .insert(
            await nextRecord(
              stored.missionId,
              mission.subjectId,
              provenance: Provenance.simulated,
              unit: 'Hz',
            ),
          );
      await expectLater(
        store.activeSimulation(),
        throwsA(isA<StoreIntegrityError>()),
      );
    });
  });

  group('integrity rules enforced by SQLite', () {
    test('measurements are immutable', () async {
      final stored = await saved();
      await expectLater(
        store.db.customUpdate(
          'UPDATE measurements SET value = value + 1 WHERE mission_id = ?',
          variables: [Variable(stored.missionId)],
        ),
        abortsWith('measurements are immutable'),
      );
    });

    test('simulation firewall: no real record in a simulation', () async {
      final stored = await saved();
      final mission = await (store.db.select(
        store.db.missions,
      )..where((m) => m.id.equals(stored.missionId))).getSingle();
      await expectLater(
        store.db
            .into(store.db.measurements)
            .insert(await nextRecord(stored.missionId, mission.subjectId)),
        abortsWith('simulation firewall'),
      );
    });

    test(
      'simulation firewall: no simulated record in a real mission',
      () async {
        final (id, subject) = await realMission();
        await expectLater(
          store.db
              .into(store.db.measurements)
              .insert(
                await nextRecord(id, subject, provenance: Provenance.simulated),
              ),
          abortsWith('simulation firewall'),
        );
        // A real record is accepted.
        await store.db
            .into(store.db.measurements)
            .insert(await nextRecord(id, subject));
        expect(await store.recordCount(id), 1);
      },
    );

    test('records must belong to the mission subject', () async {
      final (id, _) = await realMission();
      await expectLater(
        store.db
            .into(store.db.measurements)
            .insert(await nextRecord(id, uuidV7())),
        abortsWith('subject does not match'),
      );
    });

    test('the chain must be continuous', () async {
      final (id, subject) = await realMission();
      final first = await nextRecord(id, subject);
      await store.db.into(store.db.measurements).insert(first);
      final next = await nextRecord(id, subject);

      await expectLater(
        store.db
            .into(store.db.measurements)
            .insert(next.copyWith(clientSeq: const Value(3))),
        abortsWith('chain is not continuous'),
      );
      await expectLater(
        store.db
            .into(store.db.measurements)
            .insert(next.copyWith(prevHash: Value(Uint8List(32)))),
        abortsWith('chain is not continuous'),
      );
      await store.db.into(store.db.measurements).insert(next);
      expect(await store.recordCount(id), 2);
    });

    test('real missions and their records cannot be deleted', () async {
      final (id, subject) = await realMission();
      await store.db
          .into(store.db.measurements)
          .insert(await nextRecord(id, subject));
      await expectLater(
        store.db.customUpdate(
          'DELETE FROM measurements WHERE mission_id = ?',
          variables: [Variable(id)],
        ),
        abortsWith('only simulation data can be deleted'),
      );
      await expectLater(
        store.db.customUpdate(
          'DELETE FROM missions WHERE id = ?',
          variables: [Variable(id)],
        ),
        abortsWith('only simulation missions can be deleted'),
      );
      // deleteSimulation only ever targets simulation missions.
      await store.deleteSimulation(id);
      expect(await store.recordCount(id), 1);
    });

    test("a mission's identity cannot change", () async {
      final (id, _) = await realMission();
      await expectLater(
        store.db.customUpdate(
          'UPDATE missions SET is_simulation = 1 WHERE id = ?',
          variables: [Variable(id)],
        ),
        abortsWith('identity cannot change'),
      );
    });
  });

  group('ledger verification', () {
    test('detects a value altered outside RAKIA', () async {
      final stored = await saved();
      // Simulate tampering by someone with direct access to the file: drop
      // the trigger that forbids updates, then change one value.
      await store.db.customStatement('DROP TRIGGER measurements_immutable');
      await store.db.customUpdate(
        'UPDATE measurements SET value = value + 0.1 '
        'WHERE mission_id = ? AND client_seq = 100',
        variables: [Variable(stored.missionId)],
      );
      final check = await store.verifyLedger(stored.missionId, core);
      expect(check.verified, isFalse);
      expect(check.failedAtSeq, 100);
      expect(check.reason, contains('does not match its hash'));
    });

    test('detects a deleted record', () async {
      final stored = await saved();
      await store.db.customStatement(
        'DROP TRIGGER measurements_delete_simulation_only',
      );
      await store.db.customUpdate(
        'DELETE FROM measurements WHERE mission_id = ? AND client_seq = 7',
        variables: [Variable(stored.missionId)],
      );
      final check = await store.verifyLedger(stored.missionId, core);
      expect(check.failedAtSeq, 7);
      expect(check.reason, contains('missing'));
    });
  });

  group('UUIDv7', () {
    test('carries the version, variant and millisecond timestamp', () {
      final t = DateTime.utc(2026, 11, 6, 12);
      final b = uuidV7(now: t, random: Random(1));
      expect(b[6] >> 4, 7);
      expect(b[8] >> 6, 2);
      var ms = 0;
      for (var i = 0; i < 6; i++) {
        ms = ms * 256 + b[i];
      }
      expect(ms, t.millisecondsSinceEpoch);
      expect(
        uuidToString(b),
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('identifiers are unique', () {
      final ids = {for (var i = 0; i < 10000; i++) uuidToString(uuidV7())};
      expect(ids, hasLength(10000));
    });
  });
}
