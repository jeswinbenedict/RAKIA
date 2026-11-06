import 'package:flutter/foundation.dart';

import '../analytics/metric_definitions.dart';
import 'seeded_random.dart';

/// One simulated indicator: a pre-flight reference window and an in-mission
/// monitoring window of daily values, plus the change that was deliberately
/// injected (the ground truth used to judge detection).
@immutable
class SimulatedSeries {
  const SimulatedSeries({
    required this.metric,
    required this.reference,
    required this.monitoring,
    required this.sensorFlags,
    required this.scenario,
    this.changeDay,
  });

  final MetricDefinition metric;

  /// One value per pre-flight day.
  final List<double> reference;

  /// One value per mission day; NaN where no reading was recorded.
  final List<double> monitoring;

  /// Non-zero where the simulated device reported a sensor problem.
  final List<int> sensorFlags;

  /// Plain-language description of what was simulated.
  final String scenario;

  /// Mission day (1-based) on which the injected change starts, if any.
  final int? changeDay;
}

/// A deterministic, clearly labelled simulation mission.
///
/// The values are synthetic: they are drawn from simple statistical models
/// with chosen changes injected, not from a physiological model and not from
/// any astronaut. They exist to demonstrate and test the analytics, which are
/// computed by librakia exactly as they would be for real data.
@immutable
class SimulatedMission {
  const SimulatedMission({
    required this.seed,
    required this.name,
    required this.crewMember,
    required this.referenceDays,
    required this.missionDay,
    required this.plannedDays,
    required this.series,
  });

  /// Default scenario. Changing the seed changes every value.
  factory SimulatedMission.generate({int seed = 20261106}) {
    final rng = SeededRandom(seed);
    const refDays = 60;
    const missionDays = 45;

    List<double> normalSeries(int n, double mean, double sd) => [
      for (var i = 0; i < n; i++) mean + sd * rng.normal(),
    ];

    // Resting heart rate: step increase of 5 bpm (about 2.5 baseline SD)
    // from mission day 28.
    const rhrChange = 28;
    final rhr = SimulatedSeries(
      metric: restingHeartRate,
      reference: normalSeries(refDays, 58, 2),
      monitoring: [
        for (var d = 1; d <= missionDays; d++)
          58 + (d >= rhrChange ? 5.0 : 0.0) + 2 * rng.normal(),
      ],
      sensorFlags: List.filled(missionDays, 0),
      scenario:
          'A sustained step increase of 5 bpm, about 2.5 times the baseline '
          'standard deviation, injected from mission day $rhrChange.',
      changeDay: rhrChange,
    );

    // Heart-rate variability: gradual decline reaching 1 SD below baseline
    // by the last mission day.
    const hrvChange = 15;
    final hrv = SimulatedSeries(
      metric: heartRateVariability,
      reference: normalSeries(refDays, 55, 5),
      monitoring: [
        for (var d = 1; d <= missionDays; d++)
          55 -
              (d >= hrvChange
                  ? 5.0 * (d - hrvChange) / (missionDays - hrvChange)
                  : 0.0) +
              5 * rng.normal(),
      ],
      sensorFlags: List.filled(missionDays, 0),
      scenario:
          'A gradual decline from mission day $hrvChange, reaching 5 ms '
          '(1 baseline standard deviation) below baseline by day '
          '$missionDays.',
      changeDay: hrvChange,
    );

    // Oxygen saturation: no change.
    final spo2 = SimulatedSeries(
      metric: oxygenSaturation,
      reference: normalSeries(refDays, 97.6, 0.5),
      monitoring: [
        for (var d = 1; d <= missionDays; d++)
          (97.6 + 0.5 * rng.normal()).clamp(90, 100).toDouble(),
      ],
      sensorFlags: List.filled(missionDays, 0),
      scenario: 'No change injected; values vary around the baseline.',
    );

    // Sleep duration: a device outage over the last 20 nights (16 missing
    // nights and 2 artefact readings), so the window fails the quality gate.
    final sleepFlags = List.filled(missionDays, 0);
    final sleep = <double>[];
    for (var d = 1; d <= missionDays; d++) {
      final v = 6.7 + 0.5 * rng.normal();
      if (d > missionDays - 20 && d % 5 != 0) {
        sleep.add(double.nan); // no recording
      } else if (d == missionDays - 10 || d == missionDays) {
        sleep.add(0.2); // artefact: device reported a fault
        sleepFlags[d - 1] = 1;
      } else {
        sleep.add(v);
      }
    }
    final sleepSeries = SimulatedSeries(
      metric: sleepDuration,
      reference: normalSeries(refDays, 7.1, 0.45),
      monitoring: sleep,
      sensorFlags: sleepFlags,
      scenario:
          'Slightly shorter sleep in flight, then a device outage: 16 of the '
          'last 20 nights have no recording and 2 readings are flagged as '
          'sensor faults.',
      changeDay: missionDays - 19,
    );

    // Exercise: stable adherence.
    final exercise = SimulatedSeries(
      metric: exerciseMinutes,
      reference: normalSeries(refDays, 92, 12),
      monitoring: [
        for (var d = 1; d <= missionDays; d++)
          (90 + 12 * rng.normal()).clamp(0, 300).toDouble(),
      ],
      sensorFlags: List.filled(missionDays, 0),
      scenario: 'No change injected; daily sessions vary around the plan.',
    );

    return SimulatedMission(
      seed: seed,
      name: 'Simulation mission SIM-01',
      crewMember: 'Simulated crew member A',
      referenceDays: refDays,
      missionDay: missionDays,
      plannedDays: 180,
      series: [rhr, hrv, spo2, sleepSeries, exercise],
    );
  }

  final int seed;
  final String name;

  /// Not a real person.
  final String crewMember;

  /// Length of the pre-flight reference window, in days.
  final int referenceDays;

  /// Current mission day (1-based); also the monitoring window length.
  final int missionDay;
  final int plannedDays;
  final List<SimulatedSeries> series;
}
