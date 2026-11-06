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
  /// export the new schema (`dart run drift_dev make-migrations`).
  static const int currentSchemaVersion = 1;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // No migrations exist yet. Refuse rather than guess, so a database
      // written by a newer build is never silently reinterpreted.
      throw UnsupportedError(
        'The local database uses schema version $from; this build of RAKIA '
        'supports version $to.',
      );
    },
    beforeOpen: (details) async {
      // ON DELETE CASCADE and REFERENCES are only enforced with this pragma.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
