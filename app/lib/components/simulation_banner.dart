import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../mission/mission_controller.dart';

/// Persistent strip shown above every page while the simulation mission is
/// running, so simulated values can never be mistaken for real ones.
class SimulationBanner extends StatelessWidget {
  const SimulationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = MissionScope.of(context);
    final snapshot = controller.snapshot;
    if (snapshot == null) return const SizedBox.shrink();
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    final compact =
        RakiaBreakpoints.of(MediaQuery.sizeOf(context).width) ==
        RakiaWindowClass.compact;

    final message = Text(
      compact
          ? 'Simulation mission. All values are simulated.'
          : '${snapshot.mission.name}. Every value in RAKIA is simulated '
                'for demonstration and is not a real measurement.',
      style: t.labelMedium?.copyWith(color: c.textPrimary),
    );

    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        key: const Key('simulation-banner'),
        decoration: BoxDecoration(
          color: c.surface2,
          border: Border(
            bottom: BorderSide(color: c.simulated.withValues(alpha: 0.5)),
          ),
        ),
        child: CustomPaint(
          painter: _StripePainter(c.simulated.withValues(alpha: 0.10)),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? RakiaSpacing.lg : RakiaSpacing.xl,
              vertical: RakiaSpacing.xs,
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(Icons.science_outlined, color: c.simulated),
                ),
                const SizedBox(width: RakiaSpacing.md),
                Expanded(child: message),
                const SizedBox(width: RakiaSpacing.md),
                TextButton(
                  onPressed: controller.busy ? null : controller.endSimulation,
                  child: Text(compact ? 'End' : 'End simulation'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  _StripePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 6;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var x = -size.height; x < size.width; x += 18) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StripePainter old) => old.color != color;
}
