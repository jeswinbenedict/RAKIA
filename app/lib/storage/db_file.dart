/// What is on disk where the native database belongs.
enum DatabaseFileState {
  /// No file, or an empty one: a new database.
  absent,

  /// A database written without encryption (before encryption at rest).
  plaintext,

  /// Anything else; RAKIA only writes encrypted databases.
  encrypted,
}

/// The 16-byte header every unencrypted SQLite file starts with.
const List<int> kSqlitePlaintextHeader = [
  0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66, // "SQLite f"
  0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00, // "ormat 3\0"
];

DatabaseFileState classifyDatabaseHeader(List<int> header) {
  if (header.isEmpty) return DatabaseFileState.absent;
  if (header.length >= kSqlitePlaintextHeader.length) {
    var plain = true;
    for (var i = 0; i < kSqlitePlaintextHeader.length; i++) {
      if (header[i] != kSqlitePlaintextHeader[i]) plain = false;
    }
    if (plain) return DatabaseFileState.plaintext;
  }
  return DatabaseFileState.encrypted;
}
