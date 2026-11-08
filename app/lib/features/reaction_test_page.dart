import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../components/surface_card.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../wellbeing/format.dart';
import '../wellbeing/instruments.dart';
import '../wellbeing/pvt.dart';
import '../wellbeing/wellbeing_controller.dart';
import 'page_frame.dart';
import 'simulation_controls.dart';

/// A 3-minute psychomotor vigilance test (after PVT-B). Nothing is saved
/// unless the astronaut chooses to after seeing the result.
class ReactionTestPage extends StatefulWidget {
  const ReactionTestPage({super.key, this.clock, this.random, this.duration});

  /// Monotonic time; a stopwatch by default. Tests supply their own.
  final Duration Function()? clock;
  final Random? random;

  /// Test length; [Pvt.duration] by default.
  final Duration? duration;

  @override
  State<ReactionTestPage> createState() => _ReactionTestPageState();
}

enum _Stage { intro, running, result }

class _ReactionTestPageState extends State<ReactionTestPage>
    with SingleTickerProviderStateMixin {
  late final Stopwatch _stopwatch = Stopwatch()..start();
  late final Ticker _ticker = createTicker(_onTick);
  final FocusNode _focus = FocusNode(debugLabel: 'reaction-test-area');
  _Stage _stage = _Stage.intro;
  PvtSession? _session;
  ReactionTestResult? _result;
  bool _saving = false;
  String? _error;

  Duration _now() => widget.clock?.call() ?? _stopwatch.elapsed;

  @override
  void dispose() {
    _ticker.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _start() {
    final s = PvtSession(
      clock: _now,
      random: widget.random,
      duration: widget.duration ?? Pvt.duration,
    )..start();
    setState(() {
      _session = s;
      _stage = _Stage.running;
    });
    _ticker.start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _onTick(Duration _) {
    final s = _session;
    if (s == null) return;
    if (s.tick()) {
      _finish();
      return;
    }
    if (s.stimulusDue) {
      // The stimulus counts from the moment the frame showing it is drawn.
      setState(() {});
      SchedulerBinding.instance.addPostFrameCallback((_) => s.stimulusShown());
      return;
    }
    // Redraw for the running counter and the progress bar.
    setState(() {});
  }

  void _respond() {
    final s = _session;
    if (_stage != _Stage.running || s == null) return;
    s.respond();
    if (s.phase == PvtPhase.finished) {
      _finish();
    } else {
      setState(() {});
    }
  }

  void _finish() {
    _ticker.stop();
    setState(() {
      _result = _session!.result(
        recordedAt: DateTime.now(),
        device: _deviceDescription(context),
      );
      _stage = _Stage.result;
    });
  }

  void _abort() {
    _ticker.stop();
    context.go('/behavioural');
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await WellbeingScope.of(context).addReactionTest(_result!);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Test result saved.')));
      context.go('/behavioural');
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'The result could not be saved: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Reaction-time test',
      eyebrow: 'Behavioural health',
      summary:
          'A 3-minute vigilance task. Respond as quickly as you can whenever '
          'the counter appears.',
      body: switch (_stage) {
        _Stage.intro => _Intro(onStart: _start),
        _Stage.running => _Running(
          session: _session!,
          focus: _focus,
          onRespond: _respond,
          onStop: _abort,
        ),
        _Stage.result => _Result(
          result: _result!,
          saving: _saving,
          error: _error,
          onSave: _save,
          onDiscard: () => context.go('/behavioural'),
        ),
      },
    );
  }
}

String _deviceDescription(BuildContext context) {
  final shortest = MediaQuery.sizeOf(context).shortestSide;
  final form = shortest < 600
      ? 'phone'
      : shortest < 900
      ? 'tablet'
      : 'desktop';
  final platform = switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iOS',
    TargetPlatform.macOS => 'macOS',
    TargetPlatform.windows => 'Windows',
    TargetPlatform.linux => 'Linux',
    TargetPlatform.fuchsia => 'Fuchsia',
  };
  return kIsWeb ? 'Web on $platform, $form' : '$platform $form';
}

class _Intro extends StatelessWidget {
  const _Intro({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    return SurfaceCard(
      title: 'Before you start',
      leadingIcon: Icons.info_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in const [
            'Find a quiet moment: the test takes 3 minutes without breaks.',
            'Watch the response area. When a counter appears, tap or click '
                'it, or press Space or Enter, as fast as you can.',
            'Do not respond before the counter appears; early responses are '
                'counted as false starts.',
            'Use the same device each time: results compare only with '
                'earlier tests on the same device.',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: RakiaSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Icon(Icons.circle, size: 6, color: c.brandText),
                    ),
                  ),
                  const SizedBox(width: RakiaSpacing.sm),
                  Expanded(child: Text(line, style: t.bodyMedium)),
                ],
              ),
            ),
          const SizedBox(height: RakiaSpacing.sm),
          Text(
            'After the 3-minute brief psychomotor vigilance test (PVT-B; '
            'Basner, Mollicone and Dinges, 2011), a short form of the test '
            'used in spaceflight research. The task needs sight of the screen.',
            style: t.bodySmall?.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: RakiaSpacing.lg),
          Wrap(
            spacing: RakiaSpacing.md,
            runSpacing: RakiaSpacing.md,
            children: [
              FilledButton.icon(
                key: const Key('begin-reaction-test'),
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start the test'),
              ),
              TextButton(
                onPressed: () => context.go('/behavioural'),
                child: const Text('Back'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Running extends StatelessWidget {
  const _Running({
    required this.session,
    required this.focus,
    required this.onRespond,
    required this.onStop,
  });

  final PvtSession session;
  final FocusNode focus;
  final VoidCallback onRespond;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    final showing = session.phase == PvtPhase.stimulus || session.stimulusDue;
    final progress =
        session.elapsed.inMilliseconds / session.duration.inMilliseconds;
    final height = (MediaQuery.sizeOf(context).height * 0.45).clamp(
      240.0,
      520.0,
    );
    final last = session.lastResponseMs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                semanticsLabel: 'Test progress',
              ),
            ),
            const SizedBox(width: RakiaSpacing.md),
            Text(
              '${formatMinutesSeconds(session.remaining)} left',
              style: RakiaType.metric(t.bodyMedium ?? const TextStyle()),
            ),
          ],
        ),
        const SizedBox(height: RakiaSpacing.lg),
        Focus(
          focusNode: focus,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.space ||
                    event.logicalKey == LogicalKeyboardKey.enter)) {
              onRespond();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Semantics(
            label: 'Response area. Respond when the counter appears.',
            button: true,
            child: Listener(
              key: const Key('reaction-area'),
              behavior: HitTestBehavior.opaque,
              // Pointer down, not tap up: the earliest moment of a response.
              onPointerDown: (_) => onRespond(),
              child: Container(
                height: height,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.surface2,
                  borderRadius: BorderRadius.circular(RakiaRadii.md),
                  border: Border.all(
                    color: showing ? c.action : c.borderSubtle,
                    width: showing ? 2 : 1,
                  ),
                ),
                child: showing
                    ? Text(
                        '${session.stimulusElapsedMs}',
                        key: const Key('reaction-stimulus'),
                        style: RakiaType.metric(
                          t.displayMedium ?? const TextStyle(),
                        ).copyWith(color: c.action),
                      )
                    : Text(
                        last == null ? 'Wait for the counter' : '$last ms',
                        key: const Key('reaction-wait'),
                        style: last == null
                            ? t.titleMedium?.copyWith(color: c.textSecondary)
                            : RakiaType.metric(
                                t.headlineSmall ?? const TextStyle(),
                              ).copyWith(color: c.textSecondary),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: RakiaSpacing.lg),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('stop-reaction-test'),
            onPressed: onStop,
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Stop without saving'),
          ),
        ),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.result,
    required this.saving,
    required this.error,
    required this.onSave,
    required this.onDiscard,
  });

  final ReactionTestResult result;
  final bool saving;
  final String? error;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    final facts = [
      ('Stimuli', '${result.stimuli}'),
      ('Valid responses', '${result.responses}'),
      (
        'Median response time',
        result.medianRtMs == null ? '-' : '${result.medianRtMs!.round()} ms',
      ),
      (
        'Mean response speed',
        result.meanSpeed == null
            ? '-'
            : '${result.meanSpeed!.toStringAsFixed(2)} per second',
      ),
      ('Lapses (355 ms or slower)', '${result.lapses}'),
      ('False starts', '${result.falseStarts}'),
    ];
    return SurfaceCard(
      key: const Key('reaction-result'),
      title: 'Your result',
      subtitle: result.device,
      leadingIcon: Icons.timer_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: RakiaSpacing.xl,
            runSpacing: RakiaSpacing.md,
            children: [
              for (final (label, value) in facts)
                Semantics(
                  container: true,
                  label: '$label: $value',
                  excludeSemantics: true,
                  child: SizedBox(
                    width: 200,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: t.labelMedium?.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          style: RakiaType.metric(
                            t.titleMedium ?? const TextStyle(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: RakiaSpacing.lg),
          Text(
            'Response times include this device\'s screen and input delay. '
            'Compare this result only with earlier tests on the same device; '
            'it is not a measure of fitness for duty.',
            style: t.bodySmall?.copyWith(color: c.textSecondary),
          ),
          if (error != null) ...[
            const SizedBox(height: RakiaSpacing.md),
            OperationError(message: error!),
          ],
          const SizedBox(height: RakiaSpacing.lg),
          Wrap(
            spacing: RakiaSpacing.md,
            runSpacing: RakiaSpacing.md,
            children: [
              FilledButton(
                key: const Key('save-reaction-test'),
                onPressed: saving ? null : onSave,
                child: Text(saving ? 'Saving' : 'Save result'),
              ),
              TextButton(
                key: const Key('discard-reaction-test'),
                onPressed: saving ? null : onDiscard,
                child: const Text('Discard'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
