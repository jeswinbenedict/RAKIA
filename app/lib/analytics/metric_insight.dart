import 'package:flutter/foundation.dart';
import 'package:rakia_core/rakia_core.dart';

import '../components/health_status.dart';
import 'day_format.dart';
import 'metric_definitions.dart';

import 'metric_series.dart';

/// Everything librakia computed for one indicator, plus the inputs needed to
/// draw it. No value here is invented by the UI layer.
@immutable
class MetricInsight {
  const MetricInsight({
    required this.metric,
    required this.series,
    required this.reference,
    required this.monitoring,
    required this.monitoringQuality,
    required this.qualitySummary,
    required this.baseline,
    required this.assessment,
    required this.trend,
  });

  final MetricDefinition metric;
  final MetricSeries series;
  final List<double> reference;
  final List<double> monitoring;

  /// Per-sample quality from the quality gate (1 usable, 0 rejected).
  final List<double> monitoringQuality;
  final QualityResult qualitySummary;
  final Baseline baseline;
  final Assessment assessment;

  /// Theil-Sen trend over usable mission-day values; null when fewer than
  /// three usable values exist.
  final Trend? trend;

  HealthStatus get status => HealthStatus.values[assessment.level.index];

  /// Mission day (1-based) of an index in the monitoring window.
  static int dayOf(int index) => index + 1;

  /// Whether days are calendar dates (a real record) rather than mission
  /// days of a simulation.
  bool get datesKnown => series.monitoringStart != null;

  /// The calendar day of a monitoring index, when [datesKnown].
  DateTime? dateOf(int index) =>
      series.monitoringStart?.add(Duration(days: index));

  /// A monitoring day in a sentence: "mission day 3" or "4 Nov".
  String dayLabel(int index) => switch (dateOf(index)) {
    final d? => formatDay(d, withYear: false),
    null => 'mission day ${dayOf(index)}',
  };

  /// A monitoring day on a chart axis: "Day 3" or "4 Nov".
  String axisLabel(int index) => switch (dateOf(index)) {
    final d? => formatDay(d, withYear: false),
    null => 'Day ${dayOf(index)}',
  };

  /// What the baseline days are called.
  String get referenceNoun => datesKnown ? 'earlier days' : 'pre-flight days';

  /// What the monitoring readings are called.
  String get readingsNoun => datesKnown
      ? 'readings from the past ${monitoring.length} days'
      : 'mission-day readings';

  /// Whether the assessment carries a sustained-shift explanation.
  bool get hasShift =>
      assessment.cusum.alarm &&
      assessment.reasons.contains(AssessmentReason.sustainedShift);

  int get rejectedCount => monitoring.length - assessment.nUsable;
}

/// Runs the librakia pipeline for one simulated indicator: quality gate on
/// both windows, robust baseline from the reference window, quality-gated
/// assessment of the mission window, and Theil-Sen trend.
MetricInsight analyse(RakiaCore core, MetricSeries s) {
  final m = s.metric;
  final qcfg = QualityConfig(
    plausibleMin: m.plausibleMin,
    plausibleMax: m.plausibleMax,
    expectedSamples: s.monitoring.length.toDouble(),
  );
  final refQuality = core.qualityAssess(
    s.reference,
    config: QualityConfig(
      plausibleMin: m.plausibleMin,
      plausibleMax: m.plausibleMax,
    ),
  );
  final baseline = core.baseline(
    s.reference,
    quality: refQuality.quality,
    config: core.baselineDefaults.copyWith(minSpread: m.minSpread),
  );
  final monQuality = core.qualityAssess(
    s.monitoring,
    sensorFlags: s.sensorFlags,
    config: qcfg,
  );
  final assessment = core.assess(
    s.monitoring,
    baseline: baseline,
    quality: monQuality.quality,
  );

  final t = <double>[];
  final y = <double>[];
  for (var i = 0; i < s.monitoring.length; i++) {
    if (monQuality.quality[i] >= core.assessDefaults.minSampleQuality) {
      t.add(MetricInsight.dayOf(i).toDouble());
      y.add(s.monitoring[i]);
    }
  }
  final trend = t.length >= 3 ? core.trend(t, y) : null;

  return MetricInsight(
    metric: m,
    series: s,
    reference: s.reference,
    monitoring: s.monitoring,
    monitoringQuality: monQuality.quality,
    qualitySummary: monQuality,
    baseline: baseline,
    assessment: assessment,
    trend: trend,
  );
}

/// Indicators that need attention, most severe first: Act, Watch, then
/// data-quality problems. Order within a level is kept.
List<MetricInsight> rankAlerts(Iterable<MetricInsight> insights) {
  int rank(HealthStatus s) => switch (s) {
    HealthStatus.act => 0,
    HealthStatus.watch => 1,
    HealthStatus.dataQuality => 2,
    _ => 3,
  };
  final list = insights.where((i) => rank(i.status) < 3).toList();
  // List.sort is not stable; sort by (rank, original position).
  final pos = {for (var k = 0; k < list.length; k++) list[k]: k};
  list.sort((a, b) {
    final r = rank(a.status).compareTo(rank(b.status));
    return r != 0 ? r : pos[a]!.compareTo(pos[b]!);
  });
  return list;
}

/// The six parts of an explainable alert (see the Action center module).
@immutable
class AlertExplanation {
  const AlertExplanation({
    required this.headline,
    required this.whatChanged,
    required this.byHowMuch,
    required this.since,
    required this.evidence,
    required this.whyItMatters,
    required this.checkNext,
  });

  final String headline;
  final String whatChanged;
  final String byHowMuch;
  final String since;
  final String evidence;
  final String whyItMatters;
  final String checkNext;
}

/// Builds the explanation from librakia's outputs only.
AlertExplanation explain(MetricInsight i) {
  final m = i.metric;
  final a = i.assessment;
  final b = i.baseline;
  final usable = a.nUsable;
  final total = i.monitoring.length;
  final quality = (a.windowQuality * 100).round();

  if (i.status == HealthStatus.dataQuality && i.datesKnown) {
    final unusable = i.qualitySummary.nTotal - i.qualitySummary.nValid;
    return AlertExplanation(
      headline: '${m.label}: not enough recent readings',
      whatChanged:
          'Only $usable of the past $total days have a usable reading, below '
          'the 70% RAKIA needs before it assesses a trend.',
      byHowMuch: '$quality% of days usable.',
      since: _firstRejectedDay(i),
      evidence:
          '$unusable of the past $total days have no reading or one outside '
          'the plausible range.',
      whyItMatters:
          'A change can only be told apart from day-to-day variation when '
          'readings are regular.',
      checkNext:
          'Add any missing days you have readings for (up to 90 days back), '
          'and record one each day from now on.',
    );
  }

  if (i.status == HealthStatus.dataQuality) {
    return AlertExplanation(
      headline: '${m.label}: not enough reliable readings',
      whatChanged:
          'Only $usable of $total mission-day readings passed the quality '
          'gate, below the 70% RAKIA needs before it assesses a trend.',
      byHowMuch: '$quality% of readings usable.',
      since: _firstRejectedDay(i),
      evidence:
          '${i.qualitySummary.nTotal - i.qualitySummary.nValid} readings were '
          'missing, implausible or flagged by the device.',
      whyItMatters: m.whyItMatters,
      checkNext: m.checkNext,
    );
  }

  final direction = a.cusum.direction > 0 || a.deviation > 0
      ? 'above'
      : 'below';
  final dev = a.deviation.abs();
  final byHowMuch =
      'Latest reading ${m.formatWithUnit(a.latestValue)}, '
      '${m.format(dev)} ${m.unit == '%' ? 'percentage points' : m.unit} '
      '$direction the baseline median of ${m.formatWithUnit(b.center)} '
      '(robust z ${a.latestZ.toStringAsFixed(1)}).';

  final String whatChanged;
  final String since;
  if (i.hasShift) {
    final onset = MetricInsight.dayOf(a.cusum.onsetIndex);
    final alarm = MetricInsight.dayOf(a.cusum.alarmIndex);
    whatChanged =
        '${m.label} has shifted $direction your personal baseline and stayed '
        'there.';
    since = i.datesKnown
        ? 'Estimated onset ${i.dayLabel(a.cusum.onsetIndex)}; the sustained '
              'shift was detected on ${i.dayLabel(a.cusum.alarmIndex)}.'
        : 'Estimated onset mission day $onset; the sustained shift was '
              'detected on day $alarm.';
  } else if (a.reasons.contains(AssessmentReason.pointDeviation)) {
    whatChanged =
        'The latest reading is unusually far $direction your baseline. One '
        'reading is not a trend, so RAKIA asks for confirmation.';
    since = 'Latest reading, ${i.dayLabel(a.latestIndex)}.';
  } else {
    final trend = trendSummary(i);
    whatChanged = trend.significant
        ? '${m.label} is within your personal baseline, but readings show a '
              '${trend.direction} trend '
              '${i.datesKnown ? 'over the past week' : 'across the mission'}.'
        : '${m.label} is within your personal baseline.';
    since = i.datesKnown
        ? 'No sustained change detected in the past week.'
        : 'No sustained change detected in this mission.';
  }

  return AlertExplanation(
    headline: switch (i.status) {
      HealthStatus.act => '${m.label}: sustained change',
      HealthStatus.watch => '${m.label}: worth watching',
      _ => m.label,
    },
    whatChanged: whatChanged,
    byHowMuch: byHowMuch,
    since: since,
    evidence:
        '$usable usable ${i.readingsNoun} compared with a baseline of '
        '${b.n} ${i.referenceNoun} (median ${m.formatWithUnit(b.center)}, '
        'spread ${m.format(b.spread)}).',
    whyItMatters: m.whyItMatters,
    checkNext: m.checkNext,
  );
}

/// Theil-Sen slope per week with Mann-Kendall significance.
@immutable
class TrendSummary {
  const TrendSummary({
    required this.text,
    required this.significant,
    required this.direction,
  });

  final String text;

  /// Two-sided Mann-Kendall p < 0.05.
  final bool significant;

  /// 'rising', 'declining' or 'flat'.
  final String direction;
}

TrendSummary trendSummary(MetricInsight i) {
  final tr = i.trend;
  final m = i.metric;
  if (tr == null) {
    return const TrendSummary(
      text: 'Not enough usable readings for a trend.',
      significant: false,
      direction: 'flat',
    );
  }
  final perWeek = tr.slope * 7;
  final significant = tr.pValue < 0.05;
  final direction = perWeek > 0
      ? 'rising'
      : perWeek < 0
      ? 'declining'
      : 'flat';
  final p = tr.pValue < 0.001
      ? 'p < 0.001'
      : 'p = ${tr.pValue.toStringAsFixed(tr.pValue < 0.01 ? 3 : 2)}';
  final rate =
      '${perWeek >= 0 ? '+' : '-'}${m.format(perWeek.abs())} '
      '${m.unit == '%' ? 'points' : m.unit} per week';
  return TrendSummary(
    text: significant
        ? '${direction[0].toUpperCase()}${direction.substring(1)} trend, '
              '$rate (Mann-Kendall $p).'
        : 'No significant trend ($rate, Mann-Kendall $p).',
    significant: significant,
    direction: direction,
  );
}

String _firstRejectedDay(MetricInsight i) {
  for (var k = 0; k < i.monitoringQuality.length; k++) {
    if (i.monitoringQuality[k] < 0.5) {
      return i.datesKnown
          ? 'First day without a usable reading: ${i.dayLabel(k)}.'
          : 'First rejected reading on ${i.dayLabel(k)}.';
    }
  }
  return 'No rejected readings.';
}
