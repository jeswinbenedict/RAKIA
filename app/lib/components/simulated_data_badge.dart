import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// Unmistakable marker for simulated data. Must accompany every view,
/// chart and export that contains simulated measurements.
class SimulatedDataBadge extends StatelessWidget {
  const SimulatedDataBadge({super.key});

  static const String text = 'SIMULATED DATA';

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    return Semantics(
      container: true,
      label: 'Simulated data. These values are not real measurements.',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(RakiaRadii.sm),
          border: Border.all(color: c.simulated, width: 1.5),
        ),
        child: CustomPaint(
          painter: _HatchPainter(c.simulated.withValues(alpha: 0.18)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: RakiaSpacing.sm,
              vertical: RakiaSpacing.xs,
            ),
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: c.simulated, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class _HatchPainter extends CustomPainter {
  _HatchPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (double x = -size.height; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HatchPainter old) => old.color != color;
}
