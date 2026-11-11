// RAKIA's astronaut: an original character drawn in code, in a soft
// clay-like style inspired by the CC BY 4.0 Spline scene "100 followers" by
// heyvlad. The head turns slightly and the eyes follow the mouse or the
// last touch, smoothly; the character blinks now and then. It is decorative
// and hidden from screen readers.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'pointer_tracker.dart';

/// Where to look, as a vector of length at most 1, for a pointer at
/// [pointer] and a head centred at [center] of size [size]. Far pointers
/// give a full glance; near ones a gentle one, so the eyes never snap.
Offset gazeToward(Offset pointer, Offset center, double size) {
  final d = pointer - center;
  final dist = d.distance;
  if (dist < 1e-6 || size <= 0) return Offset.zero;
  final m = (dist / (size * 1.5)).clamp(0.0, 1.0);
  final k = m * (2 - m); // ease out
  final g = d / dist * k;
  // Eyes travel less vertically than horizontally, as real ones do.
  return Offset(g.dx, g.dy * 0.8);
}

/// Moves [current] towards [target] by an exponential step for [dt]
/// seconds: frame-rate independent smoothing.
Offset smoothToward(
  Offset current,
  Offset target,
  double dt, {
  double rate = 10,
}) {
  final a = 1 - math.exp(-rate * dt);
  return current + (target - current) * a;
}

class Astronaut extends StatefulWidget {
  const Astronaut({
    super.key,
    this.width = 220,
    this.skin = const Color(0xFFE5B48E),
  });

  /// Width in logical pixels; the height is 1.2 times this.
  final double width;

  /// The face's clay tone.
  final Color skin;

  @override
  State<Astronaut> createState() => AstronautState();
}

class AstronautState extends State<Astronaut>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  ValueListenable<Offset?>? _pointer;
  Offset _gaze = Offset.zero;
  Offset _target = Offset.zero;
  Duration? _last;
  double _blink = 0; // 0 open, 1 closed
  bool _blinking = false;
  Duration? _blinkStart;
  Timer? _blinkTimer;
  final math.Random _random = math.Random();

  static const Duration _blinkLength = Duration(milliseconds: 160);

  /// The current gaze, for tests.
  @visibleForTesting
  Offset get gaze => _gaze;

  bool get _reducedMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = PointerTracker.of(context);
    if (!identical(p, _pointer)) {
      _pointer?.removeListener(_onPointer);
      _pointer = p..addListener(_onPointer);
    }
    _scheduleBlink();
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    if (_reducedMotion) return;
    _blinkTimer = Timer(
      Duration(milliseconds: 2500 + _random.nextInt(3500)),
      () {
        if (!mounted) return;
        _blinkStart = null;
        _blinking = true;
        _wake();
        _scheduleBlink();
      },
    );
  }

  void _onPointer() {
    final box = context.findRenderObject() as RenderBox?;
    final p = _pointer?.value;
    if (box == null || !box.hasSize || !box.attached) return;
    if (p == null) {
      _target = Offset.zero; // look ahead when the pointer leaves
    } else {
      final w = widget.width;
      final head = box.localToGlobal(Offset(w * 0.5, w * 0.42));
      _target = gazeToward(p, head, w);
    }
    if (_reducedMotion) {
      setState(() => _gaze = _target);
      return;
    }
    _wake();
  }

  void _wake() {
    if (!_ticker.isActive) {
      _last = null;
      _ticker.start();
    }
  }

  void _tick(Duration now) {
    final dt = _last == null ? 1 / 60 : (now - _last!).inMicroseconds / 1e6;
    _last = now;
    var next = smoothToward(_gaze, _target, dt.clamp(0, 0.1));
    if ((next - _target).distance < 0.002) next = _target;
    var blink = 0.0;
    if (_blinking) {
      _blinkStart ??= now;
      final t =
          (now - _blinkStart!).inMicroseconds / _blinkLength.inMicroseconds;
      if (t >= 1) {
        _blinking = false;
        _blinkStart = null;
      } else {
        blink = t < 0.5 ? t * 2 : (1 - t) * 2;
      }
    }
    setState(() {
      _gaze = next;
      _blink = blink;
    });
    if (next == _target && !_blinking) _ticker.stop();
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _pointer?.removeListener(_onPointer);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: CustomPaint(
        size: Size(widget.width, widget.width * 1.2),
        painter: AstronautPainter(
          gaze: _gaze,
          blink: _blink,
          skin: widget.skin,
        ),
      ),
    ),
  );
}

class AstronautPainter extends CustomPainter {
  AstronautPainter({
    required this.gaze,
    required this.blink,
    required this.skin,
  });

  final Offset gaze;
  final double blink;
  final Color skin;

  static const Color suitLight = Color(0xFFF6F8FB);
  static const Color suitShade = Color(0xFFC3CCD8);
  static const Color seam = Color(0xFFAEB8C6);
  static const Color ringBlue = Color(0xFF2F5D9E);
  static const Color stripeRed = Color(0xFFC62B2B);
  static const Color patchNavy = Color(0xFF1B2A5C);
  static const Color orbitOrange = Color(0xFFF08A24);
  static const Color pupil = Color(0xFF181B22);
  static const Color brow = Color(0xFF2A2320);
  static const Color rim = Color(0xFF7A5CFF);

  Color _shade(Color c, double f) => Color.lerp(c, const Color(0xFF000000), f)!;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 100;
    Offset p(double x, double y) => Offset(x * u, y * u);

    // ---- suit body
    final torso = RRect.fromRectAndCorners(
      Rect.fromLTRB(16 * u, 70 * u, 84 * u, 120 * u),
      topLeft: Radius.circular(24 * u),
      topRight: Radius.circular(24 * u),
    );
    canvas.drawRRect(
      torso,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.6),
          radius: 1.1,
          colors: [suitLight, suitShade],
        ).createShader(torso.outerRect),
    );
    // Shoulder joints and the commander's red arm stripe.
    for (final x in [21.0, 79.0]) {
      canvas.drawCircle(
        p(x, 86),
        10 * u,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.3, -0.4),
            colors: [suitLight, suitShade],
          ).createShader(Rect.fromCircle(center: p(x, 86), radius: 10 * u)),
      );
      canvas.drawArc(
        Rect.fromCircle(center: p(x, 86), radius: 10 * u),
        math.pi * 0.15,
        math.pi * 0.7,
        false,
        Paint()
          ..color = seam
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7 * u,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(74 * u, 95 * u, 86 * u, 98 * u),
        Radius.circular(u),
      ),
      Paint()..color = stripeRed,
    );
    // Seams down the torso.
    final seamPaint = Paint()
      ..color = seam
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6 * u;
    canvas.drawLine(p(50, 100), p(50, 120), seamPaint);
    canvas.drawArc(
      Rect.fromLTRB(30 * u, 96 * u, 70 * u, 112 * u),
      0,
      math.pi,
      false,
      seamPaint,
    );

    // Chest control panel.
    final panel = RRect.fromRectAndRadius(
      Rect.fromLTRB(39 * u, 84 * u, 61 * u, 97 * u),
      Radius.circular(2 * u),
    );
    canvas.drawRRect(panel, Paint()..color = const Color(0xFF8B95A7));
    canvas.drawRRect(
      panel.deflate(1.2 * u),
      Paint()..color = const Color(0xFF6C7689),
    );
    for (final (i, c) in [
      const Color(0xFFE5484D),
      const Color(0xFFF5B83D),
      const Color(0xFF46C47E),
    ].indexed) {
      canvas.drawCircle(p(44 + i * 4.5, 88.5), 1.3 * u, Paint()..color = c);
    }
    final dial = Paint()
      ..color = const Color(0xFFDDE3EC)
      ..strokeWidth = 0.8 * u
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(p(42.5, 93), p(57.5, 93), dial);

    // Mission patch: RAKIA's own (not a NASA insignia).
    final patch = p(27, 92);
    canvas.drawCircle(patch, 6.4 * u, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawCircle(patch, 5.6 * u, Paint()..color = patchNavy);
    canvas.save();
    canvas.translate(patch.dx, patch.dy);
    canvas.rotate(-0.45);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 10 * u, height: 4 * u),
      Paint()
        ..color = orbitOrange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 * u,
    );
    canvas.restore();
    canvas.drawCircle(patch, 1.6 * u, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawCircle(
      patch + Offset(2.6 * u, -2.6 * u),
      0.6 * u,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    // Name tag.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(65 * u, 89 * u, 79 * u, 93.5 * u),
        Radius.circular(u),
      ),
      Paint()..color = patchNavy,
    );
    final tag = TextPainter(
      text: TextSpan(
        text: 'RAKIA',
        style: TextStyle(
          color: const Color(0xFFFFFFFF),
          fontSize: 2.9 * u,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3 * u,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tag.paint(canvas, p(72, 91.25) - Offset(tag.width / 2, tag.height / 2));

    // ---- helmet back plate
    final helmetC = p(50, 42);
    final helmetR = 35 * u;
    canvas.drawCircle(
      helmetC,
      helmetR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.2),
          colors: [Color(0xFF2A3350), Color(0xFF151A2C)],
        ).createShader(Rect.fromCircle(center: helmetC, radius: helmetR)),
    );

    // ---- head: turns a little towards the gaze
    final g = gaze;
    final head = p(50 + g.dx * 3.2, 45 + g.dy * 2.4);
    final headR = 24 * u;
    final headRect = Rect.fromCircle(center: head, radius: headR);
    canvas.drawCircle(
      head,
      headR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 1.0,
          colors: [
            Color.lerp(skin, const Color(0xFFFFFFFF), 0.25)!,
            skin,
            _shade(skin, 0.28),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(headRect),
    );
    // Violet rim light from below right, as in the reference's lighting.
    canvas.drawCircle(
      head,
      headR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.75, 0.85),
          radius: 0.7,
          colors: [rim.withValues(alpha: 0.45), rim.withValues(alpha: 0)],
        ).createShader(headRect),
    );

    // Eyes.
    final features = head + Offset(g.dx * 2.2 * u, g.dy * 1.6 * u);
    final eyeRx = 6.4 * u;
    final eyeRy = 7.4 * u;
    for (final side in [-1.0, 1.0]) {
      final ec = features + Offset(side * 8.6 * u, -2 * u);
      final eye = Rect.fromCenter(
        center: ec,
        width: eyeRx * 2,
        height: eyeRy * 2,
      );
      canvas.drawOval(
        eye.inflate(0.5 * u),
        Paint()..color = _shade(skin, 0.35).withValues(alpha: 0.35),
      );
      canvas.drawOval(
        eye,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.2, -0.3),
            colors: [Color(0xFFFFFFFF), Color(0xFFDCE2EC)],
          ).createShader(eye),
      );
      canvas.save();
      canvas.clipPath(Path()..addOval(eye));
      final pupilR = 3.5 * u;
      final travel = Offset(
        (eyeRx - pupilR - 0.6 * u) * g.dx,
        (eyeRy - pupilR - 0.8 * u) * g.dy,
      );
      final pc = ec + travel;
      canvas.drawCircle(pc, pupilR, Paint()..color = pupil);
      canvas.drawCircle(
        pc + Offset(-1.2 * u, -1.3 * u),
        1.0 * u,
        Paint()..color = const Color(0xFFFFFFFF),
      );
      if (blink > 0) {
        canvas.drawRect(
          Rect.fromLTRB(
            eye.left,
            eye.top,
            eye.right,
            eye.top + eye.height * blink,
          ),
          Paint()..color = skin,
        );
      }
      canvas.restore();
      // Brows: thick, rounded, lifting when the gaze goes up.
      final browY = ec.dy - eyeRy - 3.2 * u - math.max(0, -g.dy) * 1.4 * u;
      canvas.save();
      canvas.translate(ec.dx, browY);
      canvas.rotate(side * -0.12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 11 * u, height: 2.8 * u),
          Radius.circular(1.4 * u),
        ),
        Paint()..color = brow,
      );
      canvas.restore();
    }
    // Nose and a small smile.
    final nose = features + Offset(g.dx * 1.2 * u, 6.2 * u);
    canvas.drawOval(
      Rect.fromCenter(center: nose, width: 4.6 * u, height: 3.6 * u),
      Paint()..color = _shade(skin, 0.12),
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: features + Offset(0, 11.5 * u),
        width: 8 * u,
        height: 4 * u,
      ),
      0.15 * math.pi,
      0.7 * math.pi,
      false,
      Paint()
        ..color = _shade(skin, 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 * u
        ..strokeCap = StrokeCap.round,
    );

    // ---- helmet glass: tint, rim and visor reflection
    final glass = Rect.fromCircle(center: helmetC, radius: helmetR);
    canvas.drawCircle(
      helmetC,
      helmetR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.5),
          radius: 1.1,
          colors: [
            const Color(0xFFB9D4FF).withValues(alpha: 0.05),
            const Color(0xFF6E8FD8).withValues(alpha: 0.16),
          ],
        ).createShader(glass),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(glass));
    canvas.drawArc(
      glass.deflate(4 * u),
      math.pi * 1.08,
      math.pi * 0.42,
      false,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2 * u
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      p(72, 24),
      1.8 * u,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.7),
    );
    canvas.restore();
    canvas.drawCircle(
      helmetC,
      helmetR,
      Paint()
        ..color = const Color(0xFFE9EEF5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8 * u,
    );

    // ---- neck ring the helmet sits in
    final ring = Rect.fromCenter(
      center: p(50, 74),
      width: 52 * u,
      height: 11 * u,
    );
    canvas.drawOval(
      ring,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5C86C7), ringBlue, Color(0xFF1F3F72)],
        ).createShader(ring),
    );
    canvas.drawOval(
      ring.deflate(2.2 * u),
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7 * u,
    );
  }

  @override
  bool shouldRepaint(AstronautPainter old) =>
      old.gaze != gaze || old.blink != blink || old.skin != skin;
}
