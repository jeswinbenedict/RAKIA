import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/neumorphism.dart';
import '../../design/tokens.dart';
import 'astronaut.dart';

/// A window onto space with the astronaut in it: a deep-blue inset panel
/// with a still star field and a soft violet glow behind the character, as
/// in the reference's lighting. Decorative.
class MissionWindow extends StatelessWidget {
  const MissionWindow({
    super.key,
    required this.astronautWidth,
    this.child,
    this.padding = const EdgeInsets.all(RakiaSpacing.xl),
  });

  final double astronautWidth;

  /// Shown under the astronaut (headline and copy).
  final Widget? child;
  final EdgeInsetsGeometry padding;

  static const Color deep = Color(0xFF12162B);
  static const Color mid = Color(0xFF1E1F45);
  static const Color glow = Color(0xFF6B4DFF);

  @override
  Widget build(BuildContext context) => NeuSurface(
    style: NeuStyle.inset,
    depth: RakiaDepth.control,
    radius: RakiaRadii.lg,
    color: deep,
    child: CustomPaint(
      painter: _SpacePainter(),
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Astronaut(width: astronautWidth)),
            if (child != null) ...[
              const SizedBox(height: RakiaSpacing.lg),
              child!,
            ],
          ],
        ),
      ),
    ),
  );
}

class _SpacePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.35),
          radius: 0.9,
          colors: [
            MissionWindow.glow.withValues(alpha: 0.35),
            MissionWindow.mid,
            MissionWindow.deep,
          ],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
    // A fixed star field (the same on every frame and every visit).
    final random = math.Random(7);
    final star = Paint();
    for (var i = 0; i < 70; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final r = 0.4 + random.nextDouble() * 1.1;
      star.color = Colors.white.withValues(
        alpha: 0.25 + random.nextDouble() * 0.5,
      );
      canvas.drawCircle(Offset(x, y), r, star);
    }
  }

  @override
  bool shouldRepaint(_SpacePainter old) => false;
}
