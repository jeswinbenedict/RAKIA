import 'package:drift/drift.dart';

part 'database.g.dart';

/// The on-device SQLite database (schema in schema.drift).
///
/// Use [LocalStore] rather than this class directly: it adds ledger hashing
/// and the mission-level operations the app needs.
@DriftDatabase(include: {'schema.drift'})
class RakiaDatabase extends _$RakiaDatabase {
  RakiaDatabase(super.executor);

  /// Bump with every schema change, add a migration step in [migration] and
  /// export the new schema (`dart run drift_dev schema dump ...`, see
  /// docs/DEVELOPMENT.md). Version history:
  ///   1  settings, missions, measurements (hash-chained ledger)
  ///   2  self_checkins and reaction_tests (private wellbeing records)
  ///   3  alert_responses (what the astronaut did about an alert)
  static const int currentSchemaVersion = 3;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from > to) {
        // Written by a newer build: refuse rather than guess, so it is
        // never silently reinterpreted.
        throw UnsupportedError(
          'The local database uses schema version $from; this build of RAKIA '
          'supports version $to.',
        );
      }
      if (from < 2) {
        for (final entity in <DatabaseSchemaEntity>[
          selfCheckins,
          selfCheckinsByTime,
          selfCheckinsImmutable,
          reactionTests,
          reactionTestsByTime,
          reactionTestsImmutable,
        ]) {
          await m.create(entity);
        }
      }
      if (from < 3) {
        for (final entity in <DatabaseSchemaEntity>[
          alertResponses,
          alertResponsesByMetric,
          alertResponsesRealOnly,
          alertResponsesImmutable,
          alertResponsesKept,
        ]) {
          await m.create(entity);
        }
      }
    },
    beforeOpen: (details) async {
      // ON DELETE CASCADE and REFERENCES are only enforced with this pragma.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
