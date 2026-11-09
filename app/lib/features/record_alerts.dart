import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../analytics/day_format.dart';
import '../analytics/metric_insight.dart';
import '../components/health_status.dart';
import '../components/surface_card.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../record/alert_response.dart';
import '../record/record.dart';
import '../record/record_controller.dart';

/// Where the astronaut's own record stands when nothing needs attention.
class RecordStatusSummary extends StatelessWidget {
  const RecordStatusSummary({super.key, required this.record});

  final RecordController record;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final String text;
    if (!record.ready || record.loading || record.indicators.isEmpty) {
      text = 'Your health record is opening.';
    } else if (!record.hasEntries) {
      text =
          'Alerts from your own readings appear here once an indicator has '
          'readings on at least ${RecordWindows.minBaselineDays} days before '
          'the past week. Nothing here is ever based on simulated data.';
    } else {
      final evaluated = record.indicators.where((i) => i.insight != null);
      if (evaluated.isEmpty) {
        final closest = record.indicators.reduce(
          (a, b) => a.baselineDays >= b.baselineDays ? a : b,
        );
        text =
            'No indicator has an established baseline yet. Closest: '
            '${closest.metric.label.toLowerCase()}, ${closest.baselineDays} '
            'of ${RecordWindows.minBaselineDays} days.';
      } else {
        text =
            '${evaluated.length} of ${record.indicators.length} indicators '
            'are evaluated against your baseline, and none needs attention.';
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(key: const Key('record-status'), text, style: t.bodyMedium),
        const SizedBox(height: RakiaSpacing.md),
        OutlinedButton.icon(
          onPressed: () => context.go('/record'),
          icon: const Icon(Icons.edit_note_outlined, size: 18),
          label: const Text('Open My health record'),
        ),
      ],
    );
  }
}

/// The confirmatory check for an alert on the astronaut's record, the ways
/// to respond, and the responses logged so far.
class AlertResponsePanel extends StatelessWidget {
  const AlertResponsePanel({
    super.key,
    required this.record,
    required this.alert,
  });

  final RecordController record;
  final MetricInsight alert;

  /// The reading the explanation quotes: the latest usable one.
  RecordEntry? _flaggedEntry() {
    final day = alert.dateOf(alert.assessment.latestIndex);
    for (final i in record.indicators) {
      if (i.metric.code != alert.metric.code) continue;
      for (final e in i.entries) {
        if (e.day == day) return e;
      }
      return i.entries.isEmpty ? null : i.entries.first;
    }
    return null;
  }

  Future<void> _reading(BuildContext context, {RecordEntry? correcting}) =>
      showDialog<void>(
        context: context,
        builder: (_) => _ReadingDialog(
          record: record,
          alert: alert,
          correcting: correcting,
        ),
      );

  Future<void> _check(BuildContext context) async {
    final entry = _flaggedEntry();
    if (entry == null) return;
    final m = alert.metric;
    final choice = await showDialog<AlertResponseKind>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Check ${m.label.toLowerCase()}'),
        content: SizedBox(
          width: 480,
          child: Text(
            'Recorded ${m.formatWithUnit(entry.value)} on '
            '${formatDay(entry.day)}. ${m.confirmatoryCheck}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('check-correct-it'),
            onPressed: () =>
                Navigator.of(dialogContext)
                    .pop(AlertResponseKind.valueCorrected),
            child: const Text('Correct it'),
          ),
          FilledButton(
            key: const Key('check-is-correct'),
            onPressed: () =>
                Navigator.of(dialogContext).pop(AlertResponseKind.valueChecked),
            child: const Text('It is correct'),
          ),
        ],
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == AlertResponseKind.valueCorrected) {
      await _reading(context, correcting: entry);
    } else {
      await _log(context, choice, askNote: false);
    }
  }

  Future<void> _log(
    BuildContext context,
    AlertResponseKind kind, {
    bool askNote = true,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    String? note;
    if (askNote) {
      final result = await showDialog<_NoteResult>(
        context: context,
        builder: (_) => _NoteDialog(kind: kind),
      );
      if (result == null) return;
      note = result.note;
    }
    final problem = await record.respond(alert, kind, note: note);
    messenger.showSnackBar(
      SnackBar(content: Text(problem ?? 'Logged: ${kind.label}.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = RakiaColors.of(context);
    final m = alert.metric;
    final code = m.code;
    final dataQuality = alert.status == HealthStatus.dataQuality;
    final responses = record.responsesFor(alert);

    final String guidance;
    if (dataQuality) {
      guidance = explain(alert).checkNext;
    } else {
      guidance = m.confirmatoryCheck;
    }

    return Container(
      padding: const EdgeInsets.all(RakiaSpacing.md),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(RakiaRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              dataQuality ? 'Fill the gaps' : 'Confirm before acting',
              style: t.titleSmall,
            ),
          ),
          const SizedBox(height: RakiaSpacing.xs),
          Text(guidance, style: t.bodyMedium),
          if (alert.status == HealthStatus.act) ...[
            const SizedBox(height: RakiaSpacing.sm),
            Text(
              'If the check agrees, contact your flight surgeon or medical '
              'support and follow your mission medical procedures. RAKIA '
              'flags changes; it does not diagnose.',
              style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: RakiaSpacing.md),
          Wrap(
            spacing: RakiaSpacing.sm,
            runSpacing: RakiaSpacing.sm,
            children: [
              if (dataQuality)
                FilledButton.icon(
                  key: Key('add-readings-$code'),
                  onPressed: () => context.go('/record'),
                  icon: const Icon(Icons.edit_note_outlined, size: 18),
                  label: const Text('Add readings'),
                )
              else if (m.repeatable)
                FilledButton.icon(
                  key: Key('confirm-$code'),
                  onPressed: record.ready ? () => _reading(context) : null,
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text('Record a confirmatory reading'),
                )
              else
                FilledButton.icon(
                  key: Key('check-$code'),
                  onPressed: record.ready && _flaggedEntry() != null
                      ? () => _check(context)
                      : null,
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: const Text('Check the reading'),
                ),
              OutlinedButton(
                key: Key('watch-$code'),
                onPressed: record.ready
                    ? () => _log(context, AlertResponseKind.keepWatching)
                    : null,
                child: const Text('Keep watching'),
              ),
              if (!dataQuality)
                OutlinedButton(
                  key: Key('medical-$code'),
                  onPressed: record.ready
                      ? () => _log(context, AlertResponseKind.contactedMedical)
                      : null,
                  child: const Text('I contacted medical support'),
                ),
            ],
          ),
          const SizedBox(height: RakiaSpacing.md),
          Text('Your responses', style: t.labelLarge),
          const SizedBox(height: RakiaSpacing.xs),
          if (responses.isEmpty)
            Text(
              'None yet.',
              style: t.bodySmall?.copyWith(color: c.textSecondary),
            )
          else
            for (final r in responses) ResponseLine(response: r),
        ],
      ),
    );
  }
}

/// One logged response, in words.
class ResponseLine extends StatelessWidget {
  const ResponseLine({super.key, required this.response});

  final AlertResponse response;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = response;
    final at = r.recordedAt.toLocal();
    final time =
        '${formatDay(at, withYear: false)}, '
        '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
    final parts = [
      '${r.kind.label}.',
      ?r.note,
      if (r.outcome case final o?) outcomeText(o),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: RakiaSpacing.xs),
      child: Text('$time: ${parts.join(' ')}', style: t.bodySmall),
    );
  }
}

class _NoteResult {
  const _NoteResult(this.note);
  final String? note;
}

/// Confirms a response and takes an optional note.
class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.kind});
  final AlertResponseKind kind;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.kind.label),
    content: SizedBox(
      width: 480,
      child: TextField(
        key: const Key('response-note'),
        controller: _note,
        maxLength: kMaxResponseNote,
        maxLines: 3,
        minLines: 1,
        decoration: const InputDecoration(
          labelText: 'Note (optional)',
          helperText: 'Kept on this device with your record.',
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('response-log'),
        onPressed: () {
          final text = _note.text.trim();
          Navigator.of(context).pop(_NoteResult(text.isEmpty ? null : text));
        },
        child: const Text('Log it'),
      ),
    ],
  );
}

/// Takes a confirmatory reading for today, or corrects the flagged one,
/// and logs it as the response to the alert.
class _ReadingDialog extends StatefulWidget {
  const _ReadingDialog({
    required this.record,
    required this.alert,
    this.correcting,
  });

  final RecordController record;
  final MetricInsight alert;
  final RecordEntry? correcting;

  @override
  State<_ReadingDialog> createState() => _ReadingDialogState();
}

class _ReadingDialogState extends State<_ReadingDialog> {
  final _value = TextEditingController();
  String? _problem;
  bool _saving = false;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final m = widget.alert.metric;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _problem = null;
    });
    final problem = await widget.record.add(
      metric: m,
      value: double.tryParse(_value.text.trim().replaceAll(',', '.')),
      day: widget.correcting?.day ?? widget.record.today,
      correcting: widget.correcting,
      respondingTo: widget.alert,
    );
    if (!mounted) return;
    if (problem != null) {
      setState(() {
        _saving = false;
        _problem = problem;
      });
      return;
    }
    navigator.pop();
    final now = widget.record.insightFor(m.code)?.status;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Logged. ${now == null ? '' : outcomeText(now)}'.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.alert.metric;
    final correcting = widget.correcting;
    final t = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text(
        correcting == null
            ? 'Confirmatory reading'
            : 'Correct ${m.label.toLowerCase()}',
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              correcting == null
                  ? '${m.confirmatoryCheck} The new reading counts for '
                        'today; if you already recorded one today, it '
                        'replaces it in the evaluation. Both stay in your '
                        'record.'
                  : 'Recorded ${m.formatWithUnit(correcting.value)} on '
                        '${formatDay(correcting.day)}. The original stays in '
                        'your record; the correction replaces it in every '
                        'evaluation.',
            ),
            const SizedBox(height: RakiaSpacing.lg),
            TextField(
              key: const Key('confirm-value'),
              controller: _value,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: m.label,
                suffixText: m.unit,
                helperText:
                    '${m.format(m.plausibleMin)} to '
                    '${m.format(m.plausibleMax)}',
              ),
              onSubmitted: (_) => _saving ? null : _save(),
            ),
            if (_problem case final p?) ...[
              const SizedBox(height: RakiaSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  key: const Key('confirm-error'),
                  p,
                  style: t.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirm-save'),
          onPressed: _saving ? null : _save,
          child: Text(correcting == null ? 'Save and evaluate' : 'Save'),
        ),
      ],
    );
  }
}

/// The astronaut's own record on the Mission overview: what needs attention
/// from their real readings, or where the baseline stands.
class RecordOverviewCard extends StatelessWidget {
  const RecordOverviewCard({super.key, required this.record});

  final RecordController record;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = RakiaColors.of(context);
    final alerts = record.alerts;
    return SurfaceCard(
      key: const Key('record-overview'),
      title: 'Your health record',
      subtitle: alerts.isEmpty
          ? 'From readings you entered'
          : '${alerts.length} of ${record.indicators.length} indicators need '
                'attention',
      leadingIcon: Icons.edit_note_outlined,
      trailing: alerts.isEmpty
          ? null
          : TextButton(
              onPressed: () => context.go('/actions'),
              child: const Text('Open Action center'),
            ),
      child: alerts.isEmpty
          ? RecordStatusSummary(record: record)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var k = 0; k < alerts.length; k++) ...[
                  if (k > 0)
                    Divider(height: RakiaSpacing.xl, color: c.borderSubtle),
                  Wrap(
                    spacing: RakiaSpacing.md,
                    runSpacing: RakiaSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusChip(status: alerts[k].status),
                      Text(explain(alerts[k]).headline, style: t.labelLarge),
                    ],
                  ),
                  const SizedBox(height: RakiaSpacing.xs),
                  Text(
                    record.responsesFor(alerts[k]).isEmpty
                        ? 'No response yet.'
                        : 'Last response: '
                              '${record.responsesFor(alerts[k]).first.kind.label}.',
                    style: t.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                ],
              ],
            ),
    );
  }
}
