import 'package:flutter/material.dart';

import '../analytics/metric_insight.dart';
import '../components/accent_box.dart';
import '../components/baseline_chart.dart';
import '../components/health_status.dart';
import '../components/metric_widgets.dart';
import '../components/simulated_data_badge.dart';
import '../components/surface_card.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../mission/mission_controller.dart';
import '../navigation/modules.dart';
import 'module_page.dart';
import 'page_frame.dart';
import 'simulation_controls.dart';

/// A monitoring module. With an active mission that includes indicators for
/// this module, shows each one in detail; otherwise the module's empty state.
class MonitoringPage extends StatelessWidget {
  const MonitoringPage({super.key, required this.module});

  final ModuleSpec module;

  @override
  Widget build(BuildContext context) {
    final snapshot = MissionScope.snapshotOf(context);
    final insights = snapshot?.forModule(module.id) ?? const [];
    if (snapshot == null || insights.isEmpty) {
      return ModulePage(
        module: module,
        emptyAction: snapshot == null ? const StartSimulationAction() : null,
      );
    }

    return PageFrame(
      title: module.label,
      eyebrow: module.group.label,
      summary: module.summary,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var k = 0; k < insights.length; k++) ...[
            if (k > 0) const SizedBox(height: RakiaSpacing.xl),
            MetricDetailCard(
              insight: insights[k],
              simulated: snapshot.isSimulation,
            ),
          ],
          if (module.note != null) ...[
            const SizedBox(height: RakiaSpacing.xl),
            _Note(text: module.note!),
          ],
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    return AccentBox(
      color: c.surface2,
      accent: c.brandText,
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

/// One indicator in full: chart, explanation and the statistics behind it.
class MetricDetailCard extends StatelessWidget {
  const MetricDetailCard({
    super.key,
    required this.insight,
    required this.simulated,
  });

  final MetricInsight insight;
  final bool simulated;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    final w = RakiaBreakpoints.of(MediaQuery.sizeOf(context).width);
    final wide = w == RakiaWindowClass.expanded || w == RakiaWindowClass.large;
    final m = insight.metric;
    final a = insight.assessment;
    final b = insight.baseline;
    final e = explain(insight);
    final trend = trendSummary(insight);
    const watchZ = 2.5;

    final stats = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('STATISTICS', style: t.labelSmall),
        const SizedBox(height: RakiaSpacing.xs),
        StatRow(
          label: 'Latest reading',
          value: m.formatWithUnit(a.latestValue),
        ),
        StatRow(label: 'Baseline median', value: m.formatWithUnit(b.center)),
        StatRow(
          label: 'Baseline spread (scaled MAD)',
          value: m.formatWithUnit(b.spread),
        ),
        StatRow(
          label: 'Expected range',
          value:
              '${m.format(b.center - watchZ * b.spread)} to '
              '${m.formatWithUnit(b.center + watchZ * b.spread)}',
        ),
        StatRow(
          label: 'Robust z (latest)',
          value: a.latestZ.isFinite ? a.latestZ.toStringAsFixed(2) : '-',
        ),
        StatRow(label: 'Baseline days used', value: '${b.n}'),
        StatRow(
          label: 'Usable mission readings',
          value: '${a.nUsable} of ${insight.monitoring.length}',
        ),
        StatRow(
          label: 'Window quality',
          value: '${(a.windowQuality * 100).round()}%',
        ),
      ],
    );

    final narrative = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ASSESSMENT', style: t.labelSmall),
        const SizedBox(height: RakiaSpacing.sm),
        Text(e.whatChanged, style: t.bodyLarge),
        const SizedBox(height: RakiaSpacing.sm),
        Text(e.since, style: t.bodyMedium?.copyWith(color: c.textSecondary)),
        const SizedBox(height: RakiaSpacing.lg),
        Text('TREND', style: t.labelSmall),
        const SizedBox(height: RakiaSpacing.sm),
        Text(trend.text, style: t.bodyMedium),
        const SizedBox(height: RakiaSpacing.lg),
        Text('WHY IT MATTERS', style: t.labelSmall),
        const SizedBox(height: RakiaSpacing.sm),
        Text(m.whyItMatters, style: t.bodyMedium),
        if (simulated) ...[
          const SizedBox(height: RakiaSpacing.lg),
          if (insight.series.scenario case final s?) _ScenarioNote(text: s),
        ],
      ],
    );

    return SurfaceCard(
      key: Key('metric-detail-${m.code}'),
      title: m.label,
      subtitle: 'Daily readings against your personal baseline',
      leadingIcon: m.icon,
      trailing: Wrap(
        spacing: RakiaSpacing.sm,
        runSpacing: RakiaSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.end,
        children: [
          if (simulated && wide) const SimulatedDataBadge(),
          StatusChip(status: insight.status),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: MetricValue(insight: insight)),
              if (simulated && !wide) const SimulatedDataBadge(),
            ],
          ),
          const SizedBox(height: RakiaSpacing.lg),
          BaselineChart(
            insight: insight,
            simulated: simulated,
            height: wide ? 260 : 220,
            watchZ: watchZ,
          ),
          const SizedBox(height: RakiaSpacing.md),
          ChartLegend(
            onsetColor: insight.hasShift ? insight.status.color(c) : null,
          ),
          const SizedBox(height: RakiaSpacing.xl),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: narrative),
                const SizedBox(width: RakiaSpacing.xxl),
                Expanded(flex: 2, child: stats),
              ],
            )
          else ...[
            narrative,
            const SizedBox(height: RakiaSpacing.xl),
            stats,
          ],
        ],
      ),
    );
  }
}

class _ScenarioNote extends StatelessWidget {
  const _ScenarioNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: 'Simulation ground truth. $text',
      excludeSemantics: true,
      child: AccentBox(
        color: c.surface3,
        accent: c.simulated,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SIMULATION GROUND TRUTH',
              style: t.labelSmall?.copyWith(color: c.simulated),
            ),
            const SizedBox(height: RakiaSpacing.xs),
            Text(text, style: t.bodySmall?.copyWith(color: c.textPrimary)),
          ],
        ),
      ),
    );
  }
}
