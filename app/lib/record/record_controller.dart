import 'package:flutter/widgets.dart';
import 'package:rakia_core/rakia_core.dart';

import '../analytics/metric_definitions.dart';
import '../analytics/metric_insight.dart';
import '../analytics/metric_series.dart';
import '../components/health_status.dart';
import '../storage/local_store.dart';
import 'alert_response.dart';
import 'record.dart';

/// One indicator of the personal record: its daily series and, once the
/// baseline has enough days, librakia's evaluation of it.
@immutable
class RecordIndicator {
  const RecordIndicator({
    required this.metric,
    required this.series,
    required this.baselineDays,
    required this.entries,
    this.insight,
    this.analysisError,
  });

  final MetricDefinition metric;
  final MetricSeries series;

  /// Days with a reading in the reference window (needs
  /// [RecordWindows.minBaselineDays]).
  final int baselineDays;

  /// Current entries (corrections applied), newest day first.
  final List<RecordEntry> entries;

  /// Null until the baseline is established.
  final MetricInsight? insight;
  final String? analysisError;

  bool get baselineReady => baselineDays >= RecordWindows.minBaselineDays;
}

/// The astronaut's own record of real readings. Entries are appended to the
/// on-device ledger; evaluation is recomputed by librakia after each change.
class RecordController extends ChangeNotifier {
  RecordController({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  LocalStore? _store;
  RakiaCore? _core;
  String? _recordId;
  List<RecordEntry> _entries = const [];
  List<RecordIndicator> _indicators = const [];
  List<MetricInsight> _alerts = const [];
  List<AlertResponse> _responses = const [];
  bool _loading = false;
  bool _disposed = false;
  String? _error;

  bool get ready => _store != null && _core != null;
  bool get loading => _loading;
  String? get error => _error;

  /// Whether readings survive closing the app.
  bool get persistent => _store?.kind.persistent ?? false;

  bool get hasEntries => _entries.isNotEmpty;

  /// One per indicator, in display order.
  List<RecordIndicator> get indicators => _indicators;

  /// Evaluated indicators that need attention, most severe first. Every
  /// alert comes from the astronaut's own readings; none is simulated.
  List<MetricInsight> get alerts => _alerts;

  /// The current evaluation of an indicator, if its baseline is ready.
  MetricInsight? insightFor(String metricCode) {
    for (final i in _indicators) {
      if (i.metric.code == metricCode) return i.insight;
    }
    return null;
  }

  /// Every response logged for an indicator, newest first.
  List<AlertResponse> responsesForMetric(String metricCode) => [
    for (final r in _responses.reversed)
      if (r.metricCode == metricCode) r,
  ];

  /// Responses to [alert]: those logged for its indicator on or after the
  /// day it concerns, newest first.
  List<AlertResponse> responsesFor(MetricInsight alert) {
    final since = alertDay(alert);
    return [
      for (final r in _responses.reversed)
        if (r.metricCode == alert.metric.code &&
            (since == null ||
                !calendarDay(r.recordedAt.toLocal()).isBefore(since)))
          r,
    ];
  }

  /// Today as a calendar day.
  DateTime get today => calendarDay(_clock());

  Future<void> attach(LocalStore store, RakiaCore core) async {
    _store = store;
    _core = core;
    _loading = true;
    _notify();
    try {
      _recordId = await store.personalRecordId();
      if (_recordId case final id?) {
        // Read everything before publishing any of it: a frame drawn
        // between two awaits must never see readings without their
        // evaluation.
        final entries = await store.recordEntries(id);
        final responses = await store.alertResponses(id);
        _entries = entries;
        _responses = responses;
      }
      _error = null;
    } on Object catch (e) {
      _error = 'Your health record could not be loaded: $e';
    } finally {
      _loading = false;
      _recompute();
    }
  }

  /// Records a reading. Returns the validation message instead of saving
  /// when the input is not acceptable.
  ///
  /// With [respondingTo], the reading is the confirmatory check of that
  /// alert (or, with [correcting], its correction): once it is evaluated,
  /// the response and the indicator's new level are logged.
  Future<String?> add({
    required MetricDefinition metric,
    required double? value,
    required DateTime day,
    RecordEntry? correcting,
    MetricInsight? respondingTo,
  }) async {
    final store = _store;
    final core = _core;
    if (store == null || core == null) return 'The record is still opening.';
    final problem = validateEntry(
      metric: metric,
      value: value,
      day: day,
      today: today,
    );
    if (problem != null) return problem;
    try {
      _recordId ??= await store.createPersonalRecord(label: 'Me');
      final saved = await store.addRecordEntry(
        recordId: _recordId!,
        metric: metric,
        value: value!,
        day: day,
        core: core,
        supersedesId: correcting?.id,
      );
      _entries = [..._entries, saved];
      _error = null;
    } on Object catch (e) {
      return 'The reading could not be saved: $e';
    }
    _recompute();
    if (respondingTo != null) {
      final logged = await _log(
        respondingTo,
        correcting == null
            ? AlertResponseKind.confirmatoryReading
            : AlertResponseKind.valueCorrected,
        outcome:
            insightFor(metric.code)?.status ?? HealthStatus.insufficientData,
        note:
            '${correcting == null ? 'Reading' : 'Corrected to'} '
            '${metric.formatWithUnit(value)}.',
      );
      if (logged != null) return 'The reading was saved, but $logged';
    }
    return null;
  }

  /// Logs a response that needs no new reading: the value was checked and
  /// is correct, the astronaut keeps watching, or medical support was
  /// contacted. Returns what went wrong, or null.
  Future<String?> respond(
    MetricInsight alert,
    AlertResponseKind kind, {
    String? note,
  }) {
    assert(
      kind != AlertResponseKind.confirmatoryReading &&
          kind != AlertResponseKind.valueCorrected,
      'readings are logged through add()',
    );
    if (note != null && note.trim().length > kMaxResponseNote) {
      return Future.value('Keep the note under $kMaxResponseNote characters.');
    }
    return _log(alert, kind, note: note);
  }

  Future<String?> _log(
    MetricInsight alert,
    AlertResponseKind kind, {
    HealthStatus? outcome,
    String? note,
  }) async {
    final store = _store;
    final id = _recordId;
    if (store == null || id == null) return 'the record is not open.';
    try {
      final saved = await store.addAlertResponse(
        recordId: id,
        metricCode: alert.metric.code,
        alertLevel: alert.status,
        alertDay: alertDay(alert) ?? today,
        kind: kind,
        outcome: outcome,
        note: note,
        now: _clock(),
      );
      _responses = [..._responses, saved];
    } on Object catch (e) {
      return 'the response could not be logged: $e';
    }
    _notify();
    return null;
  }

  void _recompute() {
    final core = _core;
    final day = today;
    _indicators = [
      for (final m in kMetricDefinitions) _indicator(m, core, day),
    ];
    _alerts = rankAlerts([for (final i in _indicators) ?i.insight]);
    _notify();
  }

  RecordIndicator _indicator(MetricDefinition m, RakiaCore? core, DateTime d) {
    final series = recordSeries(m, _entries, d);
    final days = baselineDays(series);
    final current = currentByDay(_entries, m.code).values.toList()
      ..sort((a, b) => b.day.compareTo(a.day));
    MetricInsight? insight;
    String? analysisError;
    if (core != null && days >= RecordWindows.minBaselineDays) {
      try {
        insight = analyse(core, series);
      } on RakiaException catch (e) {
        analysisError = 'librakia could not evaluate this indicator: $e';
      }
    }
    return RecordIndicator(
      metric: m,
      series: series,
      baselineDays: days,
      entries: current,
      insight: insight,
      analysisError: analysisError,
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class RecordScope extends InheritedNotifier<RecordController> {
  const RecordScope({
    super.key,
    required RecordController controller,
    required super.child,
  }) : super(notifier: controller);

  static RecordController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RecordScope>();
    assert(scope != null, 'RecordScope is missing from the widget tree');
    return scope!.notifier!;
  }
}
