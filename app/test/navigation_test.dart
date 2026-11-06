import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakia/navigation/modules.dart';

import 'helpers.dart';

void main() {
  testWidgets('compact width uses a bottom bar', (tester) async {
    await pumpRakia(tester, size: const Size(390, 844));
    expect(find.byKey(const Key('nav-compact')), findsOneWidget);
    expect(find.byKey(const Key('nav-rail')), findsNothing);
    expect(find.byKey(const Key('nav-sidebar')), findsNothing);
  });

  testWidgets('medium width uses an icon rail', (tester) async {
    await pumpRakia(tester, size: const Size(800, 1100));
    expect(find.byKey(const Key('nav-rail')), findsOneWidget);
    expect(find.byKey(const Key('nav-compact')), findsNothing);
  });

  for (final size in const [Size(1280, 800), Size(1600, 1000)]) {
    testWidgets('wide width ${size.width} uses a labelled sidebar', (
      tester,
    ) async {
      await pumpRakia(tester, size: size);
      expect(find.byKey(const Key('nav-sidebar')), findsOneWidget);
      expect(find.text('MONITORING'), findsOneWidget);
    });
  }

  testWidgets('sidebar navigates to every module', (tester) async {
    await pumpRakia(tester, size: const Size(1600, 1000));
    for (final m in kModules) {
      final entry = find.descendant(
        of: find.byKey(const Key('nav-sidebar')),
        matching: find.text(m.label),
      );
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.text(m.emptyTitle), findsOneWidget, reason: m.id);
    }
  });

  testWidgets('compact "More" sheet reaches secondary modules', (tester) async {
    await pumpRakia(tester, size: const Size(390, 844));
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nav-more-sheet')), findsOneWidget);
    await tester.tap(find.text('Radiation & environment'));
    await tester.pumpAndSettle();
    expect(find.text('No dosimetry or environment data yet'), findsOneWidget);
    // "More" stays selected for modules that live in the sheet.
    final bar = tester.widget<NavigationBar>(
      find.byKey(const Key('nav-compact')),
    );
    expect(bar.selectedIndex, 4);
  });

  testWidgets('unknown routes show a recoverable not-found page', (
    tester,
  ) async {
    await pumpRakia(tester, location: '/no-such-page');
    expect(find.text('Page not found'), findsOneWidget);
    await tester.tap(find.text('Go to mission overview'));
    await tester.pumpAndSettle();
    expect(find.text('No active mission'), findsOneWidget);
  });

  testWidgets('theme can be switched from About', (tester) async {
    await pumpRakia(tester, size: const Size(1280, 800), location: '/about');
    final context = tester.element(find.text('About RAKIA').first);
    expect(Theme.of(context).brightness, Brightness.dark);
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    final after = tester.element(find.text('About RAKIA').first);
    expect(Theme.of(after).brightness, Brightness.light);
  });
}
