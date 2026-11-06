// The simulation is deterministic and librakia's conclusions on it match the
// ground truth that was injected. Expected outcomes were checked against the
// scenario definitions, not copied from the UI.
import 'package:flutter_test/flutter_test.dart';
import 'package:rakia/analytics/metric_insight.dart';
import 'package:rakia/components/health_status.dart';
import 'package:rakia/mission/mission_controller.dart';
import 'package:rakia/simulation/seeded_random.dart';
import 'package:rakia/simulation/simulated_mission.dart';
import 'package:rakia_core/rakia_core.dart';

void main() {
  late RakiaCore core;
  late MissionSnapshot snapshot;

  setUpAll(() async {
    core = await loadRakiaCore();
    final mission = MissionController();
    await mission.startSimulation(core);
    snapshot = mission.snapshot!;
  });

  MetricInsight insight(String code) =>
      snapshot.insights.firstWhere((i) => i.metric.code == code);

  test('the generator is deterministic and seed-dependent', () {
    // Same algorithm as core/dart/test/support.dart, whose port is proven
    // bit-exact against the C suite by the determinism digest test.
    final r = SeededRandom(0x52414B4941);
    final u = r.uniform();
    expect(u, greaterThan(0));
    expect(u, lessThan(1));
    // Same seed, same sequence; different seed, different sequence.
    expect(SeededRandom(0x52414B4941).uniform(), u);
    expect(SeededRandom(1).uniform(), isNot(u));
  });

  test('the simulation is deterministic', () {
    final a = SimulatedMission.generate();
    final b = SimulatedMission.generate();
    for (var k = 0; k < a.series.length; k++) {
      expect(b.series[k].reference, a.series[k].reference);
      expect(
        b.series[k].monitoring.map((v) => v.isNaN ? 'nan' : v),
        a.series[k].monitoring.map((v) => v.isNaN ? 'nan' : v),
      );
    }
    final c = SimulatedMission.generate(seed: 7);
    expect(c.series.first.reference, isNot(a.series.first.reference));
  });

  test('every value is plausible or deliberately rejected', () {
    for (final s in snapshot.mission.series) {
      expect(s.reference.length, snapshot.mission.referenceDays);
      expect(s.monitoring.length, snapshot.mission.missionDay);
      for (var i = 0; i < s.monitoring.length; i++) {
        final v = s.monitoring[i];
        final plausible =
            v >= s.metric.plausibleMin && v <= s.metric.plausibleMax;
        if (v.isFinite && s.sensorFlags[i] == 0) {
          expect(plausible, isTrue, reason: '${s.metric.code} day ${i + 1}');
        }
      }
    }
  });

  test('step change in resting heart rate: Act, onset at the injected day', () {
    final i = insight('heart_rate.resting');
    expect(i.status, HealthStatus.act);
    expect(i.hasShift, isTrue);
    expect(i.assessment.cusum.direction, 1);
    expect(
      MetricInsight.dayOf(i.assessment.cusum.onsetIndex),
      i.series.changeDay,
    );
    expect(i.assessment.reasons, contains(AssessmentReason.persistentShift));
  });

  test('sensor outage in sleep: a data problem, not a health signal', () {
    final i = insight('sleep.duration');
    expect(i.status, HealthStatus.dataQuality);
    expect(i.assessment.nUsable, 27);
    expect(i.assessment.windowQuality, closeTo(0.6, 1e-12));
    expect(i.assessment.reasons, contains(AssessmentReason.lowQuality));
  });

  test('stable indicators stay within baseline', () {
    for (final code in ['spo2', 'exercise.duration']) {
      expect(insight(code).status, HealthStatus.withinBaseline, reason: code);
      expect(trendSummary(insight(code)).significant, isFalse, reason: code);
    }
  });

  test('gradual HRV decline: no alarm, but a significant declining trend', () {
    final i = insight('hrv.rmssd');
    expect(i.status, HealthStatus.withinBaseline);
    final t = trendSummary(i);
    expect(t.significant, isTrue);
    expect(t.direction, 'declining');
    expect(explain(i).whatChanged, contains('declining trend'));
  });

  test('alerts are ranked by severity', () {
    expect(snapshot.alerts.map((i) => i.metric.code), [
      'heart_rate.resting',
      'sleep.duration',
    ]);
    expect(snapshot.count(HealthStatus.withinBaseline), 3);
  });

  test('explanations are built from librakia numbers only', () {
    for (final i in snapshot.insights) {
      final e = explain(i);
      for (final text in [
        e.headline,
        e.whatChanged,
        e.byHowMuch,
        e.since,
        e.evidence,
      ]) {
        expect(text, isNot(contains('NaN')), reason: i.metric.code);
        expect(text, isNot(contains('Infinity')), reason: i.metric.code);
        expect(text.trim(), isNotEmpty);
      }
    }
    final rhr = explain(insight('heart_rate.resting'));
    final b = insight('heart_rate.resting').baseline;
    expect(rhr.byHowMuch, contains(b.center.toStringAsFixed(1)));
    expect(rhr.since, contains('day 28'));
  });

  test('ending the simulation clears every simulated value', () async {
    final c = MissionController();
    await c.startSimulation(core);
    expect(c.isActive, isTrue);
    await c.endSimulation();
    expect(c.isActive, isFalse);
    expect(c.snapshot, isNull);
  });
}
