import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  for (final theme in const [ThemeMode.dark, ThemeMode.light]) {
    for (final vp in kViewports.entries) {
      for (final location in const ['/mission', '/environment', '/about']) {
        testWidgets('a11y guidelines: ${theme.name}, ${vp.key}, $location', (
          tester,
        ) async {
          final handle = tester.ensureSemantics();
          await pumpRakia(
            tester,
            size: vp.value,
            themeMode: theme,
            location: location,
          );
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          handle.dispose();
        });
      }
    }
  }

  for (final vp in kViewports.entries) {
    testWidgets('200% text scaling lays out without overflow: ${vp.key}', (
      tester,
    ) async {
      for (final location in const ['/mission', '/behavioural', '/about']) {
        await pumpRakia(
          tester,
          size: vp.value,
          textScale: 2.0,
          location: location,
        );
        expect(tester.takeException(), isNull, reason: location);
      }
    });
  }

  testWidgets('page heading and status words are exposed to screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpRakia(tester, location: '/about');
    expect(
      tester.getSemantics(find.text('About RAKIA').last),
      matchesSemantics(label: 'About RAKIA', isHeader: true),
    );
    // Off-screen semantics are culled, so bring the examples into view.
    await tester.ensureVisible(find.text('Act now'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Status: Act now'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Simulated data')), findsOneWidget);
    handle.dispose();
  });
}
