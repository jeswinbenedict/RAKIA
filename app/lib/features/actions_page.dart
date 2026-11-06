import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../analytics/metric_insight.dart';
import '../components/baseline_chart.dart';
import '../components/empty_state.dart';
import '../components/health_status.dart';
import '../components/metric_widgets.dart';
import '../components/surface_card.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../mission/mission_controller.dart';
import '../navigation/modules.dart';
import 'module_page.dart';
import 'page_frame.dart';
import 'simulation_controls.dart';

/// Action center: explainable alerts, most severe first.
class ActionsPage extends StatelessWidget {
  const ActionsPage({super.key, required this.module});

  final ModuleSpec module;

  @override
  Widget build(BuildContext context) {
    final snapshot = MissionScope.snapshotOf(context);
    if (snapshot == null) {
      return ModulePage(
        module: module,
        emptyAction: const StartSimulationAction(),
      );
    }
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    final alerts = snapshot.alerts;

    return PageFrame(
      title: module.label,
      eyebrow: module.group.label,
      summary: module.summary,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(RakiaSpacing.md),
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(RakiaRadii.sm),
              border: Border(left: BorderSide(color: c.brandText, width: 3)),
            ),
            child: Text(module.note!, style: t.bodyMedium),
          ),
          const SizedBox(height: RakiaSpacing.xl),
          if (alerts.isEmpty)
            EmptyState(
              icon: Icons.notifications_none,
              title: module.emptyTitle,
              message: module.emptyMessage,
            )
          else
            for (var k = 0; k < alerts.length; k++) ...[
              if (k > 0) const SizedBox(height: RakiaSpacing.lg),
              AlertCard(insight: alerts[k], simulated: snapshot.isSimulation),
            ],
        ],
      ),
    );
  }
}

class AlertCard extends StatelessWidget {
  const AlertCard({super.key, required this.insight, required this.simulated});

  final MetricInsight insight;
  final bool simulated;

  @override
  Widget build(BuildContext context) {
    final e = explain(insight);
    final module = kModules.firstWhere((m) => m.id == insight.metric.moduleId);
    final w = RakiaBreakpoints.of(MediaQuery.sizeOf(context).width);
    final wide = w == RakiaWindowClass.expanded || w == RakiaWindowClass.large;
    final c = RakiaColors.of(context);

    final chart = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BaselineChart(insight: insight, simulated: simulated, height: 200),
        const SizedBox(height: RakiaSpacing.md),
        ChartLegend(
          onsetColor: insight.hasShift ? insight.status.color(c) : null,
        ),
      ],
    );
    final details = ExplanationList(explanation: e);

    return SurfaceCard(
      key: Key('alert-${insight.metric.code}'),
      title: e.headline,
      subtitle: '${module.label}, ${insight.metric.label.toLowerCase()}',
      leadingIcon: insight.metric.icon,
      trailing: StatusChip(status: insight.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: chart),
                const SizedBox(width: RakiaSpacing.xl),
                Expanded(flex: 4, child: details),
              ],
            )
          else ...[
            chart,
            const SizedBox(height: RakiaSpacing.lg),
            details,
          ],
          const SizedBox(height: RakiaSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => context.go(module.path),
              icon: Icon(module.icon, size: 18),
              label: Text('Open ${module.label}'),
            ),
          ),
        ],
      ),
    );
  }
}
