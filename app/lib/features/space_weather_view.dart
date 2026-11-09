import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../components/accent_box.dart';
import '../components/surface_card.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../environment/space_weather.dart';

Color _levelColor(RakiaColors c, int level) => switch (level) {
  0 => c.statusWithinBaseline,
  1 || 2 => c.statusWatch,
  _ => c.statusAct,
};

IconData _levelIcon(int level) => switch (level) {
  0 => Icons.check_circle_outline,
  1 || 2 => Icons.warning_amber_outlined,
  _ => Icons.report_outlined,
};

/// Whether the measurements are old enough to say so.
bool _isOld(SpaceWeatherSnapshot s, DateTime now) =>
    s.stale || now.difference(s.latest.time) > kSpaceWeatherFreshFor;

/// The live space-radiation environment, with what it means for the
/// astronaut, its source and its freshness.
class SpaceWeatherSection extends StatelessWidget {
  const SpaceWeatherSection({super.key});

  @override
  Widget build(BuildContext context) {
    final sw = SpaceWeatherScope.of(context);
    final t = Theme.of(context).textTheme;
    final c = RakiaColors.of(context);
    final snapshot = sw.snapshot;

    final Widget body;
    if (!sw.configured) {
      body = SurfaceCard(
        key: const Key('space-weather-unconfigured'),
        title: 'Space radiation environment',
        subtitle: 'Not connected',
        leadingIcon: Icons.cloud_off_outlined,
        child: Text(
          'This build of RAKIA is not connected to a RAKIA server, so live '
          'space-weather data is not shown. Nothing is estimated in its '
          'place.',
          style: t.bodyMedium,
        ),
      );
    } else if (snapshot == null) {
      body = SurfaceCard(
        key: const Key('space-weather-pending'),
        title: 'Space radiation environment',
        subtitle: 'NOAA Space Weather Prediction Center',
        leadingIcon: Icons.satellite_alt_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sw.loading) ...[
              const LinearProgressIndicator(
                semanticsLabel: 'Loading space weather',
              ),
              const SizedBox(height: RakiaSpacing.md),
              Text(
                'Connecting to the RAKIA server. After a quiet period the '
                'server can take up to a minute to wake.',
                style: t.bodyMedium,
              ),
            ] else ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  key: const Key('space-weather-error'),
                  sw.error ?? 'No data yet.',
                  style: t.bodyMedium,
                ),
              ),
              const SizedBox(height: RakiaSpacing.md),
              _RefreshButton(sw: sw),
            ],
          ],
        ),
      );
    } else {
      body = _Live(sw: sw, snapshot: snapshot);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        body,
        const SizedBox(height: RakiaSpacing.sm),
        Text(
          'Measured near Earth by a GOES satellite at geostationary orbit. '
          'It describes the environment you are in, not the dose you have '
          'received.',
          style: t.bodySmall?.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.sw});
  final SpaceWeatherController sw;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const Key('space-weather-refresh'),
    onPressed: sw.loading ? null : sw.refresh,
    icon: const Icon(Icons.refresh, size: 18),
    label: Text(sw.loading ? 'Refreshing' : 'Refresh'),
  );
}

class _Live extends StatelessWidget {
  const _Live({required this.sw, required this.snapshot});

  final SpaceWeatherController sw;
  final SpaceWeatherSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = RakiaColors.of(context);
    final s = snapshot;
    final now = sw.now;
    final level = StormLevel.all[s.stormLevel];
    final latest = s.latest;
    final above = latest.flux >= s.s1Threshold;
    final old = _isOld(s, now);

    final storm = AccentBox(
      key: const Key('storm-level'),
      color: c.surface2,
      accent: _levelColor(c, s.stormLevel),
      accentWidth: 4,

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _levelIcon(s.stormLevel),
                size: 20,
                color: _levelColor(c, s.stormLevel),
              ),
              const SizedBox(width: RakiaSpacing.sm),
              Expanded(child: Text(level.name, style: t.titleMedium)),
            ],
          ),
          const SizedBox(height: RakiaSpacing.xs),
          Text(level.noaaEffect, style: t.bodyMedium),
          const SizedBox(height: RakiaSpacing.sm),
          Text('What it means for you', style: t.labelLarge),
          Text(level.advice, style: t.bodyMedium),
        ],
      ),
    );

    final flux = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Protons above 10 MeV, last 24 hours', style: t.titleSmall),
        const SizedBox(height: RakiaSpacing.xs),
        Text(
          key: const Key('proton-flux'),
          '${formatFlux(latest.flux)} at '
          '${formatUtc(latest.time, now: now)}, '
          '${above ? 'at or above' : 'below'} the S1 storm threshold of '
          '${formatFlux(s.s1Threshold)}.',
          style: t.bodyMedium,
        ),
        const SizedBox(height: RakiaSpacing.md),
        FluxChart(snapshot: s, now: now),
      ],
    );

    final g = s.geomagneticLevel;
    final geo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Geomagnetic activity', style: t.titleSmall),
        const SizedBox(height: RakiaSpacing.xs),
        Text(
          key: const Key('kp-index'),
          'Kp ${s.kp.toStringAsFixed(1)} at '
          '${formatUtc(s.kpObservedAt, now: now)}: '
          '${g == 0 ? 'below storm level' : 'G$g geomagnetic storm'}. '
          'Geomagnetic storms mainly disturb communications and navigation; '
          'the radiation hazard to crew comes from solar protons.',
          style: t.bodyMedium,
        ),
      ],
    );

    return SurfaceCard(
      key: const Key('space-weather-live'),
      title: 'Space radiation environment',
      subtitle:
          '${s.sourceName}, ${s.satellite}. Updated '
          '${formatAge(s.retrievedAt, now: now)}.',
      leadingIcon: Icons.satellite_alt_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (old || sw.error != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                key: const Key('space-weather-old'),
                [
                  if (s.stale)
                    'The server could not reach NOAA on its last attempt.',
                  if (sw.error case final e?) 'Last refresh failed: $e',
                  'Showing data measured '
                      '${formatAge(s.latest.time, now: now)}.',
                ].join(' '),
                style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: RakiaSpacing.md),
          ],
          storm,
          const SizedBox(height: RakiaSpacing.lg),
          flux,
          const SizedBox(height: RakiaSpacing.lg),
          geo,
          const SizedBox(height: RakiaSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: _RefreshButton(sw: sw),
          ),
        ],
      ),
    );
  }
}

/// Proton flux on a logarithmic scale with the S1 threshold. Screen readers
/// get a one-sentence summary instead of the drawing.
class FluxChart extends StatelessWidget {
  const FluxChart({
    super.key,
    required this.snapshot,
    required this.now,
    this.height = 160,
  });

  final SpaceWeatherSnapshot snapshot;
  final DateTime now;
  final double height;

  String semanticSummary() {
    final fluxes = snapshot.points.map((p) => p.flux);
    return 'Chart of proton flux above 10 MeV from '
        '${formatUtc(snapshot.points.first.time, now: now)} to '
        '${formatUtc(snapshot.latest.time, now: now)}, between '
        '${formatFlux(fluxes.reduce(math.min))} and '
        '${formatFlux(fluxes.reduce(math.max))}. S1 storm threshold '
        '${formatFlux(snapshot.s1Threshold)}.';
  }

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: semanticSummary(),
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _FluxPainter(
            snapshot: snapshot,
            now: now,
            colors: c,
            labelStyle: RakiaType.metric(
              (t.labelSmall ?? const TextStyle()).copyWith(
                color: c.textSecondary,
                letterSpacing: 0,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FluxPainter extends CustomPainter {
  _FluxPainter({
    required this.snapshot,
    required this.now,
    required this.colors,
    required this.labelStyle,
  });

  final SpaceWeatherSnapshot snapshot;
  final DateTime now;
  final RakiaColors colors;
  final TextStyle labelStyle;

  static double _log(double v) => math.log(math.max(v, 1e-3)) / math.ln10;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = snapshot.points;
    final maxFlux = pts.map((p) => p.flux).reduce(math.max);
    // Decades from 0.01 pfu to at least 1,000 pfu, so the S1 line and quiet
    // levels are both visible.
    const lo = -2.0;
    final hi = math.max(3.0, _log(maxFlux).ceilToDouble() + 1);
    const left = 44.0;
    const bottom = 18.0;
    final plot = Rect.fromLTRB(left, 4, size.width - 4, size.height - bottom);
    final t0 = pts.first.time.millisecondsSinceEpoch.toDouble();
    final t1 = math.max(
      pts.last.time.millisecondsSinceEpoch.toDouble(),
      t0 + 1,
    );
    double x(DateTime t) =>
        plot.left + (t.millisecondsSinceEpoch - t0) / (t1 - t0) * plot.width;
    double y(double v) =>
        plot.bottom - (_log(v) - lo) / (hi - lo) * plot.height;

    final grid = Paint()
      ..color = colors.borderSubtle
      ..strokeWidth = 1;
    for (var d = lo; d <= hi; d++) {
      final py = y(math.pow(10, d).toDouble());
      canvas.drawLine(Offset(plot.left, py), Offset(plot.right, py), grid);
      final v = math.pow(10, d).toDouble();
      _text(
        canvas,
        v >= 1000
            ? '${(v / 1000).round()}k'
            : v >= 1
            ? v.round().toString()
            : v.toString(),
        Offset(0, py - 7),
        maxWidth: left - 6,
        alignRight: true,
      );
    }

    // S1 threshold.
    final ty = y(snapshot.s1Threshold);
    final dash = Paint()
      ..color = colors.statusWatch
      ..strokeWidth = 1.5;
    for (var dx = plot.left; dx < plot.right; dx += 9) {
      canvas.drawLine(
        Offset(dx, ty),
        Offset(math.min(dx + 5, plot.right), ty),
        dash,
      );
    }
    _text(
      canvas,
      'S1',
      Offset(plot.right - 24, ty - 15),
      maxWidth: 24,
      alignRight: true,
      color: colors.statusWatch,
    );

    final path = Path();
    for (var k = 0; k < pts.length; k++) {
      final o = Offset(x(pts[k].time), y(pts[k].flux));
      k == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.brandText
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    final last = Offset(x(pts.last.time), y(pts.last.flux));
    canvas.drawCircle(last, 3.5, Paint()..color = colors.brandText);

    final axisY = plot.bottom + 3;
    _text(
      canvas,
      formatUtc(pts.first.time, now: now),
      Offset(plot.left, axisY),
      maxWidth: 140,
    );
    _text(
      canvas,
      formatUtc(pts.last.time, now: now),
      Offset(plot.right - 140, axisY),
      maxWidth: 140,
      alignRight: true,
    );
  }

  void _text(
    Canvas canvas,
    String s,
    Offset at, {
    double maxWidth = 120,
    bool alignRight = false,
    Color? color,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: color == null ? labelStyle : labelStyle.copyWith(color: color),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    final dx = alignRight ? at.dx + maxWidth - tp.width : at.dx;
    tp.paint(canvas, Offset(dx, at.dy));
  }

  @override
  bool shouldRepaint(_FluxPainter old) =>
      old.snapshot != snapshot ||
      old.colors != colors ||
      old.labelStyle != labelStyle;
}

/// Space weather on the Mission overview: the storm level in one line,
/// with a link to the full view.
class SpaceWeatherSummaryCard extends StatelessWidget {
  const SpaceWeatherSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final sw = SpaceWeatherScope.of(context);
    final t = Theme.of(context).textTheme;
    final c = RakiaColors.of(context);
    final s = sw.snapshot;
    final String text;
    if (!sw.configured) {
      text = 'Not connected to a RAKIA server; no live data.';
    } else if (s == null) {
      text = sw.loading
          ? 'Connecting to the RAKIA server.'
          : (sw.error ?? 'No data yet.');
    } else {
      final level = StormLevel.all[s.stormLevel];
      text =
          '${level.name}. Protons above 10 MeV ${formatFlux(s.latest.flux)}, '
          'Kp ${s.kp.toStringAsFixed(1)}. Updated '
          '${formatAge(s.retrievedAt, now: sw.now)}'
          '${_isOld(s, sw.now) ? '; measurements are not current' : ''}.';
    }
    return SurfaceCard(
      key: const Key('space-weather-summary'),
      title: 'Space weather',
      subtitle: 'Live from NOAA, near Earth',
      leadingIcon: s == null
          ? Icons.satellite_alt_outlined
          : _levelIcon(s.stormLevel),
      trailing: TextButton(
        onPressed: () => context.go('/environment'),
        child: const Text('Open radiation'),
      ),
      child: Text(
        text,
        style: t.bodyMedium?.copyWith(
          color: s == null ? c.textSecondary : null,
        ),
      ),
    );
  }
}

/// In the Action center while a radiation storm is in progress (S1 or
/// above): the level and what to do, linked to the full view.
class SpaceWeatherAlert extends StatelessWidget {
  const SpaceWeatherAlert({
    super.key,
    required this.snapshot,
    required this.now,
  });

  final SpaceWeatherSnapshot snapshot;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final level = StormLevel.all[snapshot.stormLevel];
    return SurfaceCard(
      key: const Key('space-weather-alert'),
      title: 'Solar radiation storm: ${level.name}',
      subtitle:
          'NOAA, observed '
          '${formatUtc(snapshot.stormObservedAt, now: now)}',
      leadingIcon: _levelIcon(snapshot.stormLevel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(level.noaaEffect, style: t.bodyMedium),
          const SizedBox(height: RakiaSpacing.sm),
          Text('What it means for you', style: t.labelLarge),
          Text(level.advice, style: t.bodyMedium),
          const SizedBox(height: RakiaSpacing.md),
          OutlinedButton.icon(
            onPressed: () => context.go('/environment'),
            icon: const Icon(Icons.blur_on_outlined, size: 18),
            label: const Text('Open Radiation & environment'),
          ),
        ],
      ),
    );
  }
}
