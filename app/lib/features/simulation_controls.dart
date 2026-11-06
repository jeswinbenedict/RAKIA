import 'package:flutter/material.dart';

import '../core/analytics_core.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../mission/mission_controller.dart';
import '../storage/store_controller.dart';

/// Opt-in control for the simulation mission. Disabled, with the reason
/// shown, while the analytics core or the local store is not ready.
class StartSimulationAction extends StatelessWidget {
  const StartSimulationAction({super.key});

  @override
  Widget build(BuildContext context) {
    final core = AnalyticsCoreScope.of(context);
    final store = StoreScope.of(context);
    final mission = MissionScope.of(context);
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;

    final (VoidCallback? onPressed, String? note) = switch ((core, store)) {
      (AnalyticsCoreLoading(), _) => (null, 'Waiting for the analytics core.'),
      (AnalyticsCoreUnavailable(), _) => (
        null,
        'The analytics core is unavailable, so the simulation cannot run. '
            'See About RAKIA.',
      ),
      (AnalyticsCoreReady(), StoreOpening()) => (
        null,
        'Opening local storage.',
      ),
      _ when mission.busy => (null, mission.activity),
      (AnalyticsCoreReady(:final core), StoreUnavailable()) => (
        () => mission.startSimulation(core),
        'Local storage is unavailable, so the simulation will not be kept '
            'after RAKIA closes. Simulated values are never mixed with real '
            'measurements.',
      ),
      (AnalyticsCoreReady(:final core), StoreReady()) => (
        () => mission.startSimulation(core),
        null,
      ),
    };
    final error = mission.error;

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
        if (error != null) ...[
          const SizedBox(height: RakiaSpacing.sm),
          OperationError(message: error),
        ],
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

/// A failed save, load or removal, announced to assistive technology.
class OperationError extends StatelessWidget {
  const OperationError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(Icons.error_outline, size: 18, color: c.statusAct),
            ),
            const SizedBox(width: RakiaSpacing.sm),
            Expanded(
              child: Text(
                message,
                key: const Key('mission-error'),
                style: t.bodySmall?.copyWith(color: c.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
