// HTTP-level stand-ins for Firebase Authentication's REST API and the RAKIA
// API's /v1/me, following their documented requests and answers, so the
// real clients and controller run unchanged. The end-to-end check against
// the Firebase Auth emulator and the real API is in docs/DEVELOPMENT.md.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakia/account/account_api.dart';
import 'package:rakia/account/account_controller.dart';
import 'package:rakia/account/firebase_auth_client.dart';

class FakeFirebase {
  final Map<String, ({String password, String uid, bool verified})> users = {};
  final Map<String, String> refreshTokens = {}; // refresh token -> uid
  final List<String> requests = [];
  final List<Map<String, Object?>> oobRequests = [];
  bool offline = false;
  int _n = 0;

  http.Response _error(String message) => http.Response(
    jsonEncode({
      'error': {'code': 400, 'message': message},
    }),
    400,
  );

  Map<String, Object?> _tokens(String uid, String email) {
    final refresh = 'refresh-${++_n}';
    refreshTokens[refresh] = uid;
    return {
      'localId': uid,
      'email': email,
      'idToken': 'id-$uid-$_n',
      'refreshToken': refresh,
      'expiresIn': '3600',
    };
  }

  MockClient get client => MockClient((req) async {
    if (offline) throw http.ClientException('offline');
    final path = req.url.path;
    requests.add('${req.url.host}$path');
    if (path.endsWith('/v1/token')) {
      final form = Uri.splitQueryString(req.body);
      final uid = refreshTokens[form['refresh_token']];
      if (uid == null) return _error('INVALID_REFRESH_TOKEN');
      final t = _tokens(uid, '');
      return http.Response(
        jsonEncode({
          'id_token': t['idToken'],
          'refresh_token': t['refreshToken'],
          'expires_in': '3600',
          'user_id': uid,
        }),
        200,
      );
    }
    final body = jsonDecode(req.body) as Map<String, Object?>;
    final method = path.split(':').last;
    switch (method) {
      case 'signUp':
        final email = body['email']! as String;
        final password = body['password']! as String;
        if (users.containsKey(email)) return _error('EMAIL_EXISTS');
        if (password.length < 6) {
          return _error(
            'WEAK_PASSWORD : Password should be at least 6 characters',
          );
        }
        final uid = 'uid-${users.length + 1}';
        users[email] = (password: password, uid: uid, verified: false);
        return http.Response(jsonEncode(_tokens(uid, email)), 200);
      case 'signInWithPassword':
        final email = body['email']! as String;
        final u = users[email];
        if (u == null || u.password != body['password']) {
          return _error('INVALID_LOGIN_CREDENTIALS');
        }
        return http.Response(jsonEncode(_tokens(u.uid, email)), 200);
      case 'lookup':
        final token = body['idToken']! as String;
        final entry = users.entries.firstWhere(
          (e) => token.startsWith('id-${e.value.uid}-'),
        );
        return http.Response(
          jsonEncode({
            'users': [
              {
                'localId': entry.value.uid,
                'email': entry.key,
                'emailVerified': entry.value.verified,
              },
            ],
          }),
          200,
        );
      case 'sendOobCode':
        oobRequests.add(body);
        return http.Response(jsonEncode({'email': body['email'] ?? ''}), 200);
    }
    return http.Response('', 404);
  });
}

/// /v1/me on the RAKIA API.
class FakeApi {
  final Set<String> accounts = {}; // firebase uids
  final List<String?> turnstileTokens = [];
  bool requireTurnstile = true;

  static String uidOf(String idToken) =>
      idToken.split('-').sublist(1, 3).join('-');

  MockClient get client => MockClient((req) async {
    final auth = req.headers['Authorization'] ?? '';
    if (!auth.startsWith('Bearer id-')) {
      return http.Response(
        jsonEncode({
          'error': {'code': 'invalid_token', 'message': 'Sign in again.'},
        }),
        401,
      );
    }
    final uid = uidOf(auth.substring('Bearer '.length));
    Map<String, Object?> account() => {
      'user': {
        'id': '0190b8f4-0000-7000-8000-00000000000${accounts.length}',
        'firebase_uid': uid,
        'display_name': null,
        'created_at': '2026-11-09T10:00:00Z',
      },
      'memberships': <Object>[],
    };
    if (req.method == 'GET') {
      if (!accounts.contains(uid)) {
        return http.Response(
          jsonEncode({
            'error': {'code': 'no_account', 'message': 'No account.'},
          }),
          404,
        );
      }
      return http.Response(jsonEncode(account()), 200);
    }
    final token = req.headers['X-Turnstile-Token'];
    turnstileTokens.add(token);
    if (accounts.contains(uid)) {
      return http.Response(jsonEncode(account()), 200);
    }
    if (requireTurnstile && (token == null || token.isEmpty)) {
      return http.Response(
        jsonEncode({
          'error': {
            'code': 'turnstile_failed',
            'message':
                'The bot check did not pass. Complete it again and retry.',
          },
        }),
        403,
      );
    }
    accounts.add(uid);
    return http.Response(jsonEncode(account()), 201);
  });
}

AccountController controllerFor(
  FakeFirebase fb,
  FakeApi api, {
  DateTime Function()? clock,
  String emulatorHost = '',
}) => AccountController(
  auth: FirebaseAuthClient(
    apiKey: 'test-web-api-key',
    emulatorHost: emulatorHost,
    client: fb.client,
    clock: clock,
  ),
  api: AccountApi(baseUrl: 'https://api.example.test', client: api.client),
  clock: clock,
);
