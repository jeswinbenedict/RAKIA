import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../analytics/day_format.dart';
import '../analytics/metric_definitions.dart';
import '../analytics/metric_insight.dart';
import '../components/empty_state.dart';
import '../components/health_status.dart';
import '../components/surface_card.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../navigation/modules.dart';
import '../record/record.dart';
import '../record/record_controller.dart';
import 'page_frame.dart';
import 'record_alerts.dart';

/// The astronaut's own health record: enter real readings, see how far the
/// personal baseline has come, and, once it is established, librakia's
/// evaluation of the latest week against it.
class RecordPage extends StatelessWidget {
  const RecordPage({super.key, required this.module});

  final ModuleSpec module;

  @override
  Widget build(BuildContext context) {
    final record = RecordScope.of(context);
    return PageFrame(
      title: module.label,
      eyebrow: module.group.label,
      summary: module.summary,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (record.error case final e?) ...[
            _Notice(icon: Icons.error_outline, text: e),
            const SizedBox(height: RakiaSpacing.lg),
          ],
          if (record.ready && !record.persistent) ...[
            const _Notice(
              icon: Icons.info_outline,
              text:
                  'This browser cannot keep data, so readings last only for '
                  'this session.',
            ),
            const SizedBox(height: RakiaSpacing.lg),
          ],
          _EntryForm(record: record),
          const SizedBox(height: RakiaSpacing.xl),
          const _HowItWorks(),
          const SizedBox(height: RakiaSpacing.xl),
          if (!record.hasEntries)
            EmptyState(
              icon: module.icon,
              title: module.emptyTitle,
              message: module.emptyMessage,
            )
          else
            for (final i in record.indicators) ...[
              _IndicatorCard(record: record, indicator: i),
              const SizedBox(height: RakiaSpacing.lg),
            ],
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: c.textSecondary),
          const SizedBox(width: RakiaSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

String _date(DateTime d) => formatDay(d);

/// Records a reading, or a correction of an earlier one.
class _EntryForm extends StatefulWidget {
  const _EntryForm({required this.record, this.correcting, this.onDone});

  final RecordController record;
  final RecordEntry? correcting;
  final VoidCallback? onDone;

  @override
  State<_EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<_EntryForm> {
  late MetricDefinition _metric = widget.correcting == null
      ? kMetricDefinitions.first
      : kMetricDefinitions.firstWhere(
          (m) => m.code == widget.correcting!.metricCode,
        );
  late final TextEditingController _value = TextEditingController(
    text: widget.correcting == null
        ? ''
        : _metric.format(widget.correcting!.value),
  );
  late DateTime _day = widget.correcting?.day ?? widget.record.today;
  String? _problem;
  bool _saving = false;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final today = widget.record.today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: today.subtract(
        const Duration(days: RecordWindows.maxBackdateDays),
      ),
      lastDate: today,
      helpText: 'Day of the reading',
    );
    if (picked != null) setState(() => _day = calendarDay(picked));
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _problem = null;
    });
    final problem = await widget.record.add(
      metric: _metric,
      value: double.tryParse(_value.text.trim().replaceAll(',', '.')),
      day: _day,
      correcting: widget.correcting,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _problem = problem;
    });
    if (problem == null) {
      final what = widget.correcting == null ? 'Saved' : 'Corrected';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$what: ${_metric.label} '
            '${_metric.formatWithUnit(double.parse(_value.text.trim().replaceAll(',', '.')))} '
            'on ${_date(_day)}.',
          ),
        ),
      );
      _value.clear();
      widget.onDone?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final correcting = widget.correcting != null;
    final form = LayoutBuilder(
      builder: (context, box) => Wrap(
        spacing: RakiaSpacing.lg,
        runSpacing: RakiaSpacing.lg,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          SizedBox(
            width: box.maxWidth < 260 ? box.maxWidth : 260,
            child: DropdownButtonFormField<MetricDefinition>(
              key: const Key('record-metric'),
              isExpanded: true,
              initialValue: _metric,
              decoration: const InputDecoration(labelText: 'Indicator'),
              items: [
                for (final m in kMetricDefinitions)
                  DropdownMenuItem(
                    value: m,
                    child: Text(m.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: correcting
                  ? null
                  : (m) => setState(() => _metric = m ?? _metric),
            ),
          ),
          SizedBox(
            width: box.maxWidth < 180 ? box.maxWidth : 180,
            child: TextField(
              key: const Key('record-value'),
              controller: _value,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'Value',
                suffixText: _metric.unit,
                helperText:
                    '${_metric.format(_metric.plausibleMin)} to '
                    '${_metric.format(_metric.plausibleMax)}',
              ),
              onSubmitted: (_) => _saving ? null : _save(),
            ),
          ),
          OutlinedButton.icon(
            onPressed: correcting ? null : _pickDay,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(_date(_day)),
          ),
          FilledButton(
            key: const Key('record-save'),
            onPressed: _saving || !widget.record.ready ? null : _save,
            child: Text(correcting ? 'Save correction' : 'Save reading'),
          ),
        ],
      ),
    );
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        form,
        if (_problem case final p?) ...[
          const SizedBox(height: RakiaSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(
              key: const Key('record-error'),
              p,
              style: t.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ],
    );
    if (correcting) return body;
    return SurfaceCard(
      title: 'Add a reading',
      subtitle:
          'From your own measurement or device. Readings can be dated up to '
          '${RecordWindows.maxBackdateDays} days back to load your history.',
      leadingIcon: Icons.add_chart_outlined,
      child: body,
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Text(
      'Your usual range for each indicator is learned from up to '
      '${RecordWindows.referenceDays} days before the past week, and needs '
      'at least ${RecordWindows.minBaselineDays} of them. The past '
      '${RecordWindows.monitoringDays} days are then compared with it. This '
      'is a personal trend check, not a diagnosis.',
      style: t.bodyMedium,
    );
  }
}

class _IndicatorCard extends StatelessWidget {
  const _IndicatorCard({required this.record, required this.indicator});

  final RecordController record;
  final RecordIndicator indicator;

  Future<void> _correct(BuildContext context, RecordEntry e) =>
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Correct ${indicator.metric.label.toLowerCase()}'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recorded ${indicator.metric.formatWithUnit(e.value)} on '
                  '${_date(e.day)}. The original stays in the ledger; the '
                  'correction replaces it in every evaluation.',
                ),
                const SizedBox(height: RakiaSpacing.lg),
                _EntryForm(
                  record: record,
                  correcting: e,
                  onDone: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = RakiaColors.of(context);
    final m = indicator.metric;
    final i = indicator.insight;
    final latest = indicator.entries.isEmpty ? null : indicator.entries.first;
    return SurfaceCard(
      key: Key('record-card-${m.code}'),
      title: m.label,
      subtitle: latest == null
          ? 'Nothing recorded yet'
          : 'Latest ${m.formatWithUnit(latest.value)} on ${_date(latest.day)}',
      leadingIcon: m.icon,
      trailing: i == null ? null : StatusChip(status: i.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (i != null)
            _Evaluation(insight: i)
          else if (indicator.analysisError case final err?)
            Text(err)
          else ...[
            Text(
              'Baseline: ${indicator.baselineDays} of '
              '${RecordWindows.minBaselineDays} days',
              style: t.titleSmall,
            ),
            const SizedBox(height: RakiaSpacing.sm),
            LinearProgressIndicator(
              value: (indicator.baselineDays / RecordWindows.minBaselineDays)
                  .clamp(0, 1),
              semanticsLabel: '${m.label} baseline progress',
            ),
            const SizedBox(height: RakiaSpacing.sm),
            Text(
              'Readings from the past ${RecordWindows.monitoringDays} days '
              'are compared with the baseline, so they do not count toward '
              'it.',
              style: t.bodySmall?.copyWith(color: c.textSecondary),
            ),
          ],
          if (record.responsesForMetric(m.code) case final rs
              when rs.isNotEmpty) ...[
            const SizedBox(height: RakiaSpacing.lg),
            Text('Your responses to alerts', style: t.titleSmall),
            const SizedBox(height: RakiaSpacing.xs),
            for (final r in rs.take(5)) ResponseLine(response: r),
          ],
          if (indicator.entries.isNotEmpty) ...[
            const SizedBox(height: RakiaSpacing.lg),
            Text('Recent readings', style: t.titleSmall),
            const SizedBox(height: RakiaSpacing.xs),
            for (final e in indicator.entries.take(5))
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_date(e.day)}: ${m.formatWithUnit(e.value)}',
                    ),
                  ),
                  TextButton(
                    onPressed: () => _correct(context, e),
                    child: Text(
                      'Correct',
                      semanticsLabel:
                          'Correct ${m.label} reading of ${_date(e.day)}',
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _Evaluation extends StatelessWidget {
  const _Evaluation({required this.insight});
  final MetricInsight insight;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final e = explain(insight);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(e.headline, style: t.titleSmall),
        const SizedBox(height: RakiaSpacing.xs),
        Text(e.whatChanged),
        if (insight.status == HealthStatus.watch ||
            insight.status == HealthStatus.act) ...[
          const SizedBox(height: RakiaSpacing.sm),
          Text('By how much: ${e.byHowMuch}'),
          Text('Since: ${e.since}'),
          const SizedBox(height: RakiaSpacing.sm),
          Text('Why it matters: ${e.whyItMatters}'),
          Text('What to check next: ${e.checkNext}'),
        ],
      ],
    );
  }
}
