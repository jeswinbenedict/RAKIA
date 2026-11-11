import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../analytics/metric_insight.dart';
import '../components/health_status.dart';
import '../components/metric_widgets.dart';
import '../components/simulated_data_badge.dart';
import '../components/surface_card.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../mission/mission_controller.dart';
import '../navigation/modules.dart';
import '../record/record_controller.dart';
import 'crew_greeting.dart';
import 'module_page.dart';
import 'page_frame.dart';
import 'record_alerts.dart';
import 'simulation_controls.dart';
import 'space_weather_view.dart';

/// Mission overview: mission context, status counts, what needs attention
/// and every indicator against its baseline.
class MissionPage extends StatelessWidget {
  const MissionPage({super.key, required this.module});

  final ModuleSpec module;

  @override
  Widget build(BuildContext context) {
    final snapshot = MissionScope.snapshotOf(context);
    final record = RecordScope.of(context);
    if (snapshot == null) {
      return ModulePage(
        module: module,
        emptyAction: const StartSimulationAction(),
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CrewGreetingCard(),
            const SizedBox(height: RakiaSpacing.xl),
            RecordOverviewCard(record: record),
            const SizedBox(height: RakiaSpacing.xl),
            const SpaceWeatherSummaryCard(),
          ],
        ),
      );
    }
    final w = RakiaBreakpoints.of(MediaQuery.sizeOf(context).width);
    final mission = snapshot.mission;

    return PageFrame(
      title: module.label,
      eyebrow: module.group.label,
      summary:
          '${mission.crewMember}, mission day ${mission.missionDay}. Every '
          'indicator is compared with a personal baseline from '
          '${mission.referenceDays} pre-flight days.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CrewGreetingCard(),
          const SizedBox(height: RakiaSpacing.xl),
          RecordOverviewCard(record: record),
          const SizedBox(height: RakiaSpacing.xl),
          const SpaceWeatherSummaryCard(),
          const SizedBox(height: RakiaSpacing.xl),
          _MissionContextCard(snapshot: snapshot),
          const SizedBox(height: RakiaSpacing.xl),
          const SectionHeading('Status across indicators'),
          const SizedBox(height: RakiaSpacing.md),
          _ResponsiveGrid(
            columns: switch (w) {
              RakiaWindowClass.compact => 2,
              RakiaWindowClass.medium => 3,
              _ => 5,
            },
            minTileWidth: 0,
            children: [
              for (final s in const [
                HealthStatus.act,
                HealthStatus.watch,
                HealthStatus.dataQuality,
                HealthStatus.withinBaseline,
                HealthStatus.insufficientData,
              ])
                StatusCountTile(status: s, count: snapshot.count(s)),
            ],
          ),
          const SizedBox(height: RakiaSpacing.xl),
          _AttentionCard(snapshot: snapshot),
          const SizedBox(height: RakiaSpacing.xl),
          const SectionHeading('Indicators'),
          const SizedBox(height: RakiaSpacing.md),
          _ResponsiveGrid(
            columns: switch (w) {
              RakiaWindowClass.compact => 1,
              RakiaWindowClass.medium => 2,
              RakiaWindowClass.expanded => 2,
              RakiaWindowClass.large => 3,
            },
            minTileWidth: 0,
            children: [
              for (final i in snapshot.insights)
                MetricSummaryCard(
                  insight: i,
                  simulated: snapshot.isSimulation,
                  onOpen: () => context.go('/${i.metric.moduleId}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lays children out in equal-width columns with consistent gutters.
class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({
    required this.columns,
    required this.children,
    this.minTileWidth = 0,
  });

  final int columns;
  final double minTileWidth;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const gap = RakiaSpacing.lg;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = columns.clamp(1, children.isEmpty ? 1 : children.length);
        final width = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in children) SizedBox(width: width, child: c),
          ],
        );
      },
    );
  }
}

class _MissionContextCard extends StatelessWidget {
  const _MissionContextCard({required this.snapshot});

  final MissionSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    final m = snapshot.mission;
    final progress = m.missionDay / m.plannedDays;
    final facts = [
      ('Crew member', m.crewMember),
      ('Phase', 'In flight'),
      ('Baseline', '${m.referenceDays} pre-flight days'),
      ('Indicators', '${snapshot.insights.length}'),
    ];

    return SurfaceCard(
      title: m.name,
      subtitle: 'Deterministic scenario, seed ${m.seed}',
      leadingIcon: Icons.rocket_launch_outlined,
      trailing: const SimulatedDataBadge(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            label:
                'Mission day ${m.missionDay} of ${m.plannedDays}, '
                '${(progress * 100).round()} percent complete',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: RakiaSpacing.lg,
                  runSpacing: RakiaSpacing.xs,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Day ${m.missionDay}',
                            style: RakiaType.metric(t.headlineSmall!),
                          ),
                          TextSpan(
                            text: '  of ${m.plannedDays}',
                            style: t.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}% complete',
                      style: t.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: RakiaSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(RakiaRadii.pill),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: c.surface3,
                    color: c.brandText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: RakiaSpacing.lg),
          Wrap(
            spacing: RakiaSpacing.xxl,
            runSpacing: RakiaSpacing.md,
            children: [
              for (final (label, value) in facts)
                Semantics(
                  container: true,
                  label: '$label: $value',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label.toUpperCase(), style: t.labelSmall),
                      const SizedBox(height: 2),
                      Text(value, style: t.labelLarge),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.snapshot});

  final MissionSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    final alerts = snapshot.alerts;
    return SurfaceCard(
      title: 'Needs attention',
      subtitle: alerts.isEmpty
          ? 'No indicator needs attention.'
          : '${alerts.length} of ${snapshot.insights.length} indicators',
      leadingIcon: Icons.notifications_outlined,
      trailing: alerts.isEmpty
          ? null
          : TextButton(
              onPressed: () => context.go('/actions'),
              child: const Text('Open Action center'),
            ),
      child: alerts.isEmpty
          ? Text(
              'Every indicator with enough reliable data is within its '
              'personal baseline.',
              style: t.bodyMedium?.copyWith(color: c.textSecondary),
            )
          : Column(
              children: [
                for (var k = 0; k < alerts.length; k++) ...[
                  if (k > 0)
                    Divider(height: RakiaSpacing.xl, color: c.borderSubtle),
                  _AttentionRow(insight: alerts[k]),
                ],
              ],
            ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.insight});

  final MetricInsight insight;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final e = explain(insight);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(e.headline, style: t.labelLarge),
        const SizedBox(height: RakiaSpacing.xs),
        Text(e.whatChanged, style: t.bodyMedium),
        const SizedBox(height: 2),
        Text(e.since, style: t.bodySmall),
      ],
    );
    final chip = StatusChip(status: insight.status);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kNarrowCardWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              chip,
              const SizedBox(height: RakiaSpacing.sm),
              text,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: text),
            const SizedBox(width: RakiaSpacing.lg),
            chip,
          ],
        );
      },
    );
  }
}
