// The astronaut's own health record: real readings they enter themselves,
// kept in the device's hash-chained ledger as a real (non-simulation)
// mission. Nothing here is generated; every value was typed in by the user.
import 'package:flutter/foundation.dart';

import '../analytics/metric_definitions.dart';
import '../analytics/metric_series.dart';

/// How the evaluation windows are laid out, counted back from today:
/// the last [monitoringDays] days are compared with the astronaut's usual
/// range, learned from up to [referenceDays] days before them.
abstract final class RecordWindows {
  static const int monitoringDays = 7;
  static const int referenceDays = 35;

  /// librakia needs this many usable days to establish a baseline.
  static const int minBaselineDays = 14;

  /// How far back a reading may be dated (for entering past history).
  static const int maxBackdateDays = 90;
}

/// One reading in the record, as stored.
@immutable
class RecordEntry {
  const RecordEntry({
    required this.id,
    required this.metricCode,
    required this.value,
    required this.unit,
    required this.day,
    required this.seq,
    this.supersedesId,
  });

  final String id;
  final String metricCode;
  final double value;
  final String unit;

  /// The calendar day the reading belongs to (UTC midnight of that date).
  final DateTime day;

  /// Position in the ledger; later entries win for the same day.
  final int seq;

  /// The entry this one corrects, if any.
  final String? supersedesId;
}

/// A calendar date as stored: UTC midnight of the date the user picked, so
/// a reading never moves to another day when time zones change.
DateTime calendarDay(DateTime local) =>
    DateTime.utc(local.year, local.month, local.day);

/// Why an entry cannot be recorded, in words for the form; null when valid.
String? validateEntry({
  required MetricDefinition metric,
  required double? value,
  required DateTime day,
  required DateTime today,
}) {
  if (value == null || !value.isFinite) return 'Enter a number.';
  if (value < metric.plausibleMin || value > metric.plausibleMax) {
    return 'Enter a value between ${metric.formatWithUnit(metric.plausibleMin)} '
        'and ${metric.formatWithUnit(metric.plausibleMax)}.';
  }
  if (day.isAfter(today)) return 'The date cannot be in the future.';
  if (today.difference(day).inDays > RecordWindows.maxBackdateDays) {
    return 'Readings can be dated up to ${RecordWindows.maxBackdateDays} '
        'days back.';
  }
  return null;
}

/// The entries that currently count: corrected entries are replaced by
/// their corrections, and of several readings on one day the latest wins.
Map<DateTime, RecordEntry> currentByDay(
  Iterable<RecordEntry> entries,
  String metricCode,
) {
  final superseded = {
    for (final e in entries)
      if (e.supersedesId != null) e.supersedesId!,
  };
  final byDay = <DateTime, RecordEntry>{};
  for (final e in entries) {
    if (e.metricCode != metricCode || superseded.contains(e.id)) continue;
    final prev = byDay[e.day];
    if (prev == null || e.seq > prev.seq) byDay[e.day] = e;
  }
  return byDay;
}

/// The daily series librakia analyses: the reference window (oldest first)
/// and the monitoring window ending [today], NaN on days without a reading.
MetricSeries recordSeries(
  MetricDefinition metric,
  Iterable<RecordEntry> entries,
  DateTime today,
) {
  const mon = RecordWindows.monitoringDays;
  const ref = RecordWindows.referenceDays;
  final byDay = currentByDay(entries, metric.code);
  double at(int daysBack) =>
      byDay[today.subtract(Duration(days: daysBack))]?.value ?? double.nan;
  return MetricSeries(
    metric: metric,
    reference: [for (var k = mon + ref - 1; k >= mon; k--) at(k)],
    monitoring: [for (var k = mon - 1; k >= 0; k--) at(k)],
    sensorFlags: List.filled(mon, 0),
    monitoringStart: today.subtract(const Duration(days: mon - 1)),
  );
}

/// Days with a reading in the reference window: the baseline's progress.
int baselineDays(MetricSeries s) => s.reference.where((v) => v.isFinite).length;
