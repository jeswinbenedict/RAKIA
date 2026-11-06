import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakia/app.dart';
import 'package:rakia/app_settings.dart';
import 'package:rakia/components/simulation_banner.dart';
import 'package:rakia/components/surface_card.dart';
import 'package:rakia/mission/mission_controller.dart';
import 'package:rakia_core/rakia_core.dart';

import 'helpers.dart';

Future<MissionController> _running(WidgetTester tester) async {
  final core = await tester.runAsync(loadRakiaCore);
  final mission = MissionController();
  await mission.startSimulation(core!);
  return mission;
}

void main() {
  testWidgets('the simulation starts only when the user asks', (tester) async {
    await pumpRakia(tester, size: const Size(1280, 900));
    expect(find.text('No active mission'), findsOneWidget);
    expect(find.byKey(const Key('simulation-banner')), findsNothing);

    await tester.tap(find.byKey(const Key('start-simulation')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('simulation-banner')), findsOneWidget);
    expect(find.text('Simulation mission SIM-01'), findsOneWidget);
    expect(find.text('SIMULATED DATA'), findsWidgets);
    expect(
      find.byKey(const Key('metric-card-heart_rate.resting')),
      findsOneWidget,
    );

    // Ending it from the banner returns to the honest empty state.
    await tester.tap(
      find.descendant(
        of: find.byType(SimulationBanner),
        matching: find.byType(TextButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('simulation-banner')), findsNothing);
    expect(find.text('No active mission'), findsOneWidget);
  });

  testWidgets('the start action is disabled, with a reason, without the core', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RakiaApp(
        settings: AppSettingsController(ThemeMode.dark),
        coreLoader: () => Future.error(StateError('no module')),
      ),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<ButtonStyleButton>(
      find.byKey(const Key('start-simulation')),
    );
    expect(button.onPressed, isNull);
    expect(
      find.textContaining('analytics core is unavailable'),
      findsOneWidget,
    );
  });

  testWidgets('Action center explains each alert in six parts', (tester) async {
    final mission = await _running(tester);
    await pumpRakia(
      tester,
      size: const Size(1440, 1000),
      location: '/actions',
      mission: mission,
    );
    expect(find.byKey(const Key('alert-heart_rate.resting')), findsOneWidget);
    expect(find.byKey(const Key('alert-sleep.duration')), findsOneWidget);
    for (final part in [
      'WHAT CHANGED',
      'BY HOW MUCH',
      'SINCE WHEN',
      'FROM WHICH READINGS',
      'WHY IT MATTERS',
      'WHAT TO CHECK NEXT',
    ]) {
      expect(find.text(part), findsNWidgets(2), reason: part);
    }
    expect(find.textContaining('it does not diagnose'), findsOneWidget);
  });

  testWidgets('monitoring modules show their indicators in detail', (
    tester,
  ) async {
    final mission = await _running(tester);
    await pumpRakia(
      tester,
      size: const Size(1440, 1000),
      location: '/cardio',
      mission: mission,
    );
    for (final code in ['heart_rate.resting', 'hrv.rmssd', 'spo2']) {
      expect(find.byKey(Key('metric-detail-$code')), findsOneWidget);
    }
    expect(find.text('SIMULATION GROUND TRUTH'), findsWidgets);

    await tester.tap(find.text('Sleep & circadian').first);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('metric-detail-sleep.duration')),
      findsOneWidget,
    );

    // Modules the simulation does not cover keep their empty state.
    await tester.tap(find.text('Behavioural health').first);
    await tester.pumpAndSettle();
    expect(find.text('No check-ins yet'), findsOneWidget);
  });

  testWidgets('Data management shows provenance and quality', (tester) async {
    final mission = await _running(tester);
    await pumpRakia(
      tester,
      size: const Size(1440, 1000),
      location: '/data',
      mission: mission,
    );
    expect(find.text('RAKIA simulator (on this device)'), findsOneWidget);
    expect(find.text('Provenance: simulated'), findsOneWidget);
    // 525 mission and reference days, 16 of them without a recording.
    expect(find.text('509 daily readings across 5 indicators'), findsOneWidget);
    expect(find.text('27 / 45'), findsOneWidget); // sleep, below the gate
    await tester.tap(find.byKey(const Key('end-simulation')));
    await tester.pumpAndSettle();
    expect(mission.isActive, isFalse);
  });

  for (final vp in kViewports.entries) {
    testWidgets('dashboard fits ${vp.key} without overflow', (tester) async {
      final mission = await _running(tester);
      for (final location in ['/mission', '/actions', '/cardio', '/data']) {
        await pumpRakia(
          tester,
          size: vp.value,
          location: location,
          mission: mission,
        );
        expect(tester.takeException(), isNull, reason: location);
        for (final e
            in find
                .byType(SurfaceCard)
                .evaluate()
                .followedBy(
                  find.byKey(const Key('simulation-banner')).evaluate(),
                )) {
          final box = e.renderObject! as RenderBox;
          final left = box.localToGlobal(Offset.zero).dx;
          expect(left, greaterThanOrEqualTo(0), reason: location);
          expect(
            left + box.size.width,
            lessThanOrEqualTo(vp.value.width + 0.01),
            reason: location,
          );
        }
      }
      // Indicator cards stay inside the viewport.
      await pumpRakia(tester, size: vp.value, mission: mission);
      for (final code in ['heart_rate.resting', 'exercise.duration']) {
        final finder = find.byKey(Key('metric-card-$code'));
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        final r = tester.getRect(finder);
        expect(r.left, greaterThanOrEqualTo(0), reason: code);
        expect(r.right, lessThanOrEqualTo(vp.value.width), reason: code);
      }
    });
  }

  for (final theme in const [ThemeMode.dark, ThemeMode.light]) {
    for (final location in const ['/mission', '/actions', '/cardio', '/data']) {
      testWidgets('a11y guidelines with simulation: ${theme.name}, $location', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final mission = await _running(tester);
        await pumpRakia(
          tester,
          size: const Size(1280, 900),
          themeMode: theme,
          location: location,
          mission: mission,
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  }

  testWidgets('200% text scale with simulation lays out without overflow', (
    tester,
  ) async {
    final mission = await _running(tester);
    for (final vp in kViewports.values) {
      for (final location in ['/mission', '/actions', '/cardio']) {
        await pumpRakia(
          tester,
          size: vp,
          textScale: 2,
          location: location,
          mission: mission,
        );
        expect(tester.takeException(), isNull, reason: '$vp $location');
      }
    }
  });

  testWidgets('charts describe themselves to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    final mission = await _running(tester);
    await pumpRakia(
      tester,
      size: const Size(1440, 1000),
      location: '/cardio',
      mission: mission,
    );
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'^Chart of resting heart rate over 45 mission days\. Expected '
          r'range .* Estimated onset mission day 28\. Simulated data\.$',
        ),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}
