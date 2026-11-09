import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../analytics/metric_insight.dart';
import '../components/accent_box.dart';
import '../components/baseline_chart.dart';
import '../components/empty_state.dart';
import '../components/health_status.dart';
import '../components/metric_widgets.dart';
import '../components/simulated_data_badge.dart';
import '../components/surface_card.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../environment/space_weather.dart';
import '../mission/mission_controller.dart';
import '../navigation/modules.dart';
import '../record/record_controller.dart';
import 'page_frame.dart';
import 'record_alerts.dart';
import 'simulation_controls.dart';
import 'space_weather_view.dart';

/// Action center: explainable alerts, most severe first.
class ActionsPage extends StatelessWidget {
  const ActionsPage({super.key, required this.module});

  final ModuleSpec module;

  @override
  Widget build(BuildContext context) {
    final snapshot = MissionScope.snapshotOf(context);
    final record = RecordScope.of(context);
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    final realAlerts = record.alerts;
    final simAlerts = snapshot?.alerts ?? const <MetricInsight>[];
    final sw = SpaceWeatherScope.of(context);
    final storm = switch (sw.snapshot) {
      final s? when s.stormLevel >= 1 => s,
      _ => null,
    };

    return PageFrame(
      title: module.label,
      eyebrow: module.group.label,
      summary: module.summary,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AccentBox(
            color: c.surface2,
            accent: c.brandText,
            child: Text(module.note!, style: t.bodyMedium),
          ),
          const SizedBox(height: RakiaSpacing.xl),
          if (storm != null) ...[
            const SectionHeading('Space weather'),
            const SizedBox(height: RakiaSpacing.md),
            SpaceWeatherAlert(snapshot: storm, now: sw.now),
            const SizedBox(height: RakiaSpacing.xxl),
          ],
          if (realAlerts.isEmpty && simAlerts.isEmpty && storm == null) ...[
            EmptyState(
              icon: Icons.notifications_none,
              title: module.emptyTitle,
              message: module.emptyMessage,
            ),
            const SizedBox(height: RakiaSpacing.xl),
          ],
          const SectionHeading('Your readings'),
          const SizedBox(height: RakiaSpacing.md),
          if (realAlerts.isEmpty)
            RecordStatusSummary(record: record)
          else
            for (var k = 0; k < realAlerts.length; k++) ...[
              if (k > 0) const SizedBox(height: RakiaSpacing.lg),
              AlertCard(
                insight: realAlerts[k],
                simulated: false,
                footer: AlertResponsePanel(
                  record: record,
                  alert: realAlerts[k],
                ),
              ),
            ],
          const SizedBox(height: RakiaSpacing.xxl),
          const Wrap(
            spacing: RakiaSpacing.md,
            runSpacing: RakiaSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SectionHeading('Simulation mission'),
              SimulatedDataBadge(),
            ],
          ),
          const SizedBox(height: RakiaSpacing.md),
          if (snapshot == null) ...[
            Text(
              'Practise with a simulated mission to see how alerts work. '
              'Simulated values are never mixed with your readings.',
              style: t.bodyMedium,
            ),
            const SizedBox(height: RakiaSpacing.md),
            const Align(
              alignment: Alignment.centerLeft,
              child: StartSimulationAction(),
            ),
          ] else if (simAlerts.isEmpty)
            Text('No simulated indicator needs attention.', style: t.bodyMedium)
          else
            for (var k = 0; k < simAlerts.length; k++) ...[
              if (k > 0) const SizedBox(height: RakiaSpacing.lg),
              AlertCard(insight: simAlerts[k], simulated: true),
            ],
        ],
      ),
    );
  }
}

class AlertCard extends StatelessWidget {
  const AlertCard({
    super.key,
    required this.insight,
    required this.simulated,
    this.footer,
  });

  final MetricInsight insight;
  final bool simulated;

  /// Shown under the explanation; real alerts put the confirmatory check
  /// and the response log here.
  final Widget? footer;

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
          readingsLabel: simulated ? 'Mission readings' : 'Your readings',
        ),
      ],
    );
    final details = ExplanationList(explanation: e);

    return SurfaceCard(
      key: Key(
        '${simulated ? 'alert' : 'record-alert'}-${insight.metric.code}',
      ),
      title: e.headline,
      subtitle: simulated
          ? '${module.label}, ${insight.metric.label.toLowerCase()}'
          : 'Your readings, ${insight.metric.label.toLowerCase()}',
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
          if (footer case final f?)
            f
          else
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
