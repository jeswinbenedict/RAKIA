import 'package:flutter/material.dart';

/// A tracked indicator: units, plausibility limits and the plain-language
/// context shown with every alert. Copy is deliberately non-diagnostic.
@immutable
class MetricDefinition {
  const MetricDefinition({
    required this.code,
    required this.label,
    required this.unit,
    required this.ucum,
    required this.moduleId,
    required this.icon,
    required this.plausibleMin,
    required this.plausibleMax,
    required this.minSpread,
    required this.decimals,
    required this.whyItMatters,
    required this.checkNext,
    required this.repeatable,
    required this.confirmatoryCheck,
  });

  /// librakia metric code, `[a-z0-9_.]`.
  final String code;
  final String label;

  /// Unit as displayed.
  final String unit;

  /// UCUM code used in the ledger.
  final String ucum;

  /// Module that owns the indicator (see navigation/modules.dart).
  final String moduleId;
  final IconData icon;

  /// Values outside this range are rejected by the quality gate.
  final double plausibleMin;
  final double plausibleMax;

  /// Floor for the baseline spread, in [unit].
  final double minSpread;

  /// Decimal places when formatting values.
  final int decimals;
  final String whyItMatters;
  final String checkNext;

  /// Whether a spot measurement can simply be taken again to confirm an
  /// alert (heart rate, SpO2). Daily totals (sleep, exercise) are confirmed
  /// by checking the recorded value instead.
  final bool repeatable;

  /// How to confirm an alert on this indicator, in one or two sentences.
  final String confirmatoryCheck;

  String format(double v) => v.isFinite ? v.toStringAsFixed(decimals) : '-';

  String formatWithUnit(double v) =>
      unit == '%' ? '${format(v)}%' : '${format(v)} $unit';
}

const restingHeartRate = MetricDefinition(
  code: 'heart_rate.resting',
  label: 'Resting heart rate',
  unit: 'bpm',
  ucum: '/min',
  moduleId: 'cardio',
  icon: Icons.monitor_heart_outlined,
  plausibleMin: 30,
  plausibleMax: 120,
  minSpread: 1,
  decimals: 1,
  whyItMatters:
      'A sustained rise in resting heart rate can accompany short sleep, high '
      'workload, illness or reduced fitness. It is a prompt to look closer, '
      'not a diagnosis.',
  checkNext:
      'Repeat a resting measurement after five minutes seated, review recent '
      'sleep and exercise, and report it to your flight surgeon if it '
      'persists.',
  repeatable: true,
  confirmatoryCheck:
      'Sit quietly for five minutes, then measure your resting heart rate '
      'again.',
);

const heartRateVariability = MetricDefinition(
  code: 'hrv.rmssd',
  label: 'Heart-rate variability',
  unit: 'ms',
  ucum: 'ms',
  moduleId: 'cardio',
  icon: Icons.ssid_chart,
  plausibleMin: 5,
  plausibleMax: 250,
  minSpread: 2,
  decimals: 0,
  whyItMatters:
      'Heart-rate variability (RMSSD) reflects autonomic balance and is '
      'sensitive to stress, fatigue and sleep. It differs widely between '
      'people, so only change against your own baseline is meaningful.',
  checkNext:
      'Check that readings were taken at the same time of day and in the same '
      'posture, and look at sleep and workload over the same period.',
  repeatable: true,
  confirmatoryCheck:
      'Take the reading again in your usual posture, ideally at the time of '
      'day you normally measure.',
);

const oxygenSaturation = MetricDefinition(
  code: 'spo2',
  label: 'Oxygen saturation',
  unit: '%',
  ucum: '%',
  moduleId: 'cardio',
  icon: Icons.air,
  plausibleMin: 70,
  plausibleMax: 100,
  minSpread: 0.3,
  decimals: 1,
  whyItMatters:
      'Peripheral oxygen saturation is normally stable. Consumer sensors are '
      'affected by motion and fit, so a single low reading is usually a '
      'measurement issue.',
  checkNext:
      'Repeat the measurement at rest with the sensor seated correctly, and '
      'compare with cabin oxygen and CO2 readings.',
  repeatable: true,
  confirmatoryCheck:
      'Rest for a few minutes, check that the sensor is seated correctly, and '
      'measure again.',
);

const sleepDuration = MetricDefinition(
  code: 'sleep.duration',
  label: 'Sleep duration',
  unit: 'h',
  ucum: 'h',
  moduleId: 'sleep',
  icon: Icons.bedtime_outlined,
  plausibleMin: 0.5,
  plausibleMax: 16,
  minSpread: 0.25,
  decimals: 1,
  whyItMatters:
      'On-orbit studies report shorter sleep than on the ground. Missing nights '
      'make the trend unreliable, so RAKIA reports a data problem instead of a '
      'health signal.',
  checkNext:
      'Check that the sleep device is charged and worn overnight. RAKIA will '
      'reassess once enough nights are recorded.',
  repeatable: false,
  confirmatoryCheck:
      "Compare the flagged night's value with your sleep device, and correct "
      'it if it was entered wrongly.',
);

const exerciseMinutes = MetricDefinition(
  code: 'exercise.duration',
  label: 'Exercise',
  unit: 'min',
  ucum: 'min',
  moduleId: 'physical',
  icon: Icons.fitness_center,
  plausibleMin: 0,
  plausibleMax: 300,
  minSpread: 5,
  decimals: 0,
  whyItMatters:
      'Daily exercise is the main countermeasure against bone and muscle loss '
      'in microgravity. Adherence matters more than any single session.',
  checkNext: 'Compare completed sessions with the planned exercise schedule.',
  repeatable: false,
  confirmatoryCheck:
      "Compare the flagged day's value with your exercise log, and correct it "
      'if it was entered wrongly.',
);

/// Every indicator in display order.
const List<MetricDefinition> kMetricDefinitions = [
  restingHeartRate,
  heartRateVariability,
  oxygenSaturation,
  sleepDuration,
  exerciseMinutes,
];
