import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakia/components/empty_state.dart';
import 'package:rakia/components/health_status.dart';
import 'package:rakia/components/simulated_data_badge.dart';
import 'package:rakia/design/colors.dart';
import 'package:rakia/design/theme.dart';
import 'package:rakia/design/tokens.dart';

Widget _wrap(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: buildRakiaTheme(Brightness.dark),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  test('health statuses mirror librakia levels in order', () {
    // rakia_level: INSUFFICIENT_DATA=0, DATA_QUALITY=1, WITHIN_BASELINE=2,
    // WATCH=3, ACT=4.
    expect(HealthStatus.values.map((s) => s.name).toList(), [
      'insufficientData',
      'dataQuality',
      'withinBaseline',
      'watch',
      'act',
    ]);
  });

  test('each status has a distinct word and colour', () {
    final words = HealthStatus.values.map((s) => s.label).toSet();
    final colours = HealthStatus.values
        .map((s) => s.color(RakiaColors.dark))
        .toSet();
    expect(words.length, HealthStatus.values.length);
    expect(colours.length, HealthStatus.values.length);
  });

  for (final status in HealthStatus.values) {
    testWidgets('StatusChip shows glyph and word for ${status.name}', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(StatusChip(status: status)));
      expect(find.text(status.label), findsOneWidget);
      expect(find.byType(StatusGlyph), findsOneWidget);
      expect(find.bySemanticsLabel('Status: ${status.label}'), findsOneWidget);
      handle.dispose();
    });
  }

  testWidgets('SimulatedDataBadge is labelled for sight and screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(const SimulatedDataBadge()));
    expect(find.text('SIMULATED DATA'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Simulated data. These values are not real measurements.',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('EmptyState renders title, message and optional action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        EmptyState(
          icon: Icons.storage,
          title: 'No data',
          message: 'Connect a source.',
          action: FilledButton(onPressed: () {}, child: const Text('Connect')),
        ),
      ),
    );
    expect(find.text('No data'), findsOneWidget);
    expect(find.text('Connect a source.'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });

  for (final reduce in const [false, true]) {
    testWidgets('motion durations honour reduced motion = $reduce', (
      tester,
    ) async {
      late Duration d;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              d = RakiaMotion.of(context, RakiaMotion.surfaceEnter);
              return const SizedBox();
            },
          ),
          reduceMotion: reduce,
        ),
      );
      expect(d, reduce ? Duration.zero : RakiaMotion.surfaceEnter);
    });
  }
}
