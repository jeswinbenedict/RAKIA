import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// Assessment levels, mirroring `rakia_level` in librakia
/// (core/include/rakia/rakia.h).
enum HealthStatus {
  insufficientData('Not enough data'),
  dataQuality('Check data quality'),
  withinBaseline('Within baseline'),
  watch('Watch'),
  act('Act now');

  const HealthStatus(this.label);

  /// The word shown next to the glyph. Status is never colour-only.
  final String label;

  Color color(RakiaColors c) => switch (this) {
    HealthStatus.insufficientData => c.statusInsufficient,
    HealthStatus.dataQuality => c.statusDataQuality,
    HealthStatus.withinBaseline => c.statusWithinBaseline,
    HealthStatus.watch => c.statusWatch,
    HealthStatus.act => c.statusAct,
  };
}

/// Distinct shape per status so it survives colour-blindness and greyscale:
/// dashed circle, square, filled circle, triangle, diamond.
class StatusGlyph extends StatelessWidget {
  const StatusGlyph({super.key, required this.status, this.size = 12});

  final HealthStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _GlyphPainter(status, status.color(RakiaColors.of(context))),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.status, this.color);

  final HealthStatus status;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    switch (status) {
      case HealthStatus.withinBaseline:
        canvas.drawCircle(center, w / 2, fill);
      case HealthStatus.watch:
        canvas.drawPath(
          Path()
            ..moveTo(w / 2, 0)
            ..lineTo(w, h)
            ..lineTo(0, h)
            ..close(),
          fill,
        );
      case HealthStatus.act:
        canvas.drawPath(
          Path()
            ..moveTo(w / 2, 0)
            ..lineTo(w, h / 2)
            ..lineTo(w / 2, h)
            ..lineTo(0, h / 2)
            ..close(),
          fill,
        );
      case HealthStatus.dataQuality:
        canvas.drawRect(
          Rect.fromLTWH(w * 0.1, h * 0.1, w * 0.8, h * 0.8),
          fill,
        );
      case HealthStatus.insufficientData:
        final stroke = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, w / 8);
        const segments = 8;
        final rect = Rect.fromCircle(
          center: center,
          radius: w / 2 - stroke.strokeWidth / 2,
        );
        for (var i = 0; i < segments; i++) {
          canvas.drawArc(
            rect,
            i * 2 * math.pi / segments,
            math.pi / segments,
            false,
            stroke,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.status != status || old.color != color;
}

/// Compact pill showing glyph + word. Reads as `Status: <word>` to screen
/// readers.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final HealthStatus status;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final color = status.color(c);
    return Semantics(
      container: true,
      label: 'Status: ${status.label}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: RakiaSpacing.md,
          vertical: RakiaSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: c.surface3,
          borderRadius: BorderRadius.circular(RakiaRadii.pill),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusGlyph(status: status),
            const SizedBox(width: RakiaSpacing.sm),
            // Flexible so very large text sizes wrap instead of overflowing.
            Flexible(
              child: Text(
                status.label,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
