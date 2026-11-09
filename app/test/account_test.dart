// Sign-in: the Firebase REST client (requests, emulator routing, errors in
// words), the RAKIA account API, and the controller's states, persistence
// (the password is never stored) and offline behaviour.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakia/account/account_api.dart';
import 'package:rakia/account/account_controller.dart';
import 'package:rakia/account/firebase_auth_client.dart';
import 'package:rakia/storage/local_store.dart';

import 'account_fakes.dart';
import 'helpers.dart';

void main() {
  late LocalStore store;
  setUp(() => store = newMemoryStore());
  tearDown(() => store.close());

  group('Firebase REST client', () {
    test('talks to Google with the web API key, or to the emulator', () async {
      final seen = <Uri>[];
      final client = MockClient((req) async {
        seen.add(req.url);
        return http.Response(
          jsonEncode({
            'localId': 'u1',
            'email': 'a@example.test',
            'idToken': 'id-u1-1',
            'refreshToken': 'r1',
            'expiresIn': '3600',
          }),
          200,
        );
      });
      await FirebaseAuthClient(
        apiKey: 'k1',
        client: client,
      ).signUp('a@example.test', 'password1');
      expect(
        seen.last.toString(),
        'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=k1',
      );
      await FirebaseAuthClient(
        apiKey: 'k1',
        emulatorHost: '127.0.0.1:9099',
        client: client,
      ).signUp('a@example.test', 'password1');
      expect(
        seen.last.toString(),
        'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/'
        'accounts:signUp?key=k1',
      );
    });

    test(
      'Firebase errors are explained without revealing which part was wrong',
      () {
        expect(
          describeFirebaseError('INVALID_LOGIN_CREDENTIALS'),
          describeFirebaseError('EMAIL_NOT_FOUND'),
        );
        expect(
          describeFirebaseError(
            'WEAK_PASSWORD : Password should be at least 6 characters',
          ),
          contains('8 characters'),
        );
        expect(
          describeFirebaseError('EMAIL_EXISTS'),
          contains('already exists'),
        );
        expect(
          describeFirebaseError('SOMETHING_NEW'),
          contains('SOMETHING_NEW'),
        );
      },
    );

    test('a refresh that returns another user is refused', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'id_token': 'x',
            'refresh_token': 'y',
            'expires_in': '3600',
            'user_id': 'someone-else',
          }),
          200,
        ),
      );
      final s = FirebaseSession(
        uid: 'u1',
        email: 'a@example.test',
        idToken: '',
        refreshToken: 'r',
        expiresAt: DateTime.utc(2026),
      );
      await expectLater(
        FirebaseAuthClient(apiKey: 'k', client: client).refresh(s),
        throwsA(isA<FirebaseAuthException>()),
      );
    });

    test('an unreachable service is reported in words', () async {
      final client = MockClient((_) async => throw http.ClientException('x'));
      await expectLater(
        FirebaseAuthClient(
          apiKey: 'k',
          client: client,
        ).signIn('a@example.test', 'p'),
        throwsA(
          isA<FirebaseAuthException>()
              .having(
                (e) => e.message,
                'message',
                contains('cannot be reached'),
              )
              .having((e) => e.code, 'code', isNull),
        ),
      );
    });
  });

  group('account API', () {
    test('GET without an account is NoAccountYet; POST sends the Turnstile '
        'token and the bearer token', () async {
      final api = FakeApi();
      final client = AccountApi(
        baseUrl: 'https://api.example.test',
        client: api.client,
      );
      await expectLater(
        client.fetch('id-uid-1-1'),
        throwsA(isA<NoAccountYet>()),
      );
      await expectLater(
        client.create('id-uid-1-1'),
        throwsA(
          isA<AccountApiException>()
              .having((e) => e.status, 'status', 403)
              .having((e) => e.message, 'message', contains('bot check')),
        ),
      );
      final a = await client.create('id-uid-1-1', turnstileToken: 'ts-1');
      expect(a.roles, isEmpty);
      expect(api.turnstileTokens.last, 'ts-1');
      expect((await client.fetch('id-uid-1-1')).id, a.id);
    });
  });

  group('controller', () {
    test('without a Firebase key or API it is unavailable', () async {
      final c = AccountController();
      await c.attach(store);
      expect(c.status, AccountStatus.unavailable);
      c.dispose();
    });

    test(
      'creating an account: Firebase sign-up, verification email, RAKIA '
      'account with the Turnstile token; the password is never stored',
      () async {
        final fb = FakeFirebase();
        final api = FakeApi();
        final c = controllerFor(fb, api);
        await c.attach(store);
        expect(c.status, AccountStatus.signedOut);

        await c.signUp(
          'astro@example.test',
          'correct-horse',
          turnstileToken: 'ts-1',
        );
        expect(c.error, isNull);
        expect(c.status, AccountStatus.signedIn);
        expect(c.account, isNotNull);
        expect(api.turnstileTokens, ['ts-1']);
        await pumpEventQueue();
        expect(fb.oobRequests.single['requestType'], 'VERIFY_EMAIL');

        final saved = await store.setting(AccountController.sessionKey);
        expect(saved, isNotNull);
        expect(saved, isNot(contains('correct-horse')));
        // Only what is needed to restore the sign-in: no password, no ID token.
        expect((jsonDecode(saved!) as Map).keys.toSet(), {
          'uid',
          'email',
          'refresh',
        });
        c.dispose();
      },
    );

    test('a short password is refused before anything is sent', () async {
      final fb = FakeFirebase();
      final c = controllerFor(fb, FakeApi());
      await c.attach(store);
      await c.signUp('astro@example.test', 'short', turnstileToken: 'ts');
      expect(c.error, contains('8 characters'));
      expect(fb.requests, isEmpty);
      expect(c.status, AccountStatus.signedOut);
      c.dispose();
    });

    test(
      'sign-in with the wrong password stays signed out and says why',
      () async {
        final fb = FakeFirebase()
          ..users['astro@example.test'] = (
            password: 'correct-horse',
            uid: 'uid-1',
            verified: false,
          );
        final c = controllerFor(fb, FakeApi());
        await c.attach(store);
        await c.signIn('astro@example.test', 'wrong');
        expect(c.status, AccountStatus.signedOut);
        expect(c.error, 'The email or password is not correct.');
        c.dispose();
      },
    );

    test('a sign-in without a RAKIA account asks for one; the bot check then '
        'creates it', () async {
      final fb = FakeFirebase()
        ..users['astro@example.test'] = (
          password: 'correct-horse',
          uid: 'uid-1',
          verified: true,
        );
      final api = FakeApi();
      final c = controllerFor(fb, api);
      await c.attach(store);
      await c.signIn('astro@example.test', 'correct-horse');
      expect(c.status, AccountStatus.needsAccount);
      expect(c.session!.emailVerified, isTrue);
      await c.createAccount('ts-2');
      expect(c.status, AccountStatus.signedIn);
      c.dispose();
    });

    test('the sign-in is restored after a restart, and forgotten when '
        'Firebase refuses it', () async {
      final fb = FakeFirebase()
        ..users['astro@example.test'] = (
          password: 'correct-horse',
          uid: 'uid-1',
          verified: false,
        );
      final api = FakeApi()..accounts.add('uid-1');
      final first = controllerFor(fb, api);
      await first.attach(store);
      await first.signIn('astro@example.test', 'correct-horse');
      expect(first.status, AccountStatus.signedIn);
      first.dispose();

      // Verified while the app was closed: the restored sign-in knows.
      fb.users['astro@example.test'] = (
        password: 'correct-horse',
        uid: 'uid-1',
        verified: true,
      );
      final again = controllerFor(fb, api);
      await again.attach(store);
      expect(again.status, AccountStatus.signedIn);
      expect(again.session!.email, 'astro@example.test');
      expect(again.session!.emailVerified, isTrue);
      again.dispose();

      fb.refreshTokens.clear(); // revoked
      final revoked = controllerFor(fb, api);
      await revoked.attach(store);
      expect(revoked.status, AccountStatus.signedOut);
      expect(await store.setting(AccountController.sessionKey), isNull);
      revoked.dispose();
    });

    test('offline at start-up keeps the saved sign-in', () async {
      final fb = FakeFirebase()
        ..users['astro@example.test'] = (
          password: 'correct-horse',
          uid: 'uid-1',
          verified: false,
        );
      final api = FakeApi()..accounts.add('uid-1');
      final first = controllerFor(fb, api);
      await first.attach(store);
      await first.signIn('astro@example.test', 'correct-horse');
      first.dispose();

      fb.offline = true;
      final c = controllerFor(fb, api);
      await c.attach(store);
      expect(c.status, AccountStatus.signedIn);
      expect(c.error, contains('cannot be reached'));
      expect(await store.setting(AccountController.sessionKey), isNotNull);
      c.dispose();
    });

    test('an ID token about to expire is refreshed before use', () async {
      var now = DateTime.utc(2026, 11, 9, 10);
      final fb = FakeFirebase()
        ..users['astro@example.test'] = (
          password: 'correct-horse',
          uid: 'uid-1',
          verified: false,
        );
      final api = FakeApi()..accounts.add('uid-1');
      final c = controllerFor(fb, api, clock: () => now);
      await c.attach(store);
      await c.signIn('astro@example.test', 'correct-horse');
      final before = c.session!.idToken;
      expect((await c.validSession()).idToken, before);
      now = now.add(const Duration(minutes: 58));
      expect((await c.validSession()).idToken, isNot(before));
      c.dispose();
    });

    test('signing out forgets the saved sign-in', () async {
      final fb = FakeFirebase()
        ..users['astro@example.test'] = (
          password: 'correct-horse',
          uid: 'uid-1',
          verified: false,
        );
      final api = FakeApi()..accounts.add('uid-1');
      final c = controllerFor(fb, api);
      await c.attach(store);
      await c.signIn('astro@example.test', 'correct-horse');
      await c.signOut();
      expect(c.status, AccountStatus.signedOut);
      expect(c.session, isNull);
      expect(await store.setting(AccountController.sessionKey), isNull);
      c.dispose();
    });

    test('password reset asks Firebase to send the link', () async {
      final fb = FakeFirebase();
      final c = controllerFor(fb, FakeApi());
      await c.attach(store);
      await c.sendPasswordReset(' astro@example.test ');
      expect(fb.oobRequests.single, {
        'requestType': 'PASSWORD_RESET',
        'email': 'astro@example.test',
      });
      expect(c.status, AccountStatus.signedOut);
      c.dispose();
    });
  });
}
