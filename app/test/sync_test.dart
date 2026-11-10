// Backup of the astronaut's own readings: off by default, only when signed
// in, sends exactly the ledger records (every hashed field), resumes where
// the server stopped, recovers once from a lost progress note, and never
// sends simulated data. The server here enforces the API's sequence rules;
// the real API's hash and chain checks are tested in server/tests.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakia/analytics/metric_definitions.dart';
import 'package:rakia/record/record_controller.dart';
import 'package:rakia/simulation/simulated_mission.dart';
import 'package:rakia/storage/local_store.dart';
import 'package:rakia/sync/sync_api.dart';
import 'package:rakia/sync/sync_controller.dart';
import 'package:rakia_core/rakia_core.dart';

import 'account_fakes.dart';
import 'helpers.dart';

/// /v1/sync/batches with the API's sequence rules.
class FakeSyncServer {
  final Map<String, List<Map<String, Object?>>> held = {}; // client -> records
  final List<Map<String, Object?>> batches = [];
  bool down = false;

  MockClient get client => MockClient((req) async {
    if (down) throw http.ClientException('offline');
    if (!(req.headers['Authorization'] ?? '').startsWith('Bearer id-')) {
      return http.Response('{"error":{"code":"invalid_token"}}', 401);
    }
    final b = jsonDecode(req.body) as Map<String, Object?>;
    batches.add(b);
    final records = (b['records']! as List).cast<Map<String, Object?>>();
    final mine = held.putIfAbsent(b['client_id']! as String, () => []);
    var accepted = 0;
    for (final r in records) {
      final seq = r['client_seq']! as int;
      if (seq <= mine.length) {
        if (mine[seq - 1]['hash'] != r['hash']) {
          return http.Response(
            '{"error":{"code":"chain_conflict","message":"Different records."}}',
            409,
          );
        }
        continue;
      }
      final prev = mine.isEmpty ? '0' * 64 : mine.last['hash'];
      if (seq != mine.length + 1 || r['prev_hash'] != prev) {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'chain_gap',
              'message': 'Expects sequence ${mine.length + 1}.',
            },
          }),
          409,
        );
      }
      mine.add(r);
      accepted++;
    }
    return http.Response(
      jsonEncode({
        'acked_through_seq': mine.length,
        'accepted': accepted,
        'duplicate': false,
      }),
      200,
    );
  });
}

void main() {
  late RakiaCore core;
  late LocalStore store;
  setUpAll(() async => core = await loadRakiaCore());
  setUp(() => store = fileLikeStore());
  tearDown(() => store.close());

  final today = DateTime.utc(2026, 11, 9);

  Future<RecordController> record() async {
    final r = RecordController(
      clock: () => today.add(const Duration(hours: 9)),
    );
    await r.attach(store, core);
    return r;
  }

  Future<(SyncController, FakeSyncServer, FakeFirebase, FakeApi)> setup({
    bool signIn = true,
    Listenable? changes,
  }) async {
    final fb = FakeFirebase()
      ..users['astro@example.test'] = (
        password: 'correct-horse',
        uid: 'uid-1',
        verified: true,
      );
    final api = FakeApi()..accounts.add('uid-1');
    final account = controllerFor(fb, api);
    await account.attach(store);
    if (signIn) await account.signIn('astro@example.test', 'correct-horse');
    final server = FakeSyncServer();
    final sync = SyncController(
      api: SyncApi(baseUrl: 'https://api.example.test', client: server.client),
      account: account,
      changes: changes,
    );
    addTearDown(() {
      sync.dispose();
      account.dispose();
    });
    await sync.attach(store);
    return (sync, server, fb, api);
  }

  Future<void> readings(RecordController r, int n) async {
    for (var d = n - 1; d >= 0; d--) {
      await r.add(
        metric: restingHeartRate,
        value: 58.0 + d % 3,
        day: today.subtract(Duration(days: d)),
      );
    }
  }

  test('off by default: nothing is sent', () async {
    final r = await record();
    await readings(r, 3);
    final (sync, server, _, _) = await setup();
    await sync.syncNow();
    expect(sync.status, SyncStatus.off);
    expect(server.batches, isEmpty);
  });

  test(
    'turned on and signed in: every reading is sent exactly as stored',
    () async {
      final r = await record();
      await readings(r, 3);
      final (sync, server, _, _) = await setup();
      await sync.setEnabled(true);
      expect(sync.error, isNull);
      expect(sync.status, SyncStatus.idle);
      expect(sync.backedUp, 3);
      expect(sync.total, 3);

      final sent = server.batches.single;
      final id = (await store.personalRecordId())!;
      final ledger = await store.ledgerAfter(id, 0);
      expect(sent['mission'], containsPair('id', id));
      final records = (sent['records']! as List).cast<Map<String, Object?>>();
      expect(records.map((x) => x['hash']), ledger.map((x) => x.hash));
      expect(records.first['provenance'], 1); // real
      expect(records.first['method'], 2); // manual
      expect(records.first['prev_hash'], '0' * 64);
      expect(records.first['unit'], '/min');
    },
  );

  test('new readings and corrections are sent incrementally', () async {
    final r = await record();
    await readings(r, 2);
    final (sync, server, _, _) = await setup(changes: r);
    await sync.setEnabled(true);
    expect(server.batches, hasLength(1));

    final wrong = r.indicators.first.entries.first;
    await r.add(
      metric: restingHeartRate,
      value: 61,
      day: wrong.day,
      correcting: wrong,
    );
    await pumpEventQueue();
    await sync.syncNow();
    expect(sync.backedUp, 3);
    final last = (server.batches.last['records']! as List).single as Map;
    expect(last['client_seq'], 3);
    expect(last['supersedes_id'], wrong.id);
  });

  test(
    'without sign-in nothing is sent; signing in starts the backup',
    () async {
      final r = await record();
      await readings(r, 2);
      final (sync, server, _, _) = await setup(signIn: false);
      await sync.setEnabled(true);
      expect(sync.status, SyncStatus.needsSignIn);
      expect(server.batches, isEmpty);
    },
  );

  test(
    'a failure is reported and retried; nothing is marked as sent',
    () async {
      final r = await record();
      await readings(r, 2);
      final (sync, server, _, _) = await setup();
      server.down = true;
      await sync.setEnabled(true);
      expect(sync.status, SyncStatus.failed);
      expect(sync.error, contains('cannot be reached'));
      expect(sync.backedUp, 0);

      server.down = false;
      await sync.syncNow();
      expect(sync.status, SyncStatus.idle);
      expect(sync.backedUp, 2);
    },
  );

  test('a lost progress note restarts from the beginning once, without '
      'duplicates', () async {
    final r = await record();
    await readings(r, 3);
    final (sync, server, _, _) = await setup();
    await sync.setEnabled(true);
    // The server has three; this device forgets that, then adds one.
    final id = (await store.personalRecordId())!;
    await store.setSetting(SyncController.ackedKey(id), '0');
    await r.add(metric: restingHeartRate, value: 60, day: today);
    await sync.syncNow();
    expect(sync.error, isNull);
    expect(sync.backedUp, 4);
    expect(server.held.values.single, hasLength(4));

    // The server lost records instead (a gap): restart once, then succeed.
    server.held.values.single.removeRange(2, 4);
    await store.setSetting(SyncController.ackedKey(id), '4');
    await r.add(metric: restingHeartRate, value: 59, day: today);
    await sync.syncNow();
    expect(sync.error, isNull);
    expect(server.held.values.single, hasLength(5));
  });

  test('simulated data is never sent', () async {
    await store.saveSimulation(SimulatedMission.generate(seed: 3), core);
    final (sync, server, _, _) = await setup();
    await sync.setEnabled(true);
    expect(server.batches, isEmpty);
    expect(sync.total, 0);
  });

  test('a store that does not persist offers no backup', () async {
    final memory = newMemoryStore();
    addTearDown(memory.close);
    final fb = FakeFirebase();
    final account = controllerFor(fb, FakeApi());
    final sync = SyncController(
      api: SyncApi(baseUrl: 'https://api.example.test'),
      account: account,
    );
    addTearDown(() {
      sync.dispose();
      account.dispose();
    });
    await sync.attach(memory);
    expect(sync.status, SyncStatus.needsStorage);
  });

  test('the choice is remembered', () async {
    final (sync, _, _, _) = await setup();
    await sync.setEnabled(true);
    final again = SyncController(
      api: SyncApi(baseUrl: 'https://api.example.test'),
      account: controllerFor(FakeFirebase(), FakeApi()),
    );
    await again.attach(store);
    expect(again.enabled, isTrue);
    again.dispose();
  });
}
