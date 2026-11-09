// The personal health record: real readings entered by the astronaut are
// validated, appended to the hash-chained ledger as real manual data,
// corrected without overwriting, laid out in the evaluation windows and
// evaluated by librakia only once the baseline has enough days.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakia/analytics/metric_definitions.dart';
import 'package:rakia/components/health_status.dart';
import 'package:rakia/record/record.dart';
import 'package:rakia/record/record_controller.dart';
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

  group('validation', () {
    String? check(double? v, DateTime day) => validateEntry(
      metric: restingHeartRate,
      value: v,
      day: day,
      today: today,
    );

    test('accepts a plausible reading for today or the past', () {
      expect(check(58, today), isNull);
      expect(check(58, daysAgo(RecordWindows.maxBackdateDays)), isNull);
    });

    test('refuses missing, implausible, future and too-old readings', () {
      expect(check(null, today), 'Enter a number.');
      expect(check(double.nan, today), 'Enter a number.');
      expect(check(250, today), contains('between'));
      expect(check(10, today), contains('between'));
      expect(check(58, today.add(const Duration(days: 1))), contains('future'));
      expect(
        check(58, daysAgo(RecordWindows.maxBackdateDays + 1)),
        contains('days back'),
      );
    });
  });

  group('windows', () {
    RecordEntry e(int seq, int daysBack, double v, {String? supersedes}) =>
        RecordEntry(
          id: 'id-$seq',
          metricCode: restingHeartRate.code,
          value: v,
          unit: '/min',
          day: daysAgo(daysBack),
          seq: seq,
          supersedesId: supersedes,
        );

    test(
      'the last 7 days are monitored; the 35 before them are the baseline',
      () {
        final s = recordSeries(restingHeartRate, [
          e(1, 0, 60),
          e(2, 7, 55),
        ], today);
        expect(s.monitoring.length, RecordWindows.monitoringDays);
        expect(s.reference.length, RecordWindows.referenceDays);
        expect(s.monitoring.last, 60); // today is the last monitoring day
        expect(s.reference.last, 55); // 7 days ago is the newest baseline day
        expect(s.monitoring.where((v) => v.isFinite).length, 1);
        expect(baselineDays(s), 1);
      },
    );

    test(
      'the latest reading of a day wins; a correction replaces its target',
      () {
        final entries = [
          e(1, 0, 60),
          e(2, 0, 62),
          e(3, 1, 70),
          e(4, 1, 59, supersedes: 'id-3'),
        ];
        final byDay = currentByDay(entries, restingHeartRate.code);
        expect(byDay[today]!.value, 62);
        expect(byDay[daysAgo(1)]!.value, 59);
      },
    );
  });

  group('store', () {
    test('creates one real record and appends real, manual readings', () async {
      final id = await store.createPersonalRecord(label: 'Me', now: today);
      expect(await store.createPersonalRecord(label: 'Me', now: today), id);
      expect(await store.personalRecordId(), id);
      await store.addRecordEntry(
        recordId: id,
        metric: restingHeartRate,
        value: 58,
        day: today,
        core: core,
      );
      final rows = await store.db.select(store.db.measurements).get();
      expect(rows.single.provenance, Provenance.real.code);
      expect(rows.single.method, MeasurementMethod.manual.code);
      expect(rows.single.unit, restingHeartRate.ucum);
      final check = await store.verifyLedger(id, core);
      expect(check.failedAtSeq, isNull);
    });

    test('a correction is a new linked record; the original stays', () async {
      final id = await store.createPersonalRecord(label: 'Me', now: today);
      final first = await store.addRecordEntry(
        recordId: id,
        metric: restingHeartRate,
        value: 85,
        day: today,
        core: core,
      );
      await store.addRecordEntry(
        recordId: id,
        metric: restingHeartRate,
        value: 58,
        day: today,
        core: core,
        supersedesId: first.id,
      );
      final entries = await store.recordEntries(id);
      expect(entries.length, 2);
      expect(entries.last.supersedesId, first.id);
      expect(currentByDay(entries, restingHeartRate.code)[today]!.value, 58);
      expect((await store.verifyLedger(id, core)).failedAtSeq, isNull);
    });

    test('real readings can be neither edited nor deleted', () async {
      final id = await store.createPersonalRecord(label: 'Me', now: today);
      await store.addRecordEntry(
        recordId: id,
        metric: restingHeartRate,
        value: 58,
        day: today,
        core: core,
      );
      await expectLater(
        store.db.customStatement('UPDATE measurements SET value = 99'),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        store.db.customStatement('DELETE FROM measurements'),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        store.db.customStatement('DELETE FROM missions'),
        throwsA(isA<SqliteException>()),
      );
    });

    test('implausible values never reach the ledger', () async {
      final id = await store.createPersonalRecord(label: 'Me', now: today);
      await expectLater(
        store.addRecordEntry(
          recordId: id,
          metric: restingHeartRate,
          value: 400,
          day: today,
          core: core,
        ),
        throwsArgumentError,
      );
    });
  });

  group('controller', () {
    Future<RecordController> attached() async {
      final c = RecordController(
        clock: () => today.add(const Duration(hours: 9)),
      );
      await c.attach(store, core);
      return c;
    }

    test('before 14 baseline days there is progress, not a verdict', () async {
      final c = await attached();
      for (var d = 7; d < 7 + 10; d++) {
        expect(
          await c.add(metric: restingHeartRate, value: 58, day: daysAgo(d)),
          isNull,
        );
      }
      final rhr = c.indicators.firstWhere((i) => i.metric == restingHeartRate);
      expect(rhr.baselineDays, 10);
      expect(rhr.baselineReady, isFalse);
      expect(rhr.insight, isNull);
    });

    test('with a baseline, librakia evaluates the latest week', () async {
      final c = await attached();
      // A stable baseline around 58 bpm, then a sustained rise to 66.
      final baseline = <double>[
        57.0,
        58,
        59,
        58,
        57,
        58,
        59,
        58,
        57,
        59,
        58,
        57,
        58,
        59,
        58,
        57,
      ];
      for (var k = 0; k < baseline.length; k++) {
        await c.add(
          metric: restingHeartRate,
          value: baseline[k],
          day: daysAgo(7 + k),
        );
      }
      for (var d = 0; d < 7; d++) {
        await c.add(metric: restingHeartRate, value: 66, day: daysAgo(d));
      }
      final rhr = c.indicators.firstWhere((i) => i.metric == restingHeartRate);
      expect(rhr.baselineReady, isTrue);
      expect(rhr.insight, isNotNull);
      expect(rhr.insight!.status, isIn([HealthStatus.watch, HealthStatus.act]));
    });

    test('invalid input is reported and nothing is saved', () async {
      final c = await attached();
      expect(
        await c.add(metric: restingHeartRate, value: 400, day: today),
        contains('between'),
      );
      expect(c.hasEntries, isFalse);
      expect(await store.personalRecordId(), isNull);
    });

    test('readings survive reopening the record', () async {
      final c = await attached();
      await c.add(metric: sleepDuration, value: 7.5, day: today);
      final again = await attached();
      final sleep = again.indicators.firstWhere(
        (i) => i.metric == sleepDuration,
      );
      expect(sleep.entries.single.value, 7.5);
    });
  });
}
