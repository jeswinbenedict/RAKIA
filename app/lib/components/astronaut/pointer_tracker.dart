import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Where the mouse (or the last touch) is, in global coordinates, for
/// widgets that react to it, such as the astronaut's eyes. Null when the
/// pointer has left the window. It only observes pointer events: it never
/// handles them, so every other gesture works as before.
class PointerTracker extends StatefulWidget {
  const PointerTracker({super.key, required this.child});

  final Widget child;

  /// The current pointer position, or null when unknown.
  static ValueListenable<Offset?> of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_PointerScope>();
    return scope?.position ?? _none;
  }

  static final ValueNotifier<Offset?> _none = ValueNotifier<Offset?>(null);

  @override
  State<PointerTracker> createState() => _PointerTrackerState();
}

class _PointerTrackerState extends State<PointerTracker> {
  final ValueNotifier<Offset?> _position = ValueNotifier<Offset?>(null);

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  void _set(Offset p) => _position.value = p;

  @override
  Widget build(BuildContext context) => _PointerScope(
    position: _position,
    child: MouseRegion(
      opaque: false,
      hitTestBehavior: HitTestBehavior.translucent,
      onHover: (e) => _set(e.position),
      onExit: (_) => _position.value = null,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) => _set(e.position),
        onPointerMove: (e) => _set(e.position),
        child: widget.child,
      ),
    ),
  );
}

class _PointerScope extends InheritedWidget {
  const _PointerScope({required this.position, required super.child});

  final ValueNotifier<Offset?> position;

  @override
  bool updateShouldNotify(_PointerScope old) => old.position != position;
}
