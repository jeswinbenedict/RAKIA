import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../components/surface_card.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../navigation/modules.dart';
import '../wellbeing/format.dart';
import '../wellbeing/instruments.dart';
import '../wellbeing/wellbeing_controller.dart';
import 'module_page.dart';
import 'page_frame.dart';
import 'simulation_controls.dart';

const String kCheckInPath = '/behavioural/check-in';
const String kReactionTestPath = '/behavioural/reaction-test';

/// Behavioural health: the astronaut's own check-ins and reaction-time
/// results. Real self-reports, private to this device, never part of a
/// simulation and never interpreted as a diagnosis.
class WellbeingPage extends StatelessWidget {
  const WellbeingPage({super.key, required this.module});

  final ModuleSpec module;

  @override
  Widget build(BuildContext context) {
    final w = WellbeingScope.of(context);
    if (w.isEmpty && w.error == null) {
      return ModulePage(
        module: module,
        emptyAction: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Actions(),
            if (!w.persistent) ...[
              const SizedBox(height: RakiaSpacing.md),
              const _MemoryOnlyNote(),
            ],
          ],
        ),
      );
    }

    return PageFrame(
      title: module.label,
      eyebrow: module.group.label,
      summary: module.summary,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Actions(),
          if (w.error != null) ...[
            const SizedBox(height: RakiaSpacing.md),
            OperationError(message: w.error!),
          ],
          if (!w.persistent) ...[
            const SizedBox(height: RakiaSpacing.md),
            const _MemoryOnlyNote(),
          ],
          if (w.checkIns.isNotEmpty) ...[
            const SizedBox(height: RakiaSpacing.xl),
            _CheckInsCard(checkIns: w.checkIns),
          ],
          if (w.reactionTests.isNotEmpty) ...[
            const SizedBox(height: RakiaSpacing.xl),
            _ReactionTestsCard(tests: w.reactionTests),
          ],
          const SizedBox(height: RakiaSpacing.xl),
          _PrivacyCard(controller: w),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: RakiaSpacing.md,
      runSpacing: RakiaSpacing.md,
      children: [
        FilledButton.icon(
          key: const Key('start-check-in'),
          onPressed: () => context.go(kCheckInPath),
          icon: const Icon(Icons.edit_note_outlined),
          label: const Text('Start a check-in'),
        ),
        OutlinedButton.icon(
          key: const Key('start-reaction-test'),
          onPressed: () => context.go(kReactionTestPath),
          icon: const Icon(Icons.timer_outlined),
          label: const Text('Reaction-time test'),
        ),
      ],
    );
  }
}

class _MemoryOnlyNote extends StatelessWidget {
  const _MemoryOnlyNote();

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    return Text(
      'Local storage is unavailable, so check-ins and test results are kept '
      'only until RAKIA closes.',
      key: const Key('wellbeing-memory-only'),
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: c.textSecondary),
    );
  }
}

class _CheckInsCard extends StatelessWidget {
  const _CheckInsCard({required this.checkIns});

  final List<CheckIn> checkIns;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    final latest = checkIns.first;
    final recent = checkIns.take(30).toList().reversed.toList();
    return SurfaceCard(
      key: const Key('check-ins-card'),
      title: 'Check-ins',
      subtitle:
          '${checkIns.length} recorded; latest ${formatLocalDateTime(latest.recordedAt)}',
      leadingIcon: Icons.edit_note_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final i in kCheckInInstruments) ...[
            _InstrumentRow(instrument: i, history: recent),
            const SizedBox(height: RakiaSpacing.lg),
          ],
          Text(
            'These are your own answers, shown as you gave them. RAKIA does not '
            'score, interpret or diagnose them.',
            style: t.bodySmall?.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: RakiaSpacing.lg),
          _History(checkIns: checkIns.take(10).toList()),
        ],
      ),
    );
  }
}

/// One instrument: the latest answer and the recent answers as a trace.
class _InstrumentRow extends StatelessWidget {
  const _InstrumentRow({required this.instrument, required this.history});

  final Instrument instrument;

  /// Oldest first.
  final List<CheckIn> history;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    final values = [for (final h in history) h.valueOf(instrument)];
    final latest = values.last;
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    final summary =
        '${instrument.title}: latest $latest of ${instrument.max}, '
        '${instrument.label(latest)}. Over your last ${values.length} '
        'check-ins the answers ranged from $low to $high.';
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          instrument.title,
          style: t.labelLarge?.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$latest',
                style: RakiaType.metric(t.titleLarge ?? const TextStyle()),
              ),
              TextSpan(
                text: ' of ${instrument.max}  ',
                style: t.bodySmall?.copyWith(color: c.textSecondary),
              ),
              TextSpan(text: instrument.label(latest), style: t.bodyMedium),
            ],
          ),
        ),
      ],
    );
    final trace = SizedBox(
      height: 40,
      child: CustomPaint(
        painter: _TracePainter(
          values: values,
          min: instrument.min,
          max: instrument.max,
          line: c.brandText,
          grid: c.borderSubtle,
        ),
      ),
    );
    return Semantics(
      container: true,
      label: summary,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth >= 560
            ? Row(
                children: [
                  Expanded(flex: 3, child: text),
                  const SizedBox(width: RakiaSpacing.lg),
                  Expanded(flex: 2, child: trace),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  text,
                  const SizedBox(height: RakiaSpacing.sm),
                  trace,
                ],
              ),
      ),
    );
  }
}

class _TracePainter extends CustomPainter {
  _TracePainter({
    required this.values,
    required this.min,
    required this.max,
    required this.line,
    required this.grid,
  });

  final List<int> values;
  final int min;
  final int max;
  final Color line;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final g = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas
      ..drawLine(const Offset(0, 0.5), Offset(size.width, 0.5), g)
      ..drawLine(
        Offset(0, size.height - 0.5),
        Offset(size.width, size.height - 0.5),
        g,
      );
    double y(int v) => size.height - (v - min) / (max - min) * size.height;
    final dx = values.length > 1 ? size.width / (values.length - 1) : 0.0;
    final p = Paint()
      ..color = line
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final o = Offset(
        values.length > 1 ? i * dx : size.width / 2,
        y(values[i]),
      );
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(path, p);
    final dot = Paint()..color = line;
    final last = values.length - 1;
    canvas.drawCircle(
      Offset(values.length > 1 ? last * dx : size.width / 2, y(values[last])),
      3.5,
      dot,
    );
  }

  @override
  bool shouldRepaint(_TracePainter old) =>
      old.values != values || old.line != line || old.grid != grid;
}

class _History extends StatelessWidget {
  const _History({required this.checkIns});

  final List<CheckIn> checkIns;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Recent check-ins', style: t.titleSmall),
        const SizedBox(height: RakiaSpacing.sm),
        for (final ci in checkIns)
          Semantics(
            container: true,
            label:
                '${formatLocalDateTime(ci.recordedAt)}: sleepiness '
                '${ci.sleepiness} of 9, stress ${ci.stress} of 5, mood '
                '${ci.mood} of 5',
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: RakiaSpacing.sm),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.borderSubtle)),
              ),
              child: Wrap(
                spacing: RakiaSpacing.lg,
                runSpacing: RakiaSpacing.xs,
                children: [
                  SizedBox(
                    width: 170,
                    child: Text(
                      formatLocalDateTime(ci.recordedAt),
                      style: RakiaType.metric(t.bodySmall ?? const TextStyle())
                          .copyWith(color: c.textSecondary),
                    ),
                  ),
                  Text('Sleepiness ${ci.sleepiness}/9', style: t.bodySmall),
                  Text('Stress ${ci.stress}/5', style: t.bodySmall),
                  Text('Mood ${ci.mood}/5', style: t.bodySmall),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ReactionTestsCard extends StatelessWidget {
  const _ReactionTestsCard({required this.tests});

  final List<ReactionTestResult> tests;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    return SurfaceCard(
      key: const Key('reaction-tests-card'),
      title: 'Reaction-time tests',
      subtitle: '${tests.length} completed',
      leadingIcon: Icons.timer_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final r in tests.take(10))
            Semantics(
              container: true,
              label: reactionSummary(r),
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: RakiaSpacing.sm),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.borderSubtle)),
                ),
                child: Wrap(
                  spacing: RakiaSpacing.lg,
                  runSpacing: RakiaSpacing.xs,
                  children: [
                    SizedBox(
                      width: 170,
                      child: Text(
                        formatLocalDateTime(r.recordedAt),
                        style: RakiaType.metric(
                          t.bodySmall ?? const TextStyle(),
                        ).copyWith(color: c.textSecondary),
                      ),
                    ),
                    Text(
                      r.medianRtMs == null
                          ? 'No valid responses'
                          : 'Median ${r.medianRtMs!.round()} ms',
                      style: t.bodySmall,
                    ),
                    Text('Lapses ${r.lapses}', style: t.bodySmall),
                    Text('False starts ${r.falseStarts}', style: t.bodySmall),
                    Text(
                      r.device,
                      style: t.bodySmall?.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: RakiaSpacing.md),
          Text(
            'Response times include this device\'s screen and input delay, so '
            'compare a result only with earlier tests on the same device. A '
            'single slow test is not a finding; sleep, time of day and '
            'distraction all affect it.',
            style: t.bodySmall?.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Spoken summary of a test result.
String reactionSummary(ReactionTestResult r) =>
    '${formatLocalDateTime(r.recordedAt)}: '
    '${r.medianRtMs == null ? 'no valid responses' : 'median ${r.medianRtMs!.round()} milliseconds'}, '
    '${r.lapses} lapses, ${r.falseStarts} false starts, on ${r.device}';

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({required this.controller});

  final WellbeingController controller;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    return SurfaceCard(
      title: 'Your privacy',
      leadingIcon: Icons.lock_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Check-ins and test results stay on this device, in its encrypted '
            'local database where the platform supports it. They are not part '
            'of any mission and are not shared.',
            style: t.bodyMedium,
          ),
          const SizedBox(height: RakiaSpacing.lg),
          OutlinedButton.icon(
            key: const Key('delete-wellbeing'),
            style: OutlinedButton.styleFrom(foregroundColor: c.statusAct),
            onPressed: () => _confirmDelete(context),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete all check-ins and results'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final n = controller.checkIns.length;
    final m = controller.reactionTests.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all wellbeing records?'),
        content: Text(
          'This deletes $n ${n == 1 ? 'check-in' : 'check-ins'} and $m '
          '${m == 1 ? 'reaction-time result' : 'reaction-time results'} from '
          'this device. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-delete-wellbeing'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await controller.deleteAll();
  }
}
