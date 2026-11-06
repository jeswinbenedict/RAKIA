import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:rakia_core/rakia_core.dart';

import '../simulation/simulated_mission.dart';
import 'database.dart';
import 'uuid.dart';

/// Where the local database lives in this session.
enum StorageKind {
  /// A SQLite file in the app's private support directory.
  nativeFile('SQLite database on this device', persistent: true),

  /// SQLite (WebAssembly) on the browser's Origin Private File System.
  browserOpfs(
    'SQLite in this browser (Origin Private File System)',
    persistent: true,
  ),

  /// SQLite (WebAssembly) saved to the browser's IndexedDB.
  browserIndexedDb('SQLite in this browser (IndexedDB)', persistent: true),

  /// In memory only: nothing is kept after the app closes.
  memory('In memory only', persistent: false);

  const StorageKind(this.label, {required this.persistent});

  final String label;

  /// Whether data survives closing the app.
  final bool persistent;
}

/// Bit 0 of `measurements.quality_flags`.
const int kSensorFaultFlag = 1;

const int _dayUs = 86400 * 1000000;

/// Daily readings are time-stamped at 07:00 UTC on their day.
const int _readingOffsetUs = 7 * 3600 * 1000000;

/// Result of re-verifying a mission's hash chain with librakia.
@immutable
class LedgerCheck {
  const LedgerCheck({required this.records, this.failedAtSeq, this.reason});

  /// Records examined.
  final int records;

  /// First record that failed, or null when the whole chain verified.
  final int? failedAtSeq;
  final String? reason;

  bool get verified => failedAtSeq == null;
}

/// A simulation mission read back from the store.
@immutable
class StoredSimulation {
  const StoredSimulation({
    required this.missionId,
    required this.mission,
    required this.records,
  });

  final String missionId;

  /// Values come from the stored records; scenario descriptions and ground
  /// truth come from the generator for the stored seed.
  final SimulatedMission mission;
  final int records;
}

/// Thrown when stored data contradicts what the app expects (for example a
/// unit that does not match the indicator). Such data is never guessed at.
class StoreIntegrityError extends StateError {
  StoreIntegrityError(super.message);
}

/// RAKIA's on-device store: settings, missions and the hash-chained
/// measurement ledger. Integrity rules are enforced by SQLite triggers
/// (schema.drift); record hashes come from librakia.
class LocalStore {
  LocalStore(this.db, {required this.kind});

  final RakiaDatabase db;
  final StorageKind kind;

  int get schemaVersion => db.schemaVersion;

  Future<void> close() => db.close();

  // ---------------------------------------------------------------- settings

  Future<String?> setting(String key) async {
    final row = await (db.select(
      db.settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) => db
      .into(db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  // -------------------------------------------------------------- simulation

  /// The stored simulation mission, if one is active.
  Future<StoredSimulation?> activeSimulation() async {
    final row =
        await (db.select(db.missions)
              ..where((m) => m.isSimulation.equals(1))
              ..orderBy([(m) => OrderingTerm.desc(m.createdAtUs)])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    return _readSimulation(row);
  }

  /// Writes [mission] as a new simulation mission and returns it as read back
  /// from the store, so what is analysed is exactly what was persisted.
  ///
  /// Any earlier simulation mission is removed first: there is at most one.
  Future<StoredSimulation> saveSimulation(
    SimulatedMission mission,
    RakiaCore core, {
    DateTime? now,
  }) async {
    final created = (now ?? DateTime.now()).toUtc();
    final today = DateTime.utc(created.year, created.month, created.day);
    // The simulation's latest mission day is today.
    final startAtUs =
        today.microsecondsSinceEpoch - (mission.missionDay - 1) * _dayUs;
    final missionId = uuidToString(uuidV7(now: created));
    final subjectId = uuidV7(now: created);

    final rows = <MeasurementsCompanion>[];
    var seq = 0;
    var prev = Uint8List(32);
    void add(SimulatedSeries s, int day, double v, int flags) {
      if (!v.isFinite) return; // no reading that day
      final observedAtUs = startAtUs + (day - 1) * _dayUs + _readingOffsetUs;
      final id = uuidV7(now: created);
      seq++;
      final hash = core.recordHash(
        LedgerRecord(
          id: id,
          subjectId: subjectId,
          metricCode: s.metric.code,
          value: v,
          unit: s.metric.ucum,
          observedAtUs: observedAtUs,
          method: MeasurementMethod.measured,
          provenance: Provenance.simulated,
          clientSeq: seq,
          prevHash: prev,
        ),
      );
      rows.add(
        MeasurementsCompanion.insert(
          id: id,
          missionId: missionId,
          subjectId: subjectId,
          metricCode: s.metric.code,
          value: v,
          unit: s.metric.ucum,
          observedAtUs: observedAtUs,
          method: MeasurementMethod.measured.code,
          provenance: Provenance.simulated.code,
          qualityFlags: Value(flags),
          clientSeq: seq,
          prevHash: prev,
          hash: hash,
        ),
      );
      prev = hash;
    }

    for (final s in mission.series) {
      for (var r = 0; r < s.reference.length; r++) {
        add(s, r - mission.referenceDays + 1, s.reference[r], 0);
      }
      for (var d = 1; d <= s.monitoring.length; d++) {
        final flags = s.sensorFlags[d - 1] != 0 ? kSensorFaultFlag : 0;
        add(s, d, s.monitoring[d - 1], flags);
      }
    }

    await db.transaction(() async {
      await (db.delete(
        db.missions,
      )..where((m) => m.isSimulation.equals(1))).go();
      await db
          .into(db.missions)
          .insert(
            MissionsCompanion.insert(
              id: missionId,
              name: mission.name,
              isSimulation: 1,
              simulationSeed: Value(mission.seed),
              simulatedDay: Value(mission.missionDay),
              subjectId: subjectId,
              subjectLabel: mission.crewMember,
              startAtUs: startAtUs,
              referenceDays: mission.referenceDays,
              plannedDays: mission.plannedDays,
              createdAtUs: created.microsecondsSinceEpoch,
            ),
          );
      // A batch runs its statements in order, so the continuity trigger
      // checks each record against its predecessor.
      await db.batch((b) => b.insertAll(db.measurements, rows));
    });

    final row = await (db.select(
      db.missions,
    )..where((m) => m.id.equals(missionId))).getSingle();
    return _readSimulation(row);
  }

  /// Deletes a simulation mission and all its records. Real missions cannot
  /// be deleted (the database refuses).
  Future<void> deleteSimulation(String missionId) => (db.delete(
    db.missions,
  )..where((m) => m.id.equals(missionId) & m.isSimulation.equals(1))).go();

  Future<StoredSimulation> _readSimulation(Mission row) async {
    final seed = row.simulationSeed;
    if (seed == null) {
      throw StoreIntegrityError('Mission ${row.id} has no simulation seed');
    }
    final generated = SimulatedMission.generate(seed: seed);
    final simulatedDay = row.simulatedDay ?? generated.missionDay;
    final records = await _records(row.id);
    final superseded = {
      for (final r in records)
        if (r.supersedesId != null) uuidToString(r.supersedesId!),
    };
    final series = <SimulatedSeries>[];
    for (final g in generated.series) {
      final reference = List<double>.filled(row.referenceDays, double.nan);
      final monitoring = List<double>.filled(simulatedDay, double.nan);
      final flags = List<int>.filled(simulatedDay, 0);
      for (final r in records) {
        if (r.metricCode != g.metric.code) continue;
        if (superseded.contains(uuidToString(r.id))) continue;
        if (r.unit != g.metric.ucum) {
          throw StoreIntegrityError(
            'Stored ${r.metricCode} uses unit "${r.unit}", expected '
            '"${g.metric.ucum}"',
          );
        }
        final offset = r.observedAtUs - row.startAtUs;
        // Floor division: reference days lie before the mission start.
        final day = (offset - offset % _dayUs) ~/ _dayUs + 1;
        if (day <= 0) {
          final i = row.referenceDays + day - 1;
          if (i >= 0) reference[i] = r.value;
        } else if (day <= simulatedDay) {
          monitoring[day - 1] = r.value;
          flags[day - 1] = r.qualityFlags & kSensorFaultFlag;
        }
      }
      series.add(
        SimulatedSeries(
          metric: g.metric,
          reference: reference,
          monitoring: monitoring,
          sensorFlags: flags,
          scenario: g.scenario,
          changeDay: g.changeDay,
        ),
      );
    }
    return StoredSimulation(
      missionId: row.id,
      records: records.length,
      mission: SimulatedMission(
        seed: seed,
        name: row.name,
        crewMember: row.subjectLabel,
        referenceDays: row.referenceDays,
        missionDay: simulatedDay,
        plannedDays: row.plannedDays,
        series: series,
      ),
    );
  }

  // ------------------------------------------------------------------ ledger

  Future<List<Measurement>> _records(String missionId) =>
      (db.select(db.measurements)
            ..where((m) => m.missionId.equals(missionId))
            ..orderBy([(m) => OrderingTerm.asc(m.clientSeq)]))
          .get();

  Future<int> recordCount(String missionId) async {
    final count = db.measurements.id.count();
    final q = db.selectOnly(db.measurements)
      ..addColumns([count])
      ..where(db.measurements.missionId.equals(missionId));
    return (await q.getSingle()).read(count) ?? 0;
  }

  /// Recomputes every record hash of a mission with librakia and checks the
  /// chain links, so tampering with stored values is detected.
  Future<LedgerCheck> verifyLedger(String missionId, RakiaCore core) async {
    final records = await _records(missionId);
    var prev = Uint8List(32);
    for (var k = 0; k < records.length; k++) {
      final r = records[k];
      final seq = k + 1;
      if (r.clientSeq != seq) {
        return LedgerCheck(
          records: records.length,
          failedAtSeq: seq,
          reason: 'Record $seq is missing',
        );
      }
      if (!listEquals(r.prevHash, prev)) {
        return LedgerCheck(
          records: records.length,
          failedAtSeq: seq,
          reason: 'Record $seq does not link to the record before it',
        );
      }
      final Uint8List expected;
      try {
        expected = core.recordHash(
          LedgerRecord(
            id: r.id,
            subjectId: r.subjectId,
            metricCode: r.metricCode,
            value: r.value,
            unit: r.unit,
            observedAtUs: r.observedAtUs,
            method: MeasurementMethod.values.firstWhere(
              (m) => m.code == r.method,
            ),
            provenance: Provenance.values.firstWhere(
              (p) => p.code == r.provenance,
            ),
            clientSeq: r.clientSeq,
            prevHash: r.prevHash,
          ),
        );
      } on Object catch (e) {
        return LedgerCheck(
          records: records.length,
          failedAtSeq: seq,
          reason: 'Record $seq cannot be hashed: $e',
        );
      }
      if (!listEquals(expected, r.hash)) {
        return LedgerCheck(
          records: records.length,
          failedAtSeq: seq,
          reason: 'Record $seq does not match its hash',
        );
      }
      prev = r.hash;
    }
    return LedgerCheck(records: records.length);
  }
}
