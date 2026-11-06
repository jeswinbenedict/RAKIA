import 'package:flutter/material.dart';

import '../analytics/metric_insight.dart';
import '../components/simulated_data_badge.dart';
import '../components/surface_card.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../mission/mission_controller.dart';
import '../navigation/modules.dart';
import 'module_page.dart';
import 'page_frame.dart';
import 'simulation_controls.dart';

/// Data management: where each value comes from and how good it is.
class DataPage extends StatelessWidget {
  const DataPage({super.key, required this.module});

  final ModuleSpec module;

  @override
  Widget build(BuildContext context) {
    final controller = MissionScope.of(context);
    final snapshot = controller.snapshot;
    if (snapshot == null) {
      return ModulePage(
        module: module,
        emptyAction: const StartSimulationAction(),
      );
    }
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    final m = snapshot.mission;
    final readings = snapshot.insights.fold<int>(
      0,
      (sum, i) => sum + i.reference.length + i.monitoring.length,
    );

    final source = SurfaceCard(
      title: 'Data sources',
      subtitle: '1 source connected',
      leadingIcon: Icons.storage_outlined,
      trailing: const SimulatedDataBadge(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SourceRow(
            icon: Icons.science_outlined,
            title: 'RAKIA simulator (on this device)',
            details: [
              'Provenance: simulated',
              'Deterministic, seed ${m.seed}',
              '$readings daily readings across ${snapshot.insights.length} '
                  'indicators',
            ],
          ),
          const SizedBox(height: RakiaSpacing.lg),
          Text(
            'Simulated readings stay inside this simulation mission. They are '
            'never stored with, exported as or compared against real '
            'measurements.',
            style: t.bodySmall?.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: RakiaSpacing.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('end-simulation'),
              onPressed: controller.endSimulation,
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: const Text('End simulation mission'),
            ),
          ),
        ],
      ),
    );

    final quality = SurfaceCard(
      title: 'Data quality',
      subtitle: 'Mission-day readings that passed the quality gate',
      leadingIcon: Icons.verified_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var k = 0; k < snapshot.insights.length; k++) ...[
            if (k > 0) Divider(height: RakiaSpacing.xl, color: c.borderSubtle),
            _QualityRow(insight: snapshot.insights[k]),
          ],
        ],
      ),
    );

    final w = RakiaBreakpoints.of(MediaQuery.sizeOf(context).width);
    final wide = w == RakiaWindowClass.expanded || w == RakiaWindowClass.large;
    return PageFrame(
      title: module.label,
      eyebrow: module.group.label,
      summary: module.summary,
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: source),
                const SizedBox(width: RakiaSpacing.xl),
                Expanded(flex: 3, child: quality),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                source,
                const SizedBox(height: RakiaSpacing.lg),
                quality,
              ],
            ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.icon,
    required this.title,
    required this.details,
  });

  final IconData icon;
  final String title;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: Icon(icon, color: c.simulated)),
        const SizedBox(width: RakiaSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: t.labelLarge),
              const SizedBox(height: RakiaSpacing.xs),
              for (final d in details) Text(d, style: t.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _QualityRow extends StatelessWidget {
  const _QualityRow({required this.insight});

  final MetricInsight insight;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    final q = insight.qualitySummary;
    final usable = insight.assessment.nUsable;
    final total = insight.monitoring.length;
    final fraction = total == 0 ? 0.0 : usable / total;
    final passes = fraction >= 0.7;
    final color = passes ? c.statusWithinBaseline : c.statusDataQuality;

    return Semantics(
      container: true,
      label:
          '${insight.metric.label}: $usable of $total readings usable, '
          '${(fraction * 100).round()} percent. '
          '${passes ? 'Passes' : 'Below'} the 70 percent quality gate.',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(insight.metric.icon, size: 18, color: c.textSecondary),
              const SizedBox(width: RakiaSpacing.sm),
              Expanded(child: Text(insight.metric.label, style: t.labelLarge)),
              Text('$usable / $total', style: RakiaType.metric(t.labelLarge!)),
            ],
          ),
          const SizedBox(height: RakiaSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(RakiaRadii.pill),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: c.surface3,
              color: color,
            ),
          ),
          const SizedBox(height: RakiaSpacing.sm),
          Text(
            passes
                ? 'Passes the 70% quality gate.'
                : 'Below the 70% quality gate: '
                      '${q.nTotal - q.nValid} readings missing, implausible '
                      'or flagged by the device.',
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}
