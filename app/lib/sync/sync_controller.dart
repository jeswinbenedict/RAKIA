import 'dart:async';

import 'package:flutter/widgets.dart';

import '../account/account_controller.dart';
import '../account/firebase_auth_client.dart';
import '../storage/local_store.dart';
import '../storage/uuid.dart';
import 'sync_api.dart';

/// Why backup is or is not running.
enum SyncStatus {
  /// This build has no server connection.
  unavailable,

  /// Storage on this device does not persist, so there is no stable record
  /// to back up.
  needsStorage,

  /// The astronaut has not turned backup on (the default).
  off,
  needsSignIn,
  idle,
  syncing,

  /// The last attempt failed; see [SyncController.error].
  failed,
}

/// Opt-in backup of the astronaut's own readings to the RAKIA server.
/// Upload only: readings are sent as the hash-chained records the device
/// holds, and the server verifies every hash. Simulated missions, check-ins
/// and reaction tests are never sent. Nothing is uploaded unless the
/// astronaut turns backup on and is signed in.
class SyncController extends ChangeNotifier {
  SyncController({
    required SyncApi? api,
    required AccountController account,
    Listenable? changes,
    DateTime Function()? clock,
  }) : _syncApi = api,
       _accountController = account,
       _recordChanges = changes,
       _clock = clock ?? DateTime.now {
    _accountController.addListener(_onChange);
    _recordChanges?.addListener(_onChange);
  }

  final SyncApi? _syncApi;
  final AccountController _accountController;
  final Listenable? _recordChanges;
  final DateTime Function() _clock;

  static const String enabledKey = 'sync.enabled';
  static const String clientIdKey = 'sync.client_id';
  static String ackedKey(String missionId) => 'sync.acked.$missionId';
  static const String lastSyncedKey = 'sync.last_synced_at';

  /// Records per request, and requests per run (so one run is bounded).
  static const int batchSize = 200;
  static const int maxBatchesPerRun = 50;

  LocalStore? _store;
  bool _attached = false;
  bool _enabled = false;
  bool _running = false;
  bool _again = false;
  bool _disposed = false;
  String? _error;
  int _total = 0;
  int _acked = 0;
  DateTime? _lastSynced;

  bool get enabled => _enabled;

  /// What went wrong in the last attempt, in words.
  String? get error => _error;

  /// Readings in the record on this device, and how many the server holds.
  int get total => _total;
  int get backedUp => _acked > _total ? _total : _acked;
  DateTime? get lastSynced => _lastSynced;

  SyncStatus get status {
    if (_syncApi == null || !_accountController.available) {
      return SyncStatus.unavailable;
    }
    if (_attached && _store == null) return SyncStatus.needsStorage;
    if (!_enabled) return SyncStatus.off;
    if (_accountController.status != AccountStatus.signedIn) {
      return SyncStatus.needsSignIn;
    }
    if (_running) return SyncStatus.syncing;
    if (_error != null) return SyncStatus.failed;
    return SyncStatus.idle;
  }

  /// Uses [store] (null when storage does not persist) and resumes backup
  /// if the astronaut had turned it on.
  Future<void> attach(LocalStore? store) async {
    _store = store != null && store.kind.persistent ? store : null;
    _attached = true;
    final s = _store;
    if (s != null) {
      _enabled = await s.setting(enabledKey) == 'true';
      final last = await s.setting(lastSyncedKey);
      _lastSynced = last == null ? null : DateTime.tryParse(last);
      await _count();
    }
    _notify();
    _onChange();
  }

  Future<void> setEnabled(bool value) async {
    final s = _store;
    if (s == null || value == _enabled) return;
    _enabled = value;
    _error = null;
    await s.setSetting(enabledKey, '$value');
    _notify();
    if (value) await syncNow();
  }

  void _onChange() {
    if (_disposed || !_attached) return;
    if (_enabled && _accountController.status == AccountStatus.signedIn) {
      unawaited(syncNow());
    } else {
      _notify();
    }
  }

  Future<void> _count() async {
    final s = _store;
    if (s == null) return;
    final record = await s.personalRecord();
    if (record == null) {
      _total = 0;
      _acked = 0;
      return;
    }
    _total = await s.lastSeq(record.id);
    _acked = int.tryParse(await s.setting(ackedKey(record.id)) ?? '') ?? 0;
  }

  /// Uploads every reading the server does not hold yet. Safe to call at
  /// any time; calls while a run is in progress are folded into one more.
  Future<void> syncNow() async {
    final s = _store;
    final api = _syncApi;
    if (s == null ||
        api == null ||
        !_enabled ||
        _accountController.status != AccountStatus.signedIn) {
      return;
    }
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    _error = null;
    _notify();
    try {
      do {
        _again = false;
        await _run(s, api);
      } while (_again && !_disposed);
    } on SyncException catch (e) {
      _error = e.message;
    } on FirebaseAuthException catch (e) {
      _error = e.message;
    } on Object catch (e) {
      _error = 'Backup failed: $e';
    } finally {
      _running = false;
      _notify();
    }
  }

  Future<void> _run(LocalStore s, SyncApi api) async {
    final record = await s.personalRecord();
    if (record == null) return; // nothing recorded yet
    var clientId = await s.setting(clientIdKey);
    if (clientId == null) {
      clientId = uuidToString(uuidV7(now: _clock().toUtc()));
      await s.setSetting(clientIdKey, clientId);
    }
    var acked = int.tryParse(await s.setting(ackedKey(record.id)) ?? '') ?? 0;
    var restarted = false;
    for (var n = 0; n < maxBatchesPerRun; n++) {
      final rows = await s.ledgerAfter(record.id, acked, limit: batchSize);
      _total = await s.lastSeq(record.id);
      if (rows.isEmpty) break;
      final session = await _accountController.validSession();
      final SyncAck ack;
      try {
        ack = await api.send(session.idToken, {
          'batch_id': uuidToString(uuidV7(now: _clock().toUtc())),
          'client_id': clientId,
          'subject_id': record.subjectId,
          'mission': {
            'id': record.id,
            'name': record.name,
            'start_at_us': record.startAtUs,
            'planned_days': record.plannedDays,
          },
          'records': [for (final r in rows) r.toJson()],
        });
      } on SyncException catch (e) {
        // The server holds fewer records than this device believed (for
        // example after the local note of progress was lost): start over
        // once; records it already holds are skipped, never duplicated.
        if (e.code == 'chain_gap' && !restarted) {
          restarted = true;
          acked = 0;
          await s.setSetting(ackedKey(record.id), '0');
          continue;
        }
        rethrow;
      }
      if (ack.ackedThroughSeq < rows.last.clientSeq) {
        throw const SyncException(
          'The RAKIA server did not confirm every reading. Try again.',
        );
      }
      acked = rows.last.clientSeq;
      await s.setSetting(ackedKey(record.id), '$acked');
      _acked = acked;
      _lastSynced = _clock().toUtc();
      await s.setSetting(lastSyncedKey, _lastSynced!.toIso8601String());
      _notify();
    }
    _acked = acked;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _accountController.removeListener(_onChange);
    _recordChanges?.removeListener(_onChange);
    _syncApi?.close();
    super.dispose();
  }
}

class SyncScope extends InheritedNotifier<SyncController> {
  const SyncScope({
    super.key,
    required SyncController controller,
    required super.child,
  }) : super(notifier: controller);

  static SyncController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SyncScope>();
    assert(scope != null, 'SyncScope is missing from the widget tree');
    return scope!.notifier!;
  }
}
