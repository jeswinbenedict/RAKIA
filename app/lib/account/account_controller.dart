import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../storage/local_store.dart';
import 'account_api.dart';
import 'firebase_auth_client.dart';

/// Where sign-in stands.
enum AccountStatus {
  /// This build has no Firebase key or API URL: sign-in is not available.
  unavailable,

  /// Restoring a saved sign-in.
  restoring,
  signedOut,

  /// Signed in with Firebase, but no RAKIA account exists yet: the user
  /// completes the bot check to create it.
  needsAccount,
  signedIn,
}

/// The astronaut's sign-in and RAKIA account. The refresh token is kept in
/// the on-device store (encrypted on native platforms; in browser storage
/// on the web, as the Firebase web SDK also does) and never leaves the
/// device except to Firebase.
class AccountController extends ChangeNotifier {
  AccountController({
    FirebaseAuthClient? auth,
    AccountApi? api,
    DateTime Function()? clock,
  }) : _authClient = auth,
       _apiClient = api,
       _clock = clock ?? DateTime.now;

  final FirebaseAuthClient? _authClient;
  final AccountApi? _apiClient;
  final DateTime Function() _clock;

  static const String sessionKey = 'account.session.v1';

  LocalStore? _store;
  FirebaseSession? _session;
  RakiaAccount? _account;
  String? _error;
  bool _busy = false;
  bool _disposed = false;
  late AccountStatus _status = available
      ? AccountStatus.restoring
      : AccountStatus.unavailable;

  bool get available => _authClient != null && _apiClient != null;
  AccountStatus get status => _status;
  FirebaseSession? get session => _session;
  RakiaAccount? get account => _account;

  /// What went wrong in the last action, in words.
  String? get error => _error;
  bool get busy => _busy;
  bool get usesEmulator => _authClient?.usesEmulator ?? false;

  /// Whether the session is kept after the app closes.
  bool get persistent => _store?.kind.persistent ?? false;

  /// Restores a saved sign-in from [store] (null: keep it in memory only).
  Future<void> attach(LocalStore? store) async {
    _store = store;
    if (!available) return;
    final saved = await _readSaved();
    if (saved == null) {
      _set(AccountStatus.signedOut);
      return;
    }
    _busy = true;
    _notify();
    try {
      _session = await _authClient!.refresh(saved);
      // The refresh does not say whether the email is verified; ask.
      _session = await _authClient.lookup(_session!);
      await _save();
      await _loadAccount();
    } on FirebaseAuthException catch (e) {
      if (e.code != null) {
        // Firebase refused the saved sign-in: forget it.
        _session = null;
        await _forget();
        _status = AccountStatus.signedOut;
      } else {
        // Offline: stay signed in; the token is refreshed when next needed.
        _session = saved;
        _status = AccountStatus.signedIn;
      }
      _error = e.message;
    } on AccountApiException catch (e) {
      _error = e.message;
      _status = AccountStatus.signedIn;
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> signIn(String email, String password) => _run(() async {
    _session = await _authClient!.signIn(email.trim(), password);
    await _save();
    await _loadAccount();
  });

  /// Creates the Firebase sign-in, sends the verification email, and creates
  /// the RAKIA account with the Turnstile token.
  Future<void> signUp(
    String email,
    String password, {
    required String turnstileToken,
  }) => _run(() async {
    if (password.length < 8) {
      throw const FirebaseAuthException(
        'Choose a password of at least 8 characters.',
      );
    }
    _session = await _authClient!.signUp(email.trim(), password);
    await _save();
    unawaited(
      _authClient.sendEmailVerification(_session!).catchError((Object _) {}),
    );
    _status = AccountStatus.needsAccount;
    await _createAccount(turnstileToken);
  });

  /// For a signed-in user without a RAKIA account: creates it.
  Future<void> createAccount(String turnstileToken) =>
      _run(() => _createAccount(turnstileToken));

  Future<void> sendPasswordReset(String email) => _run(() async {
    await _authClient!.sendPasswordReset(email.trim());
  }, keepStatus: true);

  Future<void> resendVerification() => _run(() async {
    await _authClient!.sendEmailVerification(await validSession());
  }, keepStatus: true);

  /// Re-reads whether the email has been verified.
  Future<void> refreshVerification() => _run(() async {
    _session = await _authClient!.lookup(await validSession());
    await _save();
  }, keepStatus: true);

  Future<void> signOut() async {
    _session = null;
    _account = null;
    _error = null;
    await _forget();
    _set(AccountStatus.signedOut);
  }

  /// An ID token that is valid for at least five more minutes.
  Future<FirebaseSession> validSession() async {
    final s = _session;
    if (s == null) {
      throw const FirebaseAuthException('Sign in to continue.');
    }
    if (!s.expiresSoon(_clock().toUtc())) return s;
    _session = await _authClient!.refresh(s);
    await _save();
    return _session!;
  }

  Future<void> _createAccount(String turnstileToken) async {
    final s = await validSession();
    _account = await _apiClient!.create(
      s.idToken,
      turnstileToken: turnstileToken,
    );
    _status = AccountStatus.signedIn;
  }

  Future<void> _loadAccount() async {
    final s = await validSession();
    try {
      _account = await _apiClient!.fetch(s.idToken);
      _status = AccountStatus.signedIn;
    } on NoAccountYet {
      _account = null;
      _status = AccountStatus.needsAccount;
    }
  }

  Future<void> _run(
    Future<void> Function() body, {
    bool keepStatus = false,
  }) async {
    if (_busy || _disposed) return;
    _busy = true;
    _error = null;
    _notify();
    try {
      await body();
    } on FirebaseAuthException catch (e) {
      _error = e.message;
    } on AccountApiException catch (e) {
      _error = e.message;
    } finally {
      _busy = false;
      if (!keepStatus &&
          _session == null &&
          _status != AccountStatus.unavailable) {
        _status = AccountStatus.signedOut;
      }
      _notify();
    }
  }

  Future<FirebaseSession?> _readSaved() async {
    final store = _store;
    if (store == null) return null;
    try {
      final raw = await store.setting(sessionKey);
      if (raw == null) return null;
      final j = jsonDecode(raw) as Map<String, Object?>;
      return FirebaseSession(
        uid: j['uid']! as String,
        email: j['email']! as String,
        // Exchanged for a new ID token at once.
        idToken: '',
        refreshToken: j['refresh']! as String,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    } on Object {
      return null;
    }
  }

  Future<void> _save() async {
    final s = _session;
    final store = _store;
    if (s == null || store == null) return;
    await store.setSetting(
      sessionKey,
      jsonEncode({'uid': s.uid, 'email': s.email, 'refresh': s.refreshToken}),
    );
  }

  Future<void> _forget() async {
    try {
      await _store?.deleteSetting(sessionKey);
    } on Object {
      // Nothing saved, or the store is gone.
    }
  }

  void _set(AccountStatus s) {
    _status = s;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authClient?.close();
    _apiClient?.close();
    super.dispose();
  }
}

class AccountScope extends InheritedNotifier<AccountController> {
  const AccountScope({
    super.key,
    required AccountController controller,
    required super.child,
  }) : super(notifier: controller);

  static AccountController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AccountScope>();
    assert(scope != null, 'AccountScope is missing from the widget tree');
    return scope!.notifier!;
  }
}
