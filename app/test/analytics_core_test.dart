import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakia/app.dart';
import 'package:rakia/app_settings.dart';
import 'package:rakia/core/analytics_core.dart';
import 'package:rakia_core/rakia_core.dart';

Future<void> _pumpAbout(
  WidgetTester tester, {
  AnalyticsCoreLoader? loader,
}) async {
  tester.view.physicalSize = const Size(1280, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RakiaApp(
      initialLocation: '/about',
      settings: AppSettingsController(ThemeMode.dark),
      coreLoader: loader,
    ),
  );
}

void main() {
  test('the native core passes the known-answer self-test', () async {
    final core = await loadRakiaCore();
    expect(core.backend, RakiaBackendKind.native);
    expect(runSelfTest(core).passed, isTrue);
  });

  testWidgets('About shows the running core and its self-test', (tester) async {
    await _pumpAbout(tester);
    await tester.pumpAndSettle();
    expect(
      find.text('librakia 0.1.0, running natively on this device'),
      findsOneWidget,
    );
    expect(find.textContaining('Self-test passed'), findsOneWidget);
  });

  testWidgets('a loading core is reported as loading', (tester) async {
    final pending = Completer<RakiaCore>();
    await _pumpAbout(tester, loader: () => pending.future);
    await tester.pump();
    expect(find.text('Loading the analytics core…'), findsOneWidget);
    pending.complete(loadRakiaCore());
    await tester.pumpAndSettle();
    expect(find.textContaining('running natively'), findsOneWidget);
  });

  testWidgets('a core that fails to load is reported, not hidden', (
    tester,
  ) async {
    await _pumpAbout(
      tester,
      loader: () => Future.error(StateError('module missing')),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Unavailable, so analytics cannot run'),
      findsOneWidget,
    );
    expect(find.textContaining('module missing'), findsOneWidget);
  });
}
