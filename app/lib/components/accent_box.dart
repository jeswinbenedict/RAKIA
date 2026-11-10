import 'package:flutter/material.dart';

import '../design/neumorphism.dart';
import '../design/tokens.dart';

/// An inset well with a coloured stripe on its leading edge, for notes and
/// callouts. [color] is kept for callers that tint the well.
class AccentBox extends StatelessWidget {
  const AccentBox({
    super.key,
    required this.color,
    required this.accent,
    required this.child,
    this.accentWidth = 3,
    this.padding = const EdgeInsets.all(RakiaSpacing.md),
  });

  final Color color;
  final Color accent;
  final double accentWidth;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => NeuSurface(
    style: NeuStyle.inset,
    depth: RakiaDepth.control,
    radius: RakiaRadii.sm,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(color: accent, width: accentWidth),
        ),
      ),
      child: Padding(padding: padding, child: child),
    ),
  );
}
