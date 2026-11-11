import 'package:flutter/material.dart';

import '../account/account_controller.dart';
import '../components/astronaut/mission_window.dart';
import '../design/colors.dart';
import '../design/neumorphism.dart';
import '../design/tokens.dart';
import '../environment/space_weather.dart';
import '../record/record_controller.dart';

/// The top of the Mission overview: the astronaut, a greeting and one line
/// on where things stand, from the astronaut's own record and the live
/// space weather. Nothing here is invented: each part says when it has no
/// data.
class CrewGreetingCard extends StatelessWidget {
  const CrewGreetingCard({super.key, this.now});

  /// Defaults to the device clock (tests supply one).
  final DateTime? now;

  static String greetingFor(DateTime local) {
    final h = local.hour;
    if (h < 5) return 'Good evening';
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = RakiaColors.of(context);
    final account = AccountScope.of(context);
    final record = RecordScope.of(context);
    final sw = SpaceWeatherScope.of(context);

    final email = account.status == AccountStatus.signedIn
        ? account.session?.email
        : null;
    final alerts = record.alerts.length;
    final storm = sw.snapshot;
    final parts = <String>[
      if (!record.hasEntries)
        'No readings recorded yet'
      else if (alerts == 0)
        'No alerts on your readings'
      else
        '$alerts ${alerts == 1 ? 'alert' : 'alerts'} on your readings',
      if (storm != null)
        storm.stormLevel == 0
            ? 'no radiation storm'
            : 'radiation storm ${StormLevel.all[storm.stormLevel].name}',
    ];

    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth < 520;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              email == null
                  ? greetingFor((now ?? DateTime.now()).toLocal())
                  : '${greetingFor((now ?? DateTime.now()).toLocal())}, $email',
              style: compact ? t.titleMedium : t.titleLarge,
            ),
            const SizedBox(height: RakiaSpacing.xs),
            Text(
              key: const Key('greeting-status'),
              '${parts.join('; ')}.',
              style: t.bodyMedium?.copyWith(color: c.textSecondary),
            ),
          ],
        );
        final window = SizedBox(
          width: compact ? 112 : 140,
          child: MissionWindow(
            astronautWidth: compact ? 84 : 104,
            padding: const EdgeInsets.all(RakiaSpacing.sm + 2),
          ),
        );
        return NeuSurface(
          key: const Key('crew-greeting'),
          radius: RakiaRadii.md,
          padding: const EdgeInsets.all(RakiaSpacing.lg),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    window,
                    const SizedBox(height: RakiaSpacing.md),
                    text,
                  ],
                )
              : Row(
                  children: [
                    window,
                    const SizedBox(width: RakiaSpacing.xl),
                    Expanded(child: text),
                  ],
                ),
        );
      },
    );
  }
}
