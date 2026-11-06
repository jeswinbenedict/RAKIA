import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../components/health_status.dart';
import '../components/simulated_data_badge.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import 'page_frame.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    final t = Theme.of(context).textTheme;
    final settings = AppSettings.of(context);

    Widget section(String title, List<Widget> children) => Card(
      child: Padding(
        padding: const EdgeInsets.all(RakiaSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text(title, style: t.titleSmall)),
            const SizedBox(height: RakiaSpacing.md),
            ...children,
          ],
        ),
      ),
    );

    return PageFrame(
      title: 'About RAKIA',
      eyebrow: 'RAKIA',
      summary:
          'Open-source astronaut health intelligence for long-duration missions, '
          'built for the NASA Space Apps Challenge 2026.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          section('Important', [
            Text(
              'RAKIA is research software. It is not a medical device, it does '
              'not diagnose, and its anomaly detection is experimental and not '
              'clinically validated. It does not replace flight surgeons or '
              'medical professionals. RAKIA is not affiliated with or endorsed '
              'by NASA or any space agency.',
              style: t.bodyMedium,
            ),
          ]),
          const SizedBox(height: RakiaSpacing.lg),
          section('Appearance', [
            Text('Theme', style: t.labelLarge),
            const SizedBox(height: RakiaSpacing.sm),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ],
              selected: {settings.themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => settings.themeMode = s.first,
            ),
          ]),
          const SizedBox(height: RakiaSpacing.lg),
          section('How status is shown', [
            Text(
              'Every status uses a colour, a distinct shape and a word, so it '
              'never depends on colour alone.',
              style: t.bodyMedium?.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: RakiaSpacing.md),
            Wrap(
              spacing: RakiaSpacing.sm,
              runSpacing: RakiaSpacing.sm,
              children: [
                for (final s in HealthStatus.values) StatusChip(status: s),
                const SimulatedDataBadge(),
              ],
            ),
          ]),
          const SizedBox(height: RakiaSpacing.lg),
          section('Open source', [
            Text(
              'Licensed under the Apache License 2.0. Typeface: Geist and Geist '
              'Mono, SIL Open Font License 1.1.',
              style: t.bodyMedium,
            ),
            const SizedBox(height: RakiaSpacing.md),
            OutlinedButton(
              onPressed: () =>
                  showLicensePage(context: context, applicationName: 'RAKIA'),
              child: const Text('View licences'),
            ),
          ]),
        ],
      ),
    );
  }
}
