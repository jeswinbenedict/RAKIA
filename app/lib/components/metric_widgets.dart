import 'package:flutter/material.dart';

import '../analytics/metric_insight.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'baseline_chart.dart';
import 'health_status.dart';
import 'surface_card.dart';

/// Large tabular value with its unit, e.g. "64.5 bpm".
class MetricValue extends StatelessWidget {
  const MetricValue({super.key, required this.insight, this.style});

  final MetricInsight insight;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    final m = insight.metric;
    final v = insight.assessment.latestValue;
    final base = style ?? t.headlineMedium!;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: m.format(v), style: RakiaType.metric(base)),
          if (v.isFinite)
            TextSpan(
              text: m.unit == '%' ? '%' : ' ${m.unit}',
              style: t.bodyMedium?.copyWith(color: c.textSecondary),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// One indicator on the mission overview: status, latest value, change
/// against baseline and a sparkline. Opens the owning module on tap.
class MetricSummaryCard extends StatelessWidget {
  const MetricSummaryCard({
    super.key,
    required this.insight,
    required this.simulated,
    this.onOpen,
  });

  final MetricInsight insight;
  final bool simulated;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    final m = insight.metric;
    final a = insight.assessment;
    final deltaText = a.latestValue.isFinite
        ? '${a.deviation >= 0 ? '+' : '-'}${m.format(a.deviation.abs())} '
              '${m.unit == '%' ? 'pts' : m.unit} vs baseline'
        : 'No usable reading';

    return SurfaceCard(
      key: Key('metric-card-${m.code}'),
      onTap: onOpen,
      semanticLabel:
          '${m.label}. Status: ${insight.status.label}. '
          'Latest ${m.formatWithUnit(a.latestValue)}. $deltaText.',
      padding: const EdgeInsets.all(RakiaSpacing.lg),
      child: ExcludeSemantics(
        excluding: onOpen != null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(m.icon, size: 18, color: c.textSecondary),
                const SizedBox(width: RakiaSpacing.sm),
                Expanded(
                  child: Text(
                    m.label,
                    style: t.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onOpen != null)
                  Icon(Icons.chevron_right, size: 20, color: c.textSecondary),
              ],
            ),
            const SizedBox(height: RakiaSpacing.md),
            StatusChip(status: insight.status),
            const SizedBox(height: RakiaSpacing.md),
            MetricValue(insight: insight, style: t.headlineSmall),
            const SizedBox(height: 2),
            Text(deltaText, style: t.bodySmall),
            const SizedBox(height: RakiaSpacing.md),
            BaselineChart(
              insight: insight,
              simulated: simulated,
              compact: true,
              height: 56,
            ),
          ],
        ),
      ),
    );
  }
}

/// Count of indicators per status, as a row of compact tiles.
class StatusCountTile extends StatelessWidget {
  const StatusCountTile({super.key, required this.status, required this.count});

  final HealthStatus status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label:
          '$count ${count == 1 ? 'indicator' : 'indicators'}: '
          '${status.label}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: RakiaSpacing.lg,
          vertical: RakiaSpacing.md,
        ),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(RakiaRadii.md),
          border: Border.all(color: c.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusGlyph(status: status, size: 14),
                const Spacer(),
                Text(
                  '$count',
                  style: RakiaType.metric(t.headlineSmall!).copyWith(
                    color: count > 0 ? status.color(c) : c.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: RakiaSpacing.xs),
            Text(
              status.label,
              style: t.labelMedium?.copyWith(color: c.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Label/value pair used in statistics panels.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = RakiaColors.of(context);
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: RakiaSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Text(
                label,
                style: t.bodyMedium?.copyWith(color: c.textSecondary),
              ),
            ),
            const SizedBox(width: RakiaSpacing.lg),
            Expanded(
              flex: 2,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: RakiaType.metric(t.bodyMedium!),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The six-part explanation of an alert.
class ExplanationList extends StatelessWidget {
  const ExplanationList({super.key, required this.explanation});

  final AlertExplanation explanation;

  @override
  Widget build(BuildContext context) {
    final e = explanation;
    final items = [
      (Icons.change_history, 'What changed', e.whatChanged),
      (Icons.straighten, 'By how much', e.byHowMuch),
      (Icons.schedule, 'Since when', e.since),
      (Icons.dataset_outlined, 'From which readings', e.evidence),
      (Icons.info_outline, 'Why it matters', e.whyItMatters),
      (Icons.checklist, 'What to check next', e.checkNext),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (icon, label, text) in items)
          _ExplanationItem(icon: icon, label: label, text: text),
      ],
    );
  }
}

class _ExplanationItem extends StatelessWidget {
  const _ExplanationItem({
    required this.icon,
    required this.label,
    required this.text,
  });

  final IconData icon;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '$label. $text',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: RakiaSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 18, color: c.brandText),
            ),
            const SizedBox(width: RakiaSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(), style: t.labelSmall),
                  const SizedBox(height: 2),
                  Text(text, style: t.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
