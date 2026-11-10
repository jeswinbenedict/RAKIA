// Raised and inset soft surfaces: the two building blocks of the
// neumorphic system. A raised element casts its shadow down and to the
// right and catches light up and to the left; an inset (pressed) element
// has the same pair on the inside.
import 'package:flutter/material.dart';

import 'colors.dart';
import 'tokens.dart';

/// Shadows of a raised element of [depth] (see [RakiaDepth]).
List<BoxShadow> raisedShadows(RakiaColors c, double depth) => [
  BoxShadow(
    color: c.shadow.withValues(alpha: 0.55),
    offset: Offset(depth, depth),
    blurRadius: RakiaDepth.blur(depth),
  ),
  BoxShadow(
    color: c.highlight.withValues(alpha: 0.9),
    offset: Offset(-depth, -depth),
    blurRadius: RakiaDepth.blur(depth),
  ),
];

enum NeuStyle {
  /// Rises out of the surface: cards, buttons, chips.
  raised,

  /// Sunk into the surface: inputs, tracks, selected navigation, wells.
  inset,

  /// Level with the surface: no depth.
  flat,
}

/// A soft surface in [style], in the background colour (or [color]).
/// [AnimatedNeuSurface] animates between styles for pressed states.
class NeuSurface extends StatelessWidget {
  const NeuSurface({
    super.key,
    required this.child,
    this.style = NeuStyle.raised,
    this.depth = RakiaDepth.panel,
    this.radius = RakiaRadii.md,
    this.color,
    this.padding,
    this.border,
  });

  final Widget child;
  final NeuStyle style;
  final double depth;
  final double radius;

  /// Defaults to the surface (raised, flat) or the well (inset).
  final Color? color;
  final EdgeInsetsGeometry? padding;

  /// Only for states that must be seen without relying on shadow: focus.
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final r = BorderRadius.circular(radius);
    final fill = color ?? (style == NeuStyle.inset ? c.surface3 : c.surface2);
    Widget content = padding == null
        ? child
        : Padding(padding: padding!, child: child);
    if (style == NeuStyle.inset) {
      content = CustomPaint(
        foregroundPainter: _InsetPainter(
          radius: radius,
          depth: depth,
          shadow: c.shadow,
          highlight: c.highlight,
        ),
        child: content,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: r,
        border: border,
        boxShadow: style == NeuStyle.raised ? raisedShadows(c, depth) : null,
      ),
      child: ClipRRect(borderRadius: r, child: content),
    );
  }
}

/// [NeuSurface] that eases between raised and inset: the press feedback of
/// buttons and selectable items. No motion when the platform asks for none.
class AnimatedNeuSurface extends StatelessWidget {
  const AnimatedNeuSurface({
    super.key,
    required this.child,
    required this.pressed,
    this.depth = RakiaDepth.control,
    this.radius = RakiaRadii.pill,
    this.padding,
    this.border,
  });

  final Widget child;
  final bool pressed;
  final double depth;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    return AnimatedContainer(
      duration: RakiaMotion.of(context, RakiaMotion.stateChange),
      curve: RakiaMotion.easeOut,
      decoration: BoxDecoration(
        color: pressed ? c.surface3 : c.surface2,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: pressed ? null : raisedShadows(c, depth),
      ),
      child: CustomPaint(
        foregroundPainter: pressed
            ? _InsetPainter(
                radius: radius,
                depth: depth,
                shadow: c.shadow,
                highlight: c.highlight,
              )
            : null,
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    );
  }
}

/// Inner shadows: the dark one along the top and left edges, the light one
/// along the bottom and right, clipped to the rounded rectangle.
class _InsetPainter extends CustomPainter {
  _InsetPainter({
    required this.radius,
    required this.depth,
    required this.shadow,
    required this.highlight,
  });

  final double radius;
  final double depth;
  final Color shadow;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = Radius.circular(radius.clamp(0, size.shortestSide / 2));
    final rrect = RRect.fromRectAndRadius(rect, r);
    canvas.save();
    canvas.clipRRect(rrect);
    final blur = RakiaDepth.blur(depth);
    void inner(Color color, Offset offset) {
      // A frame around the shape, offset and blurred, seen through it.
      final frame = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect.inflate(blur * 3))
        ..addRRect(rrect.shift(offset));
      canvas.drawPath(
        frame,
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2),
      );
    }

    inner(shadow.withValues(alpha: 0.6), Offset(depth / 2, depth / 2));
    inner(highlight.withValues(alpha: 0.7), Offset(-depth / 2, -depth / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InsetPainter old) =>
      old.radius != radius ||
      old.depth != depth ||
      old.shadow != shadow ||
      old.highlight != highlight;
}
