import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:rakia_core/rakia_core.dart';

import '../analytics/metric_definitions.dart';
import '../analytics/metric_series.dart';
import '../record/record.dart';
import '../simulation/simulated_mission.dart';
import '../wellbeing/instruments.dart';
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

/// How the database is protected at rest, as found when it was opened.
@immutable
class StoreEncryption {
  /// Encrypted with [cipher], as reported by the SQLite library itself.
  const StoreEncryption.cipher(String this.cipher)
    : label = cipher == 'chacha20' ? 'ChaCha20-Poly1305' : cipher,
      note =
          'The database file is encrypted. Its 256-bit key was generated on '
          "this device and is kept in the system's secure keystore, never in "
          "the file or in RAKIA's code.";

  /// A browser database: browsers give RAKIA no protected place for a key.
  const StoreEncryption.browser()
    : cipher = null,
      label = 'Not available in browsers',
      note =
          'A browser offers no protected place to keep an encryption key, so '
          'RAKIA does not encrypt data stored in a browser. The desktop and '
          'mobile apps encrypt it.';

  /// A database file written without encryption.
  const StoreEncryption.none()
    : cipher = null,
      label = 'Not encrypted',
      note = 'The database file is not encrypted.';

  /// Nothing is written to disk.
  const StoreEncryption.notApplicable()
    : cipher = null,
      label = 'Not applicable',
      note = 'Nothing is written to disk.';

  factory StoreEncryption.forUnencrypted(StorageKind kind) => switch (kind) {
    StorageKind.browserOpfs ||
    StorageKind.browserIndexedDb => const StoreEncryption.browser(),
    StorageKind.memory => const StoreEncryption.notApplicable(),
    StorageKind.nativeFile => const StoreEncryption.none(),
  };

  /// SQLite3 Multiple Ciphers' name for the cipher, or null when the
  /// database is not encrypted.
  final String? cipher;
  final String label;
  final String note;

  bool get encrypted => cipher != null;
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
  LocalStore(this.db, {required this.kind, StoreEncryption? encryption})
    : encryption = encryption ?? StoreEncryption.forUnencrypted(kind);

  final RakiaDatabase db;
  final StorageKind kind;
  final StoreEncryption encryption;

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

  // --------------------------------------------------------------- wellbeing
  // The astronaut's private self-reports. They belong to no mission, so they
  // can never mix with simulated data.

  Future<CheckIn> addCheckIn({
    required int sleepiness,
    required int stress,
    required int mood,
    DateTime? now,
  }) async {
    final at = (now ?? DateTime.now()).toUtc();
    final id = uuidV7(now: at);
    await db
        .into(db.selfCheckins)
        .insert(
          SelfCheckinsCompanion.insert(
            id: id,
            recordedAtUs: at.microsecondsSinceEpoch,
            sleepiness: sleepiness,
            stress: stress,
            mood: mood,
          ),
        );
    return CheckIn(
      id: uuidToString(id),
      recordedAt: at,
      sleepiness: sleepiness,
      stress: stress,
      mood: mood,
    );
  }

  /// Check-ins, newest first.
  Future<List<CheckIn>> checkIns({int limit = 500}) async {
    final rows =
        await (db.select(db.selfCheckins)
              ..orderBy([(c) => OrderingTerm.desc(c.recordedAtUs)])
              ..limit(limit))
            .get();
    return [
      for (final r in rows)
        CheckIn(
          id: uuidToString(r.id),
          recordedAt: DateTime.fromMicrosecondsSinceEpoch(
            r.recordedAtUs,
            isUtc: true,
          ),
          sleepiness: r.sleepiness,
          stress: r.stress,
          mood: r.mood,
        ),
    ];
  }

  /// Stores a scored test and returns it with its identifier.
  Future<ReactionTestResult> addReactionTest(ReactionTestResult t) async {
    final id = uuidV7(now: t.recordedAt);
    await db
        .into(db.reactionTests)
        .insert(
          ReactionTestsCompanion.insert(
            id: id,
            recordedAtUs: t.recordedAt.toUtc().microsecondsSinceEpoch,
            durationMs: t.duration.inMilliseconds,
            stimuli: t.stimuli,
            responses: t.responses,
            medianRtMs: Value(t.medianRtMs),
            meanSpeed: Value(t.meanSpeed),
            lapses: t.lapses,
            falseStarts: t.falseStarts,
            device: t.device,
          ),
        );
    return t.withId(uuidToString(id));
  }

  /// Reaction-time results, newest first.
  Future<List<ReactionTestResult>> reactionTests({int limit = 500}) async {
    final rows =
        await (db.select(db.reactionTests)
              ..orderBy([(t) => OrderingTerm.desc(t.recordedAtUs)])
              ..limit(limit))
            .get();
    return [
      for (final r in rows)
        ReactionTestResult(
          id: uuidToString(r.id),
          recordedAt: DateTime.fromMicrosecondsSinceEpoch(
            r.recordedAtUs,
            isUtc: true,
          ),
          duration: Duration(milliseconds: r.durationMs),
          stimuli: r.stimuli,
          responses: r.responses,
          medianRtMs: r.medianRtMs,
          meanSpeed: r.meanSpeed,
          lapses: r.lapses,
          falseStarts: r.falseStarts,
          device: r.device,
        ),
    ];
  }

  /// Deletes every check-in and reaction-time result on this device.
  Future<void> deleteWellbeingRecords() => db.transaction(() async {
    await db.delete(db.selfCheckins).go();
    await db.delete(db.reactionTests).go();
  });

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
    void add(MetricSeries s, int day, double v, int flags) {
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
    final series = <MetricSeries>[];
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
        MetricSeries(
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

  // ---------------------------------------------------- personal record

  /// The astronaut's own real record, if one exists. There is at most one
  /// real mission on a device today.
  Future<String?> personalRecordId() async {
    final row =
        await (db.select(db.missions)
              ..where((m) => m.isSimulation.equals(0))
              ..orderBy([(m) => OrderingTerm.asc(m.createdAtUs)])
              ..limit(1))
            .getSingleOrNull();
    return row?.id;
  }

  /// Creates the personal record (a real, non-simulation mission). Real
  /// missions can never be deleted, and nothing simulated may enter them.
  Future<String> createPersonalRecord({
    required String label,
    DateTime? now,
  }) async {
    final existing = await personalRecordId();
    if (existing != null) return existing;
    final created = (now ?? DateTime.now()).toUtc();
    final id = uuidToString(uuidV7(now: created));
    await db
        .into(db.missions)
        .insert(
          MissionsCompanion.insert(
            id: id,
            name: 'My health record',
            isSimulation: 0,
            subjectId: uuidV7(now: created),
            subjectLabel: label,
            startAtUs: DateTime.utc(
              created.year,
              created.month,
              created.day,
            ).microsecondsSinceEpoch,
            referenceDays: RecordWindows.referenceDays,
            plannedDays: 365,
            createdAtUs: created.microsecondsSinceEpoch,
          ),
        );
    return id;
  }

  /// Appends a reading the user entered, linked into the record's hash
  /// chain. A correction names the entry it replaces; nothing is
  /// overwritten.
  Future<RecordEntry> addRecordEntry({
    required String recordId,
    required MetricDefinition metric,
    required double value,
    required DateTime day,
    required RakiaCore core,
    String? supersedesId,
    DateTime? now,
  }) async {
    if (!value.isFinite ||
        value < metric.plausibleMin ||
        value > metric.plausibleMax) {
      throw ArgumentError.value(value, 'value', 'outside the plausible range');
    }
    final created = (now ?? DateTime.now()).toUtc();
    return db.transaction(() async {
      final mission = await (db.select(
        db.missions,
      )..where((m) => m.id.equals(recordId))).getSingle();
      if (mission.isSimulation != 0) {
        throw StoreIntegrityError('$recordId is not a real record');
      }
      final last =
          await (db.select(db.measurements)
                ..where((m) => m.missionId.equals(recordId))
                ..orderBy([(m) => OrderingTerm.desc(m.clientSeq)])
                ..limit(1))
              .getSingleOrNull();
      final seq = (last?.clientSeq ?? 0) + 1;
      final prev = last?.hash ?? Uint8List(32);
      final id = uuidV7(now: created);
      // Noon of the chosen date, so the reading stays on that date.
      final observedAtUs = day.microsecondsSinceEpoch + _dayUs ~/ 2;
      final hash = core.recordHash(
        LedgerRecord(
          id: id,
          subjectId: mission.subjectId,
          metricCode: metric.code,
          value: value,
          unit: metric.ucum,
          observedAtUs: observedAtUs,
          method: MeasurementMethod.manual,
          provenance: Provenance.real,
          clientSeq: seq,
          prevHash: prev,
        ),
      );
      await db
          .into(db.measurements)
          .insert(
            MeasurementsCompanion.insert(
              id: id,
              missionId: recordId,
              subjectId: mission.subjectId,
              metricCode: metric.code,
              value: value,
              unit: metric.ucum,
              observedAtUs: observedAtUs,
              method: MeasurementMethod.manual.code,
              provenance: Provenance.real.code,
              supersedesId: Value(
                supersedesId == null ? null : uuidFromString(supersedesId),
              ),
              clientSeq: seq,
              prevHash: prev,
              hash: hash,
            ),
          );
      return RecordEntry(
        id: uuidToString(id),
        metricCode: metric.code,
        value: value,
        unit: metric.ucum,
        day: day,
        seq: seq,
        supersedesId: supersedesId,
      );
    });
  }

  /// Every entry in the record, in ledger order.
  Future<List<RecordEntry>> recordEntries(String recordId) async {
    final rows = await _records(recordId);
    return [
      for (final r in rows)
        RecordEntry(
          id: uuidToString(r.id),
          metricCode: r.metricCode,
          value: r.value,
          unit: r.unit,
          day: () {
            final t = DateTime.fromMicrosecondsSinceEpoch(
              r.observedAtUs,
              isUtc: true,
            );
            return DateTime.utc(t.year, t.month, t.day);
          }(),
          seq: r.clientSeq,
          supersedesId: r.supersedesId == null
              ? null
              : uuidToString(r.supersedesId!),
        ),
    ];
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
