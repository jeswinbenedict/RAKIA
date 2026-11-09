import 'package:flutter/widgets.dart';
import 'package:rakia_core/rakia_core.dart';

import '../analytics/metric_definitions.dart';
import '../analytics/metric_insight.dart';
import '../analytics/metric_series.dart';
import '../storage/local_store.dart';
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

  /// Today as a calendar day.
  DateTime get today => calendarDay(_clock());

  Future<void> attach(LocalStore store, RakiaCore core) async {
    _store = store;
    _core = core;
    _loading = true;
    _notify();
    try {
      _recordId = await store.personalRecordId();
      if (_recordId != null) _entries = await store.recordEntries(_recordId!);
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
  Future<String?> add({
    required MetricDefinition metric,
    required double? value,
    required DateTime day,
    RecordEntry? correcting,
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
    return null;
  }

  void _recompute() {
    final core = _core;
    final day = today;
    _indicators = [
      for (final m in kMetricDefinitions) _indicator(m, core, day),
    ];
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
