import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// A rounded panel with a coloured stripe on its leading edge. The stripe is
/// clipped by the rounded corners; a one-sided border with a border radius
/// draws stray arcs on the other corners in the web renderer.
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
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(RakiaRadii.sm),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        border: BorderDirectional(
          start: BorderSide(color: accent, width: accentWidth),
        ),
      ),
      child: Padding(padding: padding, child: child),
    ),
  );
}
