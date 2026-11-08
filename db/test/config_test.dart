// Connection settings: which role, TLS modes and the CA certificate option.
import 'package:postgres/postgres.dart';
import 'package:rakia_db/rakia_db.dart';
import 'package:test/test.dart';

void main() {
  const base = {
    'RAKIA_DB_HOST': 'db.example',
    'RAKIA_DB_PORT': '5432',
    'RAKIA_DB_NAME': 'rakia',
    'RAKIA_DB_USER': 'rakia_api',
    'RAKIA_DB_PASSWORD': 'api-secret',
    'RAKIA_DB_MIGRATOR_USER': 'rakia_migrator',
    'RAKIA_DB_MIGRATOR_PASSWORD': 'migrator-secret',
  };
  DbConfig load(Map<String, String> extra, {bool api = false}) =>
      DbConfig.fromEnvironment(
        envFile: {...base, ...extra},
        environment: const {},
        api: api,
      );

  test('the migrator and the API role are selected by prefix', () {
    expect(load({}).user, 'rakia_migrator');
    expect(load({}, api: true).user, 'rakia_api');
  });

  test('the process environment wins over the file', () {
    final c = DbConfig.fromEnvironment(
      envFile: base,
      environment: const {'RAKIA_DB_HOST': 'other.example'},
    );
    expect(c.host, 'other.example');
  });

  test('TLS modes', () {
    expect(load({}).sslMode, SslMode.disable);
    expect(
      load({'RAKIA_DB_SSLMODE': 'verify-full'}).sslMode,
      SslMode.verifyFull,
    );
    expect(() => load({'RAKIA_DB_SSLMODE': 'prefer'}), throwsStateError);
  });

  test('a CA certificate file, or the system roots', () {
    final file = load({
      'RAKIA_DB_SSLMODE': 'verify-full',
      'RAKIA_DB_SSLROOTCERT': '/etc/rakia/db-ca.pem',
    });
    expect(file.sslRootCert, '/etc/rakia/db-ca.pem');
    final system = load({
      'RAKIA_DB_SSLMODE': 'verify-full',
      'RAKIA_DB_SSLROOTCERT': 'system',
    });
    expect(system.sslRootCert, isNull);
    expect(load({'RAKIA_DB_SSLROOTCERT': ''}).sslRootCert, isNull);
    expect(
      () => load({'RAKIA_DB_SSLROOTCERT': '/etc/rakia/db-ca.pem'}),
      throwsStateError,
    );
  });

  test('a missing setting names the variable and the bootstrap', () {
    expect(
      () => DbConfig.fromEnvironment(envFile: const {}, environment: const {}),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(contains('RAKIA_DB_HOST'), contains('bootstrap')),
        ),
      ),
    );
  });

  test('toString never contains a password', () {
    expect(load({}).toString(), isNot(contains('secret')));
  });
}
