// Alerts on the astronaut's own record: librakia's evaluation of real
// readings raises them, a confirmatory reading or a check settles or
// confirms them, and every response is logged on the device, immutably and
// only against a real record.
import 'package:drift/native.dart' show SqliteException;
import 'package:flutter_test/flutter_test.dart';
import 'package:rakia/analytics/day_format.dart';
import 'package:rakia/analytics/metric_definitions.dart';
import 'package:rakia/analytics/metric_insight.dart';
import 'package:rakia/components/health_status.dart';
import 'package:rakia/record/alert_response.dart';
import 'package:rakia/record/record_controller.dart';
import 'package:rakia/simulation/simulated_mission.dart';
import 'package:rakia/storage/local_store.dart';
import 'package:rakia_core/rakia_core.dart';

import 'helpers.dart';

void main() {
  late RakiaCore core;
  late LocalStore store;
  final today = DateTime.utc(2026, 11, 9);
  DateTime daysAgo(int n) => today.subtract(Duration(days: n));

  setUpAll(() async => core = await loadRakiaCore());
  setUp(() => store = newMemoryStore());
  tearDown(() => store.close());

  Future<RecordController> attached() async {
    final c = RecordController(
      clock: () => today.add(const Duration(hours: 9)),
    );
    await c.attach(store, core);
    return c;
  }

  /// Sixteen baseline days around 58 bpm (days 7 to 22 back).
  Future<void> baseline(RecordController c, {MetricDefinition? metric}) async {
    final m = metric ?? restingHeartRate;
    const values = [57.0, 58, 59, 58, 57, 58, 59, 58, 57, 59, 58, 57, 58, 59];
    final around = m == restingHeartRate ? 0.0 : 7.5 - 58;
    for (var k = 0; k < 16; k++) {
      expect(
        await c.add(
          metric: m,
          value: values[k % values.length] + around,
          day: daysAgo(7 + k),
        ),
        isNull,
      );
    }
  }

  /// A normal week except for one high reading today.
  Future<RecordController> pointDeviation() async {
    final c = await attached();
    await baseline(c);
    for (var d = 1; d < 7; d++) {
      await c.add(metric: restingHeartRate, value: 58, day: daysAgo(d));
    }
    await c.add(metric: restingHeartRate, value: 80, day: today);
    return c;
  }

  group('alerts from real readings', () {
    test('a far-off reading raises an alert dated by calendar day', () async {
      final c = await pointDeviation();
      final alert = c.alerts.single;
      expect(alert.metric, restingHeartRate);
      expect(alert.status, isIn([HealthStatus.watch, HealthStatus.act]));
      expect(alert.datesKnown, isTrue);
      expect(alertDay(alert), today);

      final e = explain(alert);
      expect(e.since, contains(formatDay(today, withYear: false)));
      expect(e.evidence, contains('readings from the past 7 days'));
      expect(e.evidence, contains('earlier days'));
      for (final text in [e.since, e.evidence, e.whatChanged]) {
        expect(text, isNot(contains('mission day')));
        expect(text, isNot(contains('pre-flight')));
      }
    });

    test('a normal record raises no alert', () async {
      final c = await attached();
      await baseline(c);
      for (var d = 0; d < 7; d++) {
        await c.add(metric: restingHeartRate, value: 58, day: daysAgo(d));
      }
      expect(c.alerts, isEmpty);
      expect(
        c.insightFor(restingHeartRate.code)!.status,
        HealthStatus.withinBaseline,
      );
    });

    test('a week with too few readings is a data problem, explained as '
        'missing days', () async {
      final c = await attached();
      await baseline(c);
      await c.add(metric: restingHeartRate, value: 58, day: daysAgo(5));
      await c.add(metric: restingHeartRate, value: 58, day: today);
      final alert = c.alerts.single;
      expect(alert.status, HealthStatus.dataQuality);
      final e = explain(alert);
      expect(e.headline, contains('not enough recent readings'));
      expect(e.whatChanged, contains('Only 2 of the past 7 days'));
      expect(e.checkNext, contains('record one each day'));
      // The first day of the week has no reading.
      expect(alertDay(alert), daysAgo(6));
    });

    test('a sustained shift is dated from its estimated onset', () async {
      final c = await attached();
      await baseline(c);
      for (var d = 0; d < 7; d++) {
        await c.add(metric: restingHeartRate, value: 66, day: daysAgo(d));
      }
      final alert = c.alerts.single;
      expect(alert.hasShift, isTrue);
      final onset = alert.dateOf(alert.assessment.cusum.onsetIndex)!;
      expect(alertDay(alert), onset);
      expect(
        explain(alert).since,
        contains('Estimated onset ${formatDay(onset, withYear: false)}'),
      );
    });
  });

  group('confirmatory checks', () {
    test('a normal repeat reading settles a one-off reading, and the '
        'response records the outcome', () async {
      final c = await pointDeviation();
      final alert = c.alerts.single;
      expect(
        await c.add(
          metric: restingHeartRate,
          value: 58,
          day: today,
          respondingTo: alert,
        ),
        isNull,
      );
      expect(c.alerts, isEmpty);
      final r = c.responsesForMetric(restingHeartRate.code).single;
      expect(r.kind, AlertResponseKind.confirmatoryReading);
      expect(r.alertLevel, alert.status);
      expect(r.alertDay, today);
      expect(r.outcome, HealthStatus.withinBaseline);
      expect(r.note, 'Reading 58.0 bpm.');
      // Both readings stay in the ledger; the repeat counts for the day.
      final id = (await store.personalRecordId())!;
      expect(await store.recordEntries(id), hasLength(16 + 7 + 1));
    });

    test('a repeat that agrees confirms the alert, and the log survives '
        'reopening', () async {
      final c = await attached();
      await baseline(c);
      for (var d = 0; d < 7; d++) {
        await c.add(metric: restingHeartRate, value: 66, day: daysAgo(d));
      }
      final alert = c.alerts.single;
      await c.add(
        metric: restingHeartRate,
        value: 67,
        day: today,
        respondingTo: alert,
      );
      expect(c.alerts, hasLength(1));
      final outcome = c.responsesFor(c.alerts.single).single.outcome;
      expect(outcome, isIn([HealthStatus.watch, HealthStatus.act]));

      final again = await attached();
      final logged = again.responsesFor(again.alerts.single).single;
      expect(logged.kind, AlertResponseKind.confirmatoryReading);
      expect(logged.outcome, outcome);
    });

    test('a correction answers the alert as a correction', () async {
      final c = await pointDeviation();
      final alert = c.alerts.single;
      final wrong = c.indicators
          .firstWhere((i) => i.metric == restingHeartRate)
          .entries
          .first;
      expect(wrong.value, 80);
      await c.add(
        metric: restingHeartRate,
        value: 59,
        day: wrong.day,
        correcting: wrong,
        respondingTo: alert,
      );
      expect(c.alerts, isEmpty);
      final r = c.responsesForMetric(restingHeartRate.code).single;
      expect(r.kind, AlertResponseKind.valueCorrected);
      expect(r.note, 'Corrected to 59.0 bpm.');
    });

    test('an invalid confirmatory reading is refused and nothing is '
        'logged', () async {
      final c = await pointDeviation();
      final alert = c.alerts.single;
      expect(
        await c.add(
          metric: restingHeartRate,
          value: 500,
          day: today,
          respondingTo: alert,
        ),
        contains('between'),
      );
      expect(c.responsesForMetric(restingHeartRate.code), isEmpty);
    });
  });

  group('responses', () {
    test('keep watching and contacting medical support are logged with an '
        'optional note, newest first', () async {
      final c = await pointDeviation();
      final alert = c.alerts.single;
      expect(
        await c.respond(alert, AlertResponseKind.keepWatching, note: '  '),
        isNull,
      );
      expect(
        await c.respond(
          alert,
          AlertResponseKind.contactedMedical,
          note: 'Spoke with the flight surgeon.',
        ),
        isNull,
      );
      final rs = c.responsesFor(alert);
      expect(rs.map((r) => r.kind), [
        AlertResponseKind.contactedMedical,
        AlertResponseKind.keepWatching,
      ]);
      expect(rs.first.note, 'Spoke with the flight surgeon.');
      expect(rs.last.note, isNull);
      expect(rs.first.outcome, isNull);
    });

    test('a note over the limit is refused', () async {
      final c = await pointDeviation();
      expect(
        await c.respond(
          c.alerts.single,
          AlertResponseKind.keepWatching,
          note: 'x' * (kMaxResponseNote + 1),
        ),
        contains('under $kMaxResponseNote'),
      );
      expect(c.responsesForMetric(restingHeartRate.code), isEmpty);
    });

    test('responses to an earlier alert do not answer a later one', () async {
      final c = await pointDeviation();
      final id = (await store.personalRecordId())!;
      // Logged three days ago, about an alert of that time.
      await store.addAlertResponse(
        recordId: id,
        metricCode: restingHeartRate.code,
        alertLevel: HealthStatus.watch,
        alertDay: daysAgo(3),
        kind: AlertResponseKind.keepWatching,
        now: daysAgo(3).add(const Duration(hours: 12)),
      );
      final again = await attached();
      expect(again.responsesFor(again.alerts.single), isEmpty);
      expect(again.responsesForMetric(restingHeartRate.code), hasLength(1));

      await again.respond(again.alerts.single, AlertResponseKind.keepWatching);
      expect(again.responsesFor(again.alerts.single), hasLength(1));
      expect(c.alerts, hasLength(1));
    });

    test('responses are never edited or deleted', () async {
      final c = await pointDeviation();
      await c.respond(c.alerts.single, AlertResponseKind.keepWatching);
      await expectLater(
        store.db.customStatement('UPDATE alert_responses SET response = 5'),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        store.db.customStatement('DELETE FROM alert_responses'),
        throwsA(isA<SqliteException>()),
      );
      expect(c.responsesForMetric(restingHeartRate.code), hasLength(1));
    });

    test('a simulation mission cannot carry responses', () async {
      final sim = await store.saveSimulation(
        SimulatedMission.generate(seed: 7),
        core,
      );
      await expectLater(
        store.addAlertResponse(
          recordId: sim.missionId,
          metricCode: restingHeartRate.code,
          alertLevel: HealthStatus.watch,
          alertDay: today,
          kind: AlertResponseKind.keepWatching,
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('only alert levels can be answered', () async {
      final id = await store.createPersonalRecord(label: 'Me');
      await expectLater(
        store.addAlertResponse(
          recordId: id,
          metricCode: restingHeartRate.code,
          alertLevel: HealthStatus.withinBaseline,
          alertDay: today,
          kind: AlertResponseKind.keepWatching,
        ),
        throwsArgumentError,
      );
    });

    test('a daily total is checked rather than re-measured', () {
      for (final m in kMetricDefinitions) {
        expect(m.confirmatoryCheck, isNotEmpty);
      }
      expect(restingHeartRate.repeatable, isTrue);
      expect(oxygenSaturation.repeatable, isTrue);
      expect(sleepDuration.repeatable, isFalse);
      expect(exerciseMinutes.repeatable, isFalse);
    });
  });

  test('alerts are ranked act, watch, data quality, keeping order within '
      'a level', () async {
    final c = await attached();
    await baseline(c);
    await baseline(c, metric: sleepDuration);
    for (var d = 0; d < 7; d++) {
      await c.add(metric: restingHeartRate, value: 75, day: daysAgo(d));
    }
    await c.add(metric: sleepDuration, value: 7.5, day: today);
    final levels = c.alerts.map((a) => a.status).toList();
    expect(levels.last, HealthStatus.dataQuality);
    expect(c.alerts.first.metric, restingHeartRate);
    expect(rankAlerts(c.alerts.reversed).map((a) => a.status), levels);
  });
}
