// What the astronaut did about an alert on their own record. Responses are
// kept on the device as an immutable log next to the readings, so the
// record shows not only what changed but how it was followed up.
import 'package:flutter/foundation.dart';

import '../analytics/metric_insight.dart';
import '../components/health_status.dart';

/// Ways to respond to an alert. Codes are stored; never renumber them.
enum AlertResponseKind {
  confirmatoryReading(1, 'Took a confirmatory reading'),
  valueChecked(2, 'Checked the reading: it is correct'),
  valueCorrected(3, 'Corrected the reading'),
  keepWatching(4, 'Chose to keep watching'),
  contactedMedical(5, 'Contacted medical support');

  const AlertResponseKind(this.code, this.label);

  final int code;
  final String label;

  static AlertResponseKind fromCode(int code) =>
      values.firstWhere((k) => k.code == code);
}

/// One logged response.
@immutable
class AlertResponse {
  const AlertResponse({
    required this.id,
    required this.metricCode,
    required this.alertLevel,
    required this.alertDay,
    required this.kind,
    required this.recordedAt,
    this.outcome,
    this.note,
  });

  final String id;
  final String metricCode;

  /// The level of the alert answered (watch, act or data quality).
  final HealthStatus alertLevel;

  /// The day the alert concerns (UTC midnight of the date).
  final DateTime alertDay;
  final AlertResponseKind kind;
  final DateTime recordedAt;

  /// For a confirmatory reading or correction: the indicator's level after
  /// the new value was evaluated.
  final HealthStatus? outcome;
  final String? note;
}

/// Longest note the astronaut can add to a response.
const int kMaxResponseNote = 500;

/// The day an alert concerns: the estimated onset of a sustained shift, the
/// flagged reading, or the first day without a usable reading. Null when
/// the insight has no calendar dates (a simulation).
DateTime? alertDay(MetricInsight i) {
  final a = i.assessment;
  if (i.status == HealthStatus.dataQuality) {
    for (var k = 0; k < i.monitoringQuality.length; k++) {
      if (i.monitoringQuality[k] < 0.5) return i.dateOf(k);
    }
    return i.dateOf(0);
  }
  if (i.hasShift) return i.dateOf(a.cusum.onsetIndex);
  return i.dateOf(a.latestIndex);
}

/// Whether a confirmatory reading or correction settled the alert.
String outcomeText(HealthStatus outcome) => switch (outcome) {
  HealthStatus.withinBaseline => 'Back within your usual range.',
  HealthStatus.watch => 'Still flagged: watch.',
  HealthStatus.act => 'Still flagged: act now.',
  HealthStatus.dataQuality => 'Not enough recent readings to judge.',
  HealthStatus.insufficientData => 'Not enough data to judge.',
};
