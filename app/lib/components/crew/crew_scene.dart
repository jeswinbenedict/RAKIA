// The RAKIA crew: a group of 3D astronauts whose heads and eyes follow the
// pointer (web/crew/crew.js, three.js served from the app's own origin). On
// platforms without the web renderer, or without WebGL, a calm still panel
// takes its place. Decorative: hidden from screen readers.
import 'package:flutter/material.dart';

import 'crew_scene_stub.dart'
    if (dart.library.js_interop) 'crew_scene_web.dart'
    as impl;

/// The deep-space colours behind the crew, used by the fallback too.
abstract final class CrewColors {
  static const Color deep = Color(0xFF0C0A24);
  static const Color mid = Color(0xFF2A1960);
  static const Color glow = Color(0xFF5A2FA8);
}

class CrewScene extends StatelessWidget {
  const CrewScene({super.key, this.compact = false});

  /// Three astronauts instead of the full crew (the dashboard greeting).
  final bool compact;

  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: impl.buildCrewScene(context, compact: compact));
}

/// What shows while the scene loads, or instead of it.
class CrewBackdrop extends StatelessWidget {
  const CrewBackdrop({super.key, this.message, this.loading = false});

  final String? message;
  final bool loading;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(0, -0.2),
        radius: 0.9,
        colors: [CrewColors.glow, CrewColors.mid, CrewColors.deep],
        stops: [0, 0.45, 1],
      ),
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white70,
              ),
            ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message!,
                key: const Key('crew-message'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
