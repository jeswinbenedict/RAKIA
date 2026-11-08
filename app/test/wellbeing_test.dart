// Wellbeing records: scoring of the reaction-time test, the test's state
// machine on a controlled clock, the store's rules for check-ins and test
// results, and the controller's in-memory fallback.
import 'dart:math';

import 'package:drift/native.dart' show SqliteException;
import 'package:flutter_test/flutter_test.dart';
import 'package:rakia/simulation/simulated_mission.dart';
import 'package:rakia/storage/local_store.dart';
import 'package:rakia/wellbeing/instruments.dart';
import 'package:rakia/wellbeing/pvt.dart';
import 'package:rakia/wellbeing/wellbeing_controller.dart';
import 'package:rakia_core/rakia_core.dart';

import 'helpers.dart';

void main() {
  final at = DateTime.utc(2026, 11, 8, 9, 30);

  group('instruments', () {
    test('match their published ranges', () {
      expect(sleepinessScale.max, 9);
      expect(stressScale.max, 5);
      expect(moodScale.max, 5);
      expect(sleepinessScale.label(1), 'Extremely alert');
      expect(sleepinessScale.label(5), 'Neither alert nor sleepy');
      expect(stressScale.label(5), 'Very much');
    });

    test('the mood rating is labelled as not validated', () {
      expect(moodScale.validated, isFalse);
      expect(moodScale.source, contains('not a validated'));
      expect(sleepinessScale.validated, isTrue);
      expect(stressScale.validated, isTrue);
    });
  });

  group('reaction-time scoring', () {
    ReactionTestResult score(List<int?> rts, {int falseStarts = 0}) =>
        ReactionTestResult.score(
          recordedAt: at,
          duration: Pvt.duration,
          responseTimesMs: rts,
          falseStarts: falseStarts,
          device: 'Test device',
        );

    test('median, mean speed, lapses and false starts', () {
      final r = score([250, 300, 400, 260, 90, null], falseStarts: 2);
      expect(r.stimuli, 6);
      // 90 ms is an anticipation, null a timeout: 4 valid responses.
      expect(r.responses, 4);
      expect(r.medianRtMs, 280);
      expect(
        r.meanSpeed,
        closeTo((4 + 1000 / 300 + 2.5 + 1000 / 260) / 4, 1e-9),
      );
      // 400 ms is a lapse, and so is the timeout.
      expect(r.lapses, 2);
      expect(r.falseStarts, 3);
    });

    test('the lapse threshold is 355 ms inclusive', () {
      expect(score([354]).lapses, 0);
      expect(score([355]).lapses, 1);
    });

    test('responses under 100 ms are false starts, 100 ms is valid', () {
      expect(score([99]).falseStarts, 1);
      expect(score([99]).responses, 0);
      expect(score([100]).responses, 1);
    });

    test('a test with no valid response has no median or speed', () {
      final r = score([null, null]);
      expect(r.responses, 0);
      expect(r.medianRtMs, isNull);
      expect(r.meanSpeed, isNull);
      expect(r.lapses, 2);
    });
  });

  group('the test session', () {
    late Duration now;
    PvtSession session({Duration duration = const Duration(seconds: 20)}) =>
        PvtSession(clock: () => now, random: Random(1), duration: duration);
    setUp(() => now = Duration.zero);

    /// Advances to the next stimulus and shows it.
    void nextStimulus(PvtSession s) {
      var guard = 0;
      while (!s.stimulusDue) {
        now += const Duration(milliseconds: 16);
        s.tick();
        expect(
          ++guard,
          lessThan(400),
          reason: 'a stimulus must come within 4 s',
        );
      }
      s.stimulusShown();
    }

    test('stimuli come 1 to 4 seconds apart', () {
      final s = session()..start();
      var previous = now;
      for (var i = 0; i < 3; i++) {
        nextStimulus(s);
        final gap = now - previous;
        expect(gap, greaterThanOrEqualTo(Pvt.minInterval));
        expect(
          gap,
          lessThanOrEqualTo(Pvt.maxInterval + const Duration(milliseconds: 16)),
        );
        now += const Duration(milliseconds: 250);
        expect(s.respond(), 250);
        previous = now;
      }
      expect(s.responseTimesMs, [250, 250, 250]);
    });

    test('a response with no stimulus showing is a false start', () {
      final s = session()..start();
      expect(s.respond(), isNull);
      expect(s.falseStarts, 1);
      expect(s.responseTimesMs, isEmpty);
    });

    test('an unanswered stimulus times out as a lapse', () {
      final s = session(duration: const Duration(minutes: 2))..start();
      nextStimulus(s);
      now += const Duration(milliseconds: Pvt.timeoutMs);
      s.tick();
      expect(s.responseTimesMs, [null]);
      expect(s.phase, PvtPhase.waiting);
    });

    test('ends at its duration, after the stimulus in progress', () {
      final s = session()..start();
      while (s.phase != PvtPhase.finished) {
        if (s.stimulusDue) {
          s.stimulusShown();
          now += const Duration(milliseconds: 300);
          s.respond();
        } else {
          now += const Duration(milliseconds: 16);
          s.tick();
        }
      }
      expect(now, greaterThanOrEqualTo(const Duration(seconds: 20)));
      expect(s.responseTimesMs, isNotEmpty);
      expect(s.responseTimesMs.every((rt) => rt == 300), isTrue);
      final r = s.result(recordedAt: at, device: 'Test device');
      expect(r.medianRtMs, 300);
      expect(r.lapses, 0);
    });
  });

  group('the store', () {
    late LocalStore store;
    setUp(() => store = newMemoryStore());
    tearDown(() => store.close());

    test('keeps check-ins, newest first', () async {
      await store.addCheckIn(sleepiness: 3, stress: 2, mood: 4, now: at);
      await store.addCheckIn(
        sleepiness: 7,
        stress: 4,
        mood: 2,
        now: at.add(const Duration(hours: 5)),
      );
      final all = await store.checkIns();
      expect(all.map((c) => c.sleepiness), [7, 3]);
      expect(all.last.recordedAt, at);
      expect(all.first.id, isNot(all.last.id));
    });

    test('refuses answers outside each scale', () async {
      for (final (s, st, m) in [(0, 1, 1), (10, 1, 1), (5, 6, 1), (5, 1, 0)]) {
        await expectLater(
          store.addCheckIn(sleepiness: s, stress: st, mood: m, now: at),
          throwsA(isA<SqliteException>()),
          reason: '($s, $st, $m)',
        );
      }
    });

    test('never edits a check-in', () async {
      await store.addCheckIn(sleepiness: 3, stress: 2, mood: 4, now: at);
      await expectLater(
        store.db.customStatement('UPDATE self_checkins SET mood = 1'),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('not edited'),
          ),
        ),
      );
    });

    test('keeps reaction-time results exactly', () async {
      final scored = ReactionTestResult.score(
        recordedAt: at,
        duration: Pvt.duration,
        responseTimesMs: const [250, 300, 400, null],
        falseStarts: 1,
        device: 'Windows desktop',
      );
      final saved = await store.addReactionTest(scored);
      expect(saved.id, isNotNull);
      final back = (await store.reactionTests()).single;
      expect(back.id, saved.id);
      expect(back.recordedAt, at);
      expect(back.stimuli, 4);
      expect(back.responses, 3);
      expect(back.medianRtMs, 300);
      expect(back.meanSpeed, scored.meanSpeed);
      expect(back.lapses, 2);
      expect(back.falseStarts, 1);
      expect(back.device, 'Windows desktop');
    });

    test('deletes all wellbeing records and nothing else', () async {
      final core = await loadRakiaCore();
      final mission = await store.saveSimulation(
        SimulatedMission.generate(),
        core,
      );
      await store.addCheckIn(sleepiness: 3, stress: 2, mood: 4, now: at);
      await store.addReactionTest(
        ReactionTestResult.score(
          recordedAt: at,
          duration: Pvt.duration,
          responseTimesMs: const [250],
          falseStarts: 0,
          device: 'Test device',
        ),
      );
      await store.deleteWellbeingRecords();
      expect(await store.checkIns(), isEmpty);
      expect(await store.reactionTests(), isEmpty);
      expect(await store.recordCount(mission.missionId), mission.records);
    });
  });

  group('the controller', () {
    test('without a store keeps records in memory, then saves them', () async {
      final c = WellbeingController();
      addTearDown(c.dispose);
      expect(c.persistent, isFalse);
      await c.addCheckIn(sleepiness: 4, stress: 2, mood: 4, now: at);
      expect(c.checkIns, hasLength(1));

      final store = newMemoryStore();
      addTearDown(store.close);
      await c.attach(store);
      expect(c.persistent, isFalse, reason: 'a memory store is not persistent');
      expect((await store.checkIns()).single.sleepiness, 4);
      expect(c.checkIns, hasLength(1));
    });

    test('loads saved records and deletes them', () async {
      final store = newMemoryStore();
      addTearDown(store.close);
      await store.addCheckIn(sleepiness: 6, stress: 3, mood: 3, now: at);
      final c = WellbeingController();
      addTearDown(c.dispose);
      await c.attach(store);
      expect(c.checkIns.single.sleepiness, 6);
      await c.deleteAll();
      expect(c.isEmpty, isTrue);
      expect(await store.checkIns(), isEmpty);
    });
  });
}
