// Firebase Authentication through its documented REST API (Identity
// Toolkit and Secure Token), so the app needs no SDK scripts from a CDN and
// works the same on every platform. Email and password only: Phone sign-in
// needs Firebase's paid plan.
// https://firebase.google.com/docs/reference/rest/auth
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A signed-in Firebase user and their tokens.
@immutable
class FirebaseSession {
  const FirebaseSession({
    required this.uid,
    required this.email,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
    this.emailVerified = false,
  });

  final String uid;
  final String email;

  /// Short-lived (one hour) proof of sign-in, sent to the RAKIA API.
  final String idToken;

  /// Long-lived; exchanged for new ID tokens. Kept on the device only.
  final String refreshToken;
  final DateTime expiresAt;
  final bool emailVerified;

  /// Whether the ID token should be refreshed before use.
  bool expiresSoon(DateTime now) =>
      now.isAfter(expiresAt.subtract(const Duration(minutes: 5)));

  FirebaseSession copyWith({
    String? idToken,
    String? refreshToken,
    DateTime? expiresAt,
    bool? emailVerified,
  }) => FirebaseSession(
    uid: uid,
    email: email,
    idToken: idToken ?? this.idToken,
    refreshToken: refreshToken ?? this.refreshToken,
    expiresAt: expiresAt ?? this.expiresAt,
    emailVerified: emailVerified ?? this.emailVerified,
  );
}

/// A refusal or failure, in words for the user. [code] is Firebase's error
/// code when there is one.
class FirebaseAuthException implements Exception {
  const FirebaseAuthException(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => message;
}

/// Firebase's error codes in plain language. Sign-in failures do not say
/// whether the email exists.
String describeFirebaseError(String code) {
  final base = code.split(' ').first.split(':').first.trim();
  return switch (base) {
    'EMAIL_EXISTS' =>
      'An account with this email already exists. Sign in instead.',
    'EMAIL_NOT_FOUND' ||
    'INVALID_PASSWORD' ||
    'INVALID_LOGIN_CREDENTIALS' => 'The email or password is not correct.',
    'USER_DISABLED' => 'This account has been disabled.',
    'TOO_MANY_ATTEMPTS_TRY_LATER' =>
      'Too many attempts. Wait a few minutes and try again.',
    'WEAK_PASSWORD' => 'Choose a password of at least 8 characters.',
    'INVALID_EMAIL' || 'MISSING_EMAIL' => 'Enter a valid email address.',
    'MISSING_PASSWORD' => 'Enter your password.',
    'OPERATION_NOT_ALLOWED' =>
      'Email sign-in is not enabled for this RAKIA project.',
    'TOKEN_EXPIRED' ||
    'USER_NOT_FOUND' ||
    'INVALID_REFRESH_TOKEN' ||
    'INVALID_ID_TOKEN' => 'Your sign-in has expired. Sign in again.',
    _ => 'Sign-in failed ($base).',
  };
}

class FirebaseAuthClient {
  FirebaseAuthClient({
    required this.apiKey,
    this.emulatorHost = '',
    http.Client? client,
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now;

  final String apiKey;

  /// host:port of the Auth emulator, or empty for Google's servers.
  final String emulatorHost;
  final http.Client _client;
  final DateTime Function() _clock;

  static const Duration timeout = Duration(seconds: 30);

  bool get usesEmulator => emulatorHost.isNotEmpty;

  Uri _identity(String method) => usesEmulator
      ? Uri.parse(
          'http://$emulatorHost/identitytoolkit.googleapis.com/v1/accounts:'
          '$method?key=$apiKey',
        )
      : Uri.https('identitytoolkit.googleapis.com', '/v1/accounts:$method', {
          'key': apiKey,
        });

  Uri get _token => usesEmulator
      ? Uri.parse(
          'http://$emulatorHost/securetoken.googleapis.com/v1/token?key=$apiKey',
        )
      : Uri.https('securetoken.googleapis.com', '/v1/token', {'key': apiKey});

  Future<Map<String, Object?>> _post(
    Uri uri,
    Object body, {
    bool form = false,
  }) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            uri,
            headers: {
              'Content-Type': form
                  ? 'application/x-www-form-urlencoded'
                  : 'application/json',
            },
            body: form ? body : jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const FirebaseAuthException('The sign-in service did not answer.');
    } on Object {
      throw const FirebaseAuthException(
        'The sign-in service cannot be reached. Check your connection.',
      );
    }
    Object? json;
    try {
      json = jsonDecode(res.body);
    } on FormatException {
      json = null;
    }
    if (res.statusCode != 200) {
      final message =
          json is Map<String, Object?> && json['error'] is Map<String, Object?>
          ? (json['error']! as Map<String, Object?>)['message']
          : null;
      final code = message is String ? message : 'HTTP_${res.statusCode}';
      throw FirebaseAuthException(describeFirebaseError(code), code: code);
    }
    if (json is! Map<String, Object?>) {
      throw const FirebaseAuthException(
        'The sign-in service sent an unexpected answer.',
      );
    }
    return json;
  }

  static String _str(Map<String, Object?> m, String k) {
    final v = m[k];
    if (v is String && v.isNotEmpty) return v;
    throw FirebaseAuthException(
      'The sign-in service sent an unexpected answer ($k).',
    );
  }

  DateTime _expiry(Map<String, Object?> m, String k) {
    final seconds = int.tryParse('${m[k]}');
    if (seconds == null || seconds <= 0) {
      throw const FirebaseAuthException(
        'The sign-in service sent an unexpected answer (expiry).',
      );
    }
    return _clock().toUtc().add(Duration(seconds: seconds));
  }

  FirebaseSession _session(Map<String, Object?> j, String email) =>
      FirebaseSession(
        uid: _str(j, 'localId'),
        email: (j['email'] as String?) ?? email,
        idToken: _str(j, 'idToken'),
        refreshToken: _str(j, 'refreshToken'),
        expiresAt: _expiry(j, 'expiresIn'),
      );

  Future<FirebaseSession> signUp(String email, String password) async =>
      _session(
        await _post(_identity('signUp'), {
          'email': email,
          'password': password,
          'returnSecureToken': true,
        }),
        email,
      );

  Future<FirebaseSession> signIn(String email, String password) async {
    final s = _session(
      await _post(_identity('signInWithPassword'), {
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
      email,
    );
    return lookup(s);
  }

  /// Exchanges the refresh token for a new ID token.
  Future<FirebaseSession> refresh(FirebaseSession s) async {
    final j = await _post(
      _token,
      'grant_type=refresh_token&refresh_token='
      '${Uri.encodeQueryComponent(s.refreshToken)}',
      form: true,
    );
    final uid = _str(j, 'user_id');
    if (uid != s.uid) {
      throw const FirebaseAuthException(
        'The sign-in service returned another user.',
      );
    }
    return s.copyWith(
      idToken: _str(j, 'id_token'),
      refreshToken: _str(j, 'refresh_token'),
      expiresAt: _expiry(j, 'expires_in'),
    );
  }

  /// Reads the account's current state (whether the email is verified).
  Future<FirebaseSession> lookup(FirebaseSession s) async {
    final j = await _post(_identity('lookup'), {'idToken': s.idToken});
    final users = j['users'];
    if (users is! List || users.isEmpty || users.first is! Map) {
      throw const FirebaseAuthException(
        'The sign-in service sent an unexpected answer (users).',
      );
    }
    final u = users.first as Map<String, Object?>;
    return s.copyWith(emailVerified: u['emailVerified'] == true);
  }

  Future<void> sendEmailVerification(FirebaseSession s) => _post(
    _identity('sendOobCode'),
    {'requestType': 'VERIFY_EMAIL', 'idToken': s.idToken},
  );

  Future<void> sendPasswordReset(String email) => _post(
    _identity('sendOobCode'),
    {'requestType': 'PASSWORD_RESET', 'email': email},
  );

  void close() => _client.close();
}
