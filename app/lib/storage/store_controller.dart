import 'package:flutter/widgets.dart';

import 'local_store.dart';
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
  StoreController({LocalStoreOpener? opener})
    : _opener = opener ?? openLocalStore;

  final LocalStoreOpener _opener;
  StoreState _state = const StoreOpening();
  bool _disposed = false;

  StoreState get state => _state;

  /// The open store, or null while opening or when unavailable.
  LocalStore? get store => switch (_state) {
    StoreReady(:final store) => store,
    _ => null,
  };

  Future<void> open() async {
    StoreState next;
    try {
      next = StoreReady(await _opener());
    } on Object catch (e) {
      next = StoreUnavailable('$e');
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
    if (_state case StoreReady(:final store)) store.close();
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
