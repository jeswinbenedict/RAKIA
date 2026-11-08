import 'dart:io';

import 'package:postgres/postgres.dart';

/// Reads `KEY=value` lines from a `.env` file. Blank lines and `#` comments
/// are skipped; values are taken literally (no quotes or expansion).
Map<String, String> readEnvFile(String path) {
  final file = File(path);
  if (!file.existsSync()) return const {};
  final values = <String, String>{};
  for (final raw in file.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    values[line.substring(0, eq).trim()] = line.substring(eq + 1).trim();
  }
  return values;
}

/// Connection settings for one database role.
class DbConfig {
  const DbConfig({
    required this.host,
    required this.port,
    required this.database,
    required this.user,
    required this.password,
    required this.sslMode,
    this.sslRootCert,
  });

  /// The migrator's settings (RAKIA_DB_MIGRATOR_USER and _PASSWORD) or, with
  /// [api], the API role's (RAKIA_DB_USER and _PASSWORD). Process
  /// environment variables override the `.env` file.
  factory DbConfig.fromEnvironment({
    required Map<String, String> envFile,
    Map<String, String>? environment,
    bool api = false,
  }) {
    final env = {...envFile, ...(environment ?? Platform.environment)};
    String need(String key) {
      final v = env[key];
      if (v == null || v.isEmpty) {
        throw StateError(
          '$key is not set. Run db/bootstrap/bootstrap-local.ps1 (or .sh) '
          'to create the database roles and .env.',
        );
      }
      return v;
    }

    final prefix = api ? 'RAKIA_DB_' : 'RAKIA_DB_MIGRATOR_';
    final rootCert = env['RAKIA_DB_SSLROOTCERT'];
    final sslModeText = env['RAKIA_DB_SSLMODE'] ?? 'disable';
    if (sslModeText == 'disable' && rootCert != null && rootCert.isNotEmpty) {
      throw StateError(
        'RAKIA_DB_SSLROOTCERT is set but RAKIA_DB_SSLMODE is disable.',
      );
    }
    return DbConfig(
      host: need('RAKIA_DB_HOST'),
      port: int.parse(need('RAKIA_DB_PORT')),
      database: need('RAKIA_DB_NAME'),
      user: need('${prefix}USER'),
      password: need('${prefix}PASSWORD'),
      sslRootCert: rootCert == null || rootCert.isEmpty || rootCert == 'system'
          ? null
          : rootCert,
      sslMode: switch (sslModeText) {
        'disable' => SslMode.disable,
        'require' => SslMode.require,
        'verify-full' => SslMode.verifyFull,
        final other => throw StateError(
          'RAKIA_DB_SSLMODE must be disable, require or verify-full, not '
          '"$other".',
        ),
      },
    );
  }

  final String host;
  final int port;
  final String database;
  final String user;
  final String password;
  final SslMode sslMode;

  /// A CA certificate file that must have signed the server's certificate
  /// (for providers with a private CA, such as Supabase), or null for the
  /// system's trusted roots.
  final String? sslRootCert;

  Future<Connection> open() => Connection.open(
    Endpoint(
      host: host,
      port: port,
      database: database,
      username: user,
      password: password,
    ),
    settings: ConnectionSettings(
      sslMode: sslMode,
      securityContext: sslRootCert == null
          ? null
          : (SecurityContext(withTrustedRoots: false)
              ..setTrustedCertificates(sslRootCert!)),
      applicationName: 'rakia_db',
      connectTimeout: const Duration(seconds: 10),
    ),
  );

  @override
  String toString() => '$user@$host:$port/$database';
}
