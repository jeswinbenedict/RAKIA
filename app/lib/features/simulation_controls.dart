import 'package:flutter/material.dart';

import '../core/analytics_core.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../mission/mission_controller.dart';

/// Opt-in control for the simulation mission. Disabled, with the reason
/// shown, while the analytics core is loading or unavailable.
class StartSimulationAction extends StatelessWidget {
  const StartSimulationAction({super.key});

  @override
  Widget build(BuildContext context) {
    final core = AnalyticsCoreScope.of(context);
    final mission = MissionScope.of(context);
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;

    final (VoidCallback? onPressed, String? note) = switch (core) {
      AnalyticsCoreReady(:final core) => (
        () => mission.startSimulation(core),
        null,
      ),
      AnalyticsCoreLoading() => (null, 'Waiting for the analytics core.'),
      AnalyticsCoreUnavailable() => (
        null,
        'The analytics core is unavailable, so the simulation cannot run. '
            'See About RAKIA.',
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: RakiaSpacing.md,
          runSpacing: RakiaSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              key: const Key('start-simulation'),
              onPressed: onPressed,
              icon: const Icon(Icons.science_outlined, size: 20),
              label: const Text('Start simulation mission'),
            ),
          ],
        ),
        const SizedBox(height: RakiaSpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            note ??
                'Runs a deterministic, clearly labelled scenario through '
                    'the real analytics so you can explore RAKIA. Simulated '
                    'values are never mixed with real measurements.',
            style: t.bodySmall?.copyWith(color: c.textSecondary),
          ),
        ),
      ],
    );
  }
}
