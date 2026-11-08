import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../components/surface_card.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../wellbeing/instruments.dart';
import '../wellbeing/wellbeing_controller.dart';
import 'page_frame.dart';
import 'simulation_controls.dart';

/// Three short self-report questions. Nothing is saved until every question
/// is answered and the astronaut chooses to save.
class CheckInPage extends StatefulWidget {
  const CheckInPage({super.key});

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  final Map<String, int> _answers = {};
  bool _saving = false;
  String? _error;

  bool get _complete =>
      kCheckInInstruments.every((i) => _answers.containsKey(i.id));

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await WellbeingScope.of(context).addCheckIn(
        sleepiness: _answers['sleepiness']!,
        stress: _answers['stress']!,
        mood: _answers['mood']!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Check-in saved.')));
      context.go('/behavioural');
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'The check-in could not be saved: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    final missing = kCheckInInstruments.length - _answers.length;
    return PageFrame(
      title: 'Check-in',
      eyebrow: 'Behavioural health',
      summary:
          'Three short questions about how you feel right now. Your answers '
          'stay on this device.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final i in kCheckInInstruments) ...[
            _Question(
              instrument: i,
              value: _answers[i.id],
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _answers[i.id] = v),
            ),
            const SizedBox(height: RakiaSpacing.lg),
          ],
          if (_error != null) ...[
            OperationError(message: _error!),
            const SizedBox(height: RakiaSpacing.md),
          ],
          Wrap(
            spacing: RakiaSpacing.md,
            runSpacing: RakiaSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton(
                key: const Key('save-check-in'),
                onPressed: _complete && !_saving ? _save : null,
                child: Text(_saving ? 'Saving' : 'Save check-in'),
              ),
              TextButton(
                key: const Key('cancel-check-in'),
                onPressed: _saving ? null : () => context.go('/behavioural'),
                child: const Text('Cancel'),
              ),
              if (!_complete)
                Text(
                  missing == 1
                      ? 'Answer the remaining question to save.'
                      : 'Answer the remaining $missing questions to save.',
                  style: t.bodySmall?.copyWith(color: c.textSecondary),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({
    required this.instrument,
    required this.value,
    required this.onChanged,
  });

  final Instrument instrument;
  final int? value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    return SurfaceCard(
      key: Key('question-${instrument.id}'),
      title: instrument.title,
      subtitle: instrument.validated
          ? 'Validated instrument'
          : 'Self-rating, not a validated scale',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(instrument.question, style: t.bodyLarge),
          const SizedBox(height: RakiaSpacing.sm),
          RadioGroup<int>(
            groupValue: value,
            onChanged: (v) {
              if (v != null) onChanged?.call(v);
            },
            // Its own Material, so the rows' ink and focus highlight draw
            // above the card's background instead of under it.
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  for (var v = instrument.min; v <= instrument.max; v++)
                    RadioListTile<int>(
                      key: Key('answer-${instrument.id}-$v'),
                      value: v,
                      enabled: onChanged != null,
                      contentPadding: EdgeInsets.zero,
                      title: Text('$v  ${instrument.label(v)}'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: RakiaSpacing.sm),
          Text(
            instrument.source,
            style: t.bodySmall?.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
