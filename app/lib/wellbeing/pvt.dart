import 'dart:math';

import 'instruments.dart';

enum PvtPhase { ready, waiting, stimulus, finished }

/// The state of one psychomotor vigilance test, independent of the UI.
///
/// Time comes from [clock] (a monotonic stopwatch in the app, a controlled
/// value in tests). The UI calls [tick] every frame, [stimulusShown] once the
/// frame showing a stimulus has been drawn, and [respond] on a tap or key
/// press.
class PvtSession {
  PvtSession({
    required this.clock,
    Random? random,
    this.duration = Pvt.duration,
  }) : _random = random ?? Random();

  /// Monotonic time since an arbitrary origin.
  final Duration Function() clock;
  final Random _random;
  final Duration duration;

  PvtPhase _phase = PvtPhase.ready;
  Duration _start = Duration.zero;
  Duration _nextOnset = Duration.zero;
  Duration? _shownAt;
  int? _lastResponseMs;
  int _falseStarts = 0;
  final List<int?> _responseTimesMs = [];

  PvtPhase get phase => _phase;

  /// Response time of each stimulus so far; null for a timeout.
  List<int?> get responseTimesMs => List.unmodifiable(_responseTimesMs);

  /// Taps or key presses while no stimulus was showing.
  int get falseStarts => _falseStarts;

  /// The most recent response time, shown as feedback until the next
  /// stimulus.
  int? get lastResponseMs => _lastResponseMs;

  /// Milliseconds since the current stimulus appeared (the running counter).
  int get stimulusElapsedMs =>
      _shownAt == null ? 0 : (clock() - _shownAt!).inMilliseconds;

  Duration get elapsed =>
      _phase == PvtPhase.ready ? Duration.zero : clock() - _start;

  Duration get remaining {
    final r = duration - elapsed;
    return r.isNegative ? Duration.zero : r;
  }

  /// Whether the UI should now show a stimulus.
  bool get stimulusDue =>
      _phase == PvtPhase.waiting &&
      clock() >= _nextOnset &&
      _nextOnset - _start < duration;

  void start() {
    _start = clock();
    _phase = PvtPhase.waiting;
    _schedule(_start);
  }

  void _schedule(Duration from) {
    final min = Pvt.minInterval.inMicroseconds;
    final span = Pvt.maxInterval.inMicroseconds - min;
    _nextOnset =
        from +
        Duration(microseconds: min + (_random.nextDouble() * span).round());
  }

  void stimulusShown() {
    if (_phase != PvtPhase.waiting) return;
    _shownAt = clock();
    _phase = PvtPhase.stimulus;
  }

  /// Advances timeouts and the end of the test. Returns true when the test
  /// has just finished.
  bool tick() {
    if (_phase == PvtPhase.ready || _phase == PvtPhase.finished) return false;
    final now = clock();
    if (_phase == PvtPhase.stimulus &&
        (now - _shownAt!).inMilliseconds >= Pvt.timeoutMs) {
      _responseTimesMs.add(null);
      _lastResponseMs = null;
      _shownAt = null;
      _phase = PvtPhase.waiting;
      _schedule(now);
    }
    // No stimulus starts after the end; one in progress is answered (or
    // times out) first.
    if (_phase == PvtPhase.waiting && now - _start >= duration) {
      _phase = PvtPhase.finished;
      return true;
    }
    return false;
  }

  /// Records a tap or key press. Returns the response time, or null for a
  /// false start.
  int? respond() {
    if (_phase == PvtPhase.stimulus) {
      final now = clock();
      final rt = (now - _shownAt!).inMilliseconds;
      _responseTimesMs.add(rt);
      _lastResponseMs = rt;
      _shownAt = null;
      _phase = PvtPhase.waiting;
      _schedule(now);
      if (now - _start >= duration) _phase = PvtPhase.finished;
      return rt;
    }
    if (_phase == PvtPhase.waiting) _falseStarts++;
    return null;
  }

  ReactionTestResult result({
    required DateTime recordedAt,
    required String device,
  }) => ReactionTestResult.score(
    recordedAt: recordedAt,
    duration: elapsed > duration ? elapsed : duration,
    responseTimesMs: _responseTimesMs,
    falseStarts: _falseStarts,
    device: device,
  );
}
