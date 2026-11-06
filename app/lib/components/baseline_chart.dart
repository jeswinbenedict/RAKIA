import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../analytics/metric_insight.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// Time series against the personal baseline: the expected range (median
/// +/- watch threshold x spread), the median, usable readings, rejected
/// readings as hollow markers, and the estimated onset of a sustained shift.
///
/// Simulated data is hatched and watermarked, as the design system requires.
/// Screen readers get a one-sentence summary instead of the drawing.
class BaselineChart extends StatelessWidget {
  const BaselineChart({
    super.key,
    required this.insight,
    required this.simulated,
    this.watchZ = 2.5,
    this.height = 220,
    this.compact = false,
    this.referenceDaysShown = 14,
  });

  final MetricInsight insight;
  final bool simulated;

  /// Half-width of the expected range, in baseline spreads.
  final double watchZ;
  final double height;

  /// Sparkline mode: no axes, labels or reference window.
  final bool compact;

  /// Trailing pre-flight days drawn before mission day 1 (full mode only).
  final int referenceDaysShown;

  String semanticSummary() {
    final m = insight.metric;
    final b = insight.baseline;
    final a = insight.assessment;
    final low = b.center - watchZ * b.spread;
    final high = b.center + watchZ * b.spread;
    final onset = insight.hasShift
        ? ' Estimated onset mission day '
              '${MetricInsight.dayOf(a.cusum.onsetIndex)}.'
        : '';
    final latest = a.latestValue.isFinite
        ? ' Latest ${m.formatWithUnit(a.latestValue)}.'
        : ' No usable latest reading.';
    return 'Chart of ${m.label.toLowerCase()} over ${insight.monitoring.length} '
        'mission days. Expected range ${m.format(low)} to '
        '${m.formatWithUnit(high)}.$latest$onset'
        '${simulated ? ' Simulated data.' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: semanticSummary(),
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _BaselinePainter(
              insight: insight,
              colors: c,
              statusColor: insight.status.color(c),
              watchZ: watchZ,
              compact: compact,
              simulated: simulated,
              referenceDaysShown: compact
                  ? 0
                  : constraints.maxWidth < 480
                  ? referenceDaysShown ~/ 2
                  : referenceDaysShown,
              labelStyle: RakiaType.metric(
                (t.labelSmall ?? const TextStyle()).copyWith(
                  color: c.textSecondary,
                  letterSpacing: 0,
                  fontSize: 11,
                ),
              ),
              watermarkStyle: (t.labelSmall ?? const TextStyle()).copyWith(
                color: c.simulated.withValues(alpha: 0.55),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BaselinePainter extends CustomPainter {
  _BaselinePainter({
    required this.insight,
    required this.colors,
    required this.statusColor,
    required this.watchZ,
    required this.compact,
    required this.simulated,
    required this.referenceDaysShown,
    required this.labelStyle,
    required this.watermarkStyle,
  });

  final MetricInsight insight;
  final RakiaColors colors;
  final Color statusColor;
  final double watchZ;
  final bool compact;
  final bool simulated;
  final int referenceDaysShown;
  final TextStyle labelStyle;
  final TextStyle watermarkStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final b = insight.baseline;
    final mon = insight.monitoring;
    final q = insight.monitoringQuality;
    final ref = insight.reference;
    final refShown = math.min(referenceDaysShown, ref.length);
    final refStart = ref.length - refShown;
    final n = refShown + mon.length;

    // Plot area, leaving room for axis labels in full mode.
    final left = compact ? 2.0 : 44.0;
    final right = compact ? 2.0 : 8.0;
    final top = compact ? 4.0 : 8.0;
    final bottom = compact ? 4.0 : 22.0;
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    if (plot.width <= 0 || plot.height <= 0 || n < 2) return;

    // Y range covers the expected range and every usable value.
    final lowBand = b.center - watchZ * b.spread;
    final highBand = b.center + watchZ * b.spread;
    var lo = lowBand;
    var hi = highBand;
    void include(double v) {
      if (v.isFinite) {
        lo = math.min(lo, v);
        hi = math.max(hi, v);
      }
    }

    for (var i = refStart; i < ref.length; i++) {
      include(ref[i]);
    }
    for (var i = 0; i < mon.length; i++) {
      if (q[i] >= 0.5) include(mon[i]);
    }
    final pad = (hi - lo) * 0.08;
    lo -= pad;
    hi += pad;

    double x(int k) => plot.left + plot.width * k / (n - 1);
    double y(double v) =>
        plot.bottom - plot.height * ((v.clamp(lo, hi) - lo) / (hi - lo));

    // Pre-flight region.
    if (refShown > 0) {
      canvas.drawRect(
        Rect.fromLTRB(plot.left, plot.top, x(refShown), plot.bottom),
        Paint()..color = colors.surface3.withValues(alpha: 0.6),
      );
    }

    // Expected range and median.
    canvas.drawRect(
      Rect.fromLTRB(plot.left, y(highBand), plot.right, y(lowBand)),
      Paint()..color = colors.brand.withValues(alpha: 0.14),
    );
    _dashedLine(
      canvas,
      Offset(plot.left, y(b.center)),
      Offset(plot.right, y(b.center)),
      Paint()
        ..color = colors.textSecondary.withValues(alpha: 0.7)
        ..strokeWidth = 1,
    );

    // Simulated hatch across the plot.
    if (simulated) {
      final hatch = Paint()
        ..color = colors.simulated.withValues(alpha: 0.06)
        ..strokeWidth = 1;
      canvas.save();
      canvas.clipRect(plot);
      for (var hx = plot.left - plot.height; hx < plot.right; hx += 10) {
        canvas.drawLine(
          Offset(hx, plot.bottom),
          Offset(hx + plot.height, plot.top),
          hatch,
        );
      }
      canvas.restore();
    }

    // Onset marker.
    if (insight.hasShift) {
      final ox = x(refShown + insight.assessment.cusum.onsetIndex);
      _dashedLine(
        canvas,
        Offset(ox, plot.top),
        Offset(ox, plot.bottom),
        Paint()
          ..color = statusColor
          ..strokeWidth = 1.5,
      );
      if (!compact) {
        final label =
            'Onset day ${MetricInsight.dayOf(insight.assessment.cusum.onsetIndex)}';
        final style = labelStyle.copyWith(color: statusColor);
        final w = _measure(label, style);
        final fitsRight = ox + 4 + w <= plot.right;
        _text(
          canvas,
          label,
          Offset(fitsRight ? ox + 4 : ox - 4 - w, plot.top),
          style,
        );
      }
    }

    // Series: reference (muted) then mission (emphasised), with gaps.
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = compact ? 1.75 : 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    if (refShown > 0) {
      final p = Path();
      for (var k = 0; k < refShown; k++) {
        final v = ref[refStart + k];
        k == 0 ? p.moveTo(x(k), y(v)) : p.lineTo(x(k), y(v));
      }
      canvas.drawPath(
        p,
        line..color = colors.textSecondary.withValues(alpha: 0.6),
      );
    }

    final path = Path();
    var open = false;
    final rejected = <Offset>[];
    for (var i = 0; i < mon.length; i++) {
      final v = mon[i];
      final px = x(refShown + i);
      if (q[i] >= 0.5 && v.isFinite) {
        open ? path.lineTo(px, y(v)) : path.moveTo(px, y(v));
        open = true;
      } else {
        open = false;
        rejected.add(Offset(px, v.isFinite ? y(v) : plot.bottom));
      }
    }
    canvas.drawPath(path, line..color = colors.brandText);

    final hollow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = colors.statusDataQuality;
    for (final r in rejected) {
      canvas.drawCircle(r, compact ? 2 : 3, hollow);
    }

    // Latest usable value.
    final a = insight.assessment;
    if (a.latestValue.isFinite) {
      final lp = Offset(x(refShown + a.latestIndex), y(a.latestValue));
      canvas.drawCircle(lp, compact ? 3 : 4, Paint()..color = statusColor);
      canvas.drawCircle(
        lp,
        compact ? 3 : 4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = colors.surface2,
      );
    }

    if (compact) return;

    // Axis labels: band edges and median, then the time axis.
    final m = insight.metric;
    for (final v in [highBand, b.center, lowBand]) {
      _text(
        canvas,
        m.format(v),
        Offset(0, y(v) - 7),
        labelStyle,
        maxWidth: left - 6,
        alignRight: true,
      );
    }
    final axisY = plot.bottom + 6;
    if (refShown > 0 &&
        x(refShown) - plot.left >= _measure('Pre-flight', labelStyle) + 8) {
      _text(canvas, 'Pre-flight', Offset(plot.left + 2, axisY), labelStyle);
    }
    _text(canvas, 'Day 1', Offset(x(refShown) + 2, axisY), labelStyle);
    _text(
      canvas,
      'Day ${mon.length}',
      Offset(plot.right - 40, axisY),
      labelStyle,
      maxWidth: 40,
      alignRight: true,
    );

    if (simulated) {
      _text(
        canvas,
        'SIMULATED',
        Offset(plot.right - 84, plot.bottom - 18),
        watermarkStyle,
        maxWidth: 80,
        alignRight: true,
      );
    }
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint p) {
    const dash = 4.0;
    const gap = 4.0;
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    for (var d = 0.0; d < total; d += dash + gap) {
      canvas.drawLine(a + dir * d, a + dir * math.min(d + dash, total), p);
    }
  }

  double _measure(String s, TextStyle style) => (TextPainter(
    text: TextSpan(text: s, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout()).width;

  void _text(
    Canvas canvas,
    String s,
    Offset at,
    TextStyle style, {
    double maxWidth = 160,
    bool alignRight = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    final dx = alignRight ? at.dx + maxWidth - tp.width : at.dx;
    tp.paint(canvas, Offset(dx, at.dy));
  }

  @override
  bool shouldRepaint(_BaselinePainter old) =>
      old.insight != insight ||
      old.colors != colors ||
      old.compact != compact ||
      old.simulated != simulated ||
      old.labelStyle != labelStyle;
}

/// Key for [BaselineChart]. Every mark is a shape as well as a colour.
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, this.onsetColor});

  /// Colour of the onset marker; null hides the onset entry.
  final Color? onsetColor;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    Widget item(Widget swatch, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 18, height: 12, child: Center(child: swatch)),
        const SizedBox(width: RakiaSpacing.xs + 2),
        Text(label, style: t.bodySmall),
      ],
    );
    return ExcludeSemantics(
      child: Wrap(
        spacing: RakiaSpacing.lg,
        runSpacing: RakiaSpacing.xs,
        children: [
          item(
            Container(
              width: 18,
              height: 10,
              color: c.brand.withValues(alpha: 0.22),
            ),
            'Expected range',
          ),
          item(
            Container(height: 1.5, width: 18, color: c.textSecondary),
            'Baseline median',
          ),
          item(
            Container(height: 2, width: 18, color: c.brandText),
            'Mission readings',
          ),
          item(
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c.statusDataQuality, width: 1.5),
              ),
            ),
            'Rejected or missing',
          ),
          if (onsetColor != null)
            item(
              Container(width: 1.5, height: 12, color: onsetColor),
              'Estimated onset',
            ),
        ],
      ),
    );
  }
}
