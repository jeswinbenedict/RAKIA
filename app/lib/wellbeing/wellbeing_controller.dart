import 'package:flutter/widgets.dart';

import '../storage/local_store.dart';
import '../storage/uuid.dart';
import 'instruments.dart';

/// The astronaut's private check-ins and reaction-time results. Kept in the
/// on-device store when one is attached; otherwise in memory for this
/// session only, which the page states.
class WellbeingController extends ChangeNotifier {
  LocalStore? _store;
  bool _loading = false;
  bool _disposed = false;
  String? _error;
  List<CheckIn> _checkIns = const [];
  List<ReactionTestResult> _tests = const [];

  /// Newest first.
  List<CheckIn> get checkIns => _checkIns;

  /// Newest first.
  List<ReactionTestResult> get reactionTests => _tests;

  bool get loading => _loading;
  String? get error => _error;

  /// Whether records survive closing the app.
  bool get persistent => _store != null && _store!.kind.persistent;

  bool get isEmpty => _checkIns.isEmpty && _tests.isEmpty;

  /// Loads the records saved in [store]; later records are saved to it.
  /// Records made in memory before the store opened are saved too.
  Future<void> attach(LocalStore store) async {
    _store = store;
    _loading = true;
    _notify();
    try {
      for (final c in _checkIns.reversed) {
        await store.addCheckIn(
          sleepiness: c.sleepiness,
          stress: c.stress,
          mood: c.mood,
          now: c.recordedAt,
        );
      }
      for (final t in _tests.reversed) {
        await store.addReactionTest(t);
      }
      _checkIns = await store.checkIns();
      _tests = await store.reactionTests();
      _error = null;
    } on Object catch (e) {
      _error = 'Your wellbeing records could not be loaded: $e';
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<CheckIn> addCheckIn({
    required int sleepiness,
    required int stress,
    required int mood,
    DateTime? now,
  }) async {
    final store = _store;
    final CheckIn saved;
    if (store != null) {
      saved = await store.addCheckIn(
        sleepiness: sleepiness,
        stress: stress,
        mood: mood,
        now: now,
      );
    } else {
      final at = (now ?? DateTime.now()).toUtc();
      saved = CheckIn(
        id: uuidToString(uuidV7(now: at)),
        recordedAt: at,
        sleepiness: sleepiness,
        stress: stress,
        mood: mood,
      );
    }
    _checkIns = [saved, ..._checkIns];
    _notify();
    return saved;
  }

  Future<ReactionTestResult> addReactionTest(ReactionTestResult t) async {
    final store = _store;
    final saved = store != null
        ? await store.addReactionTest(t)
        : t.withId(uuidToString(uuidV7(now: t.recordedAt)));
    _tests = [saved, ..._tests];
    _notify();
    return saved;
  }

  /// Deletes every check-in and reaction-time result on this device.
  Future<void> deleteAll() async {
    await _store?.deleteWellbeingRecords();
    _checkIns = const [];
    _tests = const [];
    _notify();
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

class WellbeingScope extends InheritedNotifier<WellbeingController> {
  const WellbeingScope({
    super.key,
    required WellbeingController controller,
    required super.child,
  }) : super(notifier: controller);

  static WellbeingController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<WellbeingScope>();
    assert(scope != null, 'WellbeingScope is missing from the widget tree');
    return scope!.notifier!;
  }
}
