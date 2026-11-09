import 'dart:async';

import 'package:flutter/widgets.dart';

import 'local_store.dart';
import 'memory_store.dart';
import 'open_store.dart';

/// State of the on-device store in this app session.
sealed class StoreState {
  const StoreState();
}

final class StoreOpening extends StoreState {
  const StoreOpening();
}

final class StoreReady extends StoreState {
  const StoreReady(this.store);
  final LocalStore store;
}

/// The store could not be opened. The app keeps working, but nothing is
/// kept after it closes; the reason is shown on the Data management page.
final class StoreUnavailable extends StoreState {
  const StoreUnavailable(this.reason);
  final String reason;
}

typedef LocalStoreOpener = Future<LocalStore> Function();

class StoreController extends ChangeNotifier {
  StoreController({
    LocalStoreOpener? opener,
    LocalStoreOpener? sessionOpener,
    this.timeout = const Duration(seconds: 15),
  }) : _opener = opener ?? openLocalStore,
       _sessionOpener = sessionOpener ?? openMemoryStore;

  final LocalStoreOpener _opener;
  final LocalStoreOpener _sessionOpener;

  /// How long opening persistent storage may take before the app gives up
  /// and continues with a session-only store.
  final Duration timeout;
  LocalStore? _session;
  StoreState _state = const StoreOpening();
  bool _disposed = false;

  StoreState get state => _state;

  /// The open store, or null while opening or when unavailable.
  LocalStore? get store => switch (_state) {
    StoreReady(:final store) => store,
    _ => null,
  };

  /// When persistent storage is unavailable: an in-memory store for this
  /// session, so features that need a database still work (and say that
  /// nothing will be kept). Null while opening or when storage is ready.
  LocalStore? get sessionStore => _session;

  Timer? _deadline;

  Future<void> open() async {
    StoreState next;
    final opening = _opener();
    // A cancellable deadline (not Future.timeout), so disposing the
    // controller while storage is still opening leaves no timer behind.
    final timedOut = Completer<void>();
    _deadline = Timer(timeout, timedOut.complete);
    try {
      final first = await Future.any<Object?>([opening, timedOut.future]);
      if (first is LocalStore) {
        next = StoreReady(first);
      } else {
        next = StoreUnavailable(
          'Local storage did not open within ${timeout.inSeconds} seconds. '
          'Another window of RAKIA may be holding it; close other windows '
          'and reload.',
        );
        // If it opens after all, release it: this session already moved on.
        unawaited(
          opening.then((store) => store.close(), onError: (Object _) {}),
        );
      }
    } on Object catch (e) {
      next = StoreUnavailable('$e');
    } finally {
      _deadline?.cancel();
      _deadline = null;
    }
    if (next is StoreUnavailable && !_disposed) {
      try {
        _session = await _sessionOpener();
      } on Object {
        _session = null;
      }
    }
    if (_disposed) {
      if (next case StoreReady(:final store)) await store.close();
      return;
    }
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _deadline?.cancel();
    if (_state case StoreReady(:final store)) store.close();
    _session?.close();
    super.dispose();
  }
}

class StoreScope extends InheritedNotifier<StoreController> {
  const StoreScope({
    super.key,
    required StoreController controller,
    required super.child,
  }) : super(notifier: controller);

  static StoreState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StoreScope>();
    assert(scope != null, 'StoreScope is missing from the widget tree');
    return scope!.notifier!.state;
  }
}
