// The astronaut: the gaze maths, the eyes following real pointer events
// (mouse hover and touch), smooth settling that stops animating, looking
// ahead when the pointer leaves, and the sign-in and dashboard placements.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakia/components/astronaut/astronaut.dart';
import 'package:rakia/components/astronaut/pointer_tracker.dart';
import 'package:rakia/features/crew_greeting.dart';

import 'account_fakes.dart';
import 'helpers.dart';

void main() {
  group('gaze', () {
    test('points towards the pointer, never further than 1', () {
      const c = Offset(100, 100);
      expect(gazeToward(c, c, 200), Offset.zero);
      final right = gazeToward(const Offset(1000, 100), c, 200);
      expect(right.dx, closeTo(1, 1e-9));
      expect(right.dy, 0);
      final up = gazeToward(const Offset(100, -1000), c, 200);
      expect(up.dx, 0);
      expect(up.dy, closeTo(-0.8, 1e-9)); // eyes travel less vertically
      for (final p in [
        const Offset(-500, 900),
        const Offset(5000, -5000),
        const Offset(130, 90),
      ]) {
        expect(gazeToward(p, c, 200).distance, lessThanOrEqualTo(1 + 1e-9));
      }
    });

    test('near pointers give a gentle glance that grows with distance', () {
      const c = Offset.zero;
      final near = gazeToward(const Offset(20, 0), c, 200).dx;
      final mid = gazeToward(const Offset(150, 0), c, 200).dx;
      final far = gazeToward(const Offset(300, 0), c, 200).dx;
      expect(near, greaterThan(0));
      expect(near, lessThan(mid));
      expect(mid, lessThan(far));
    });

    test('smoothing is frame-rate independent and converges', () {
      var a = Offset.zero;
      for (var i = 0; i < 60; i++) {
        a = smoothToward(a, const Offset(1, 0), 1 / 60);
      }
      var b = Offset.zero;
      for (var i = 0; i < 30; i++) {
        b = smoothToward(b, const Offset(1, 0), 1 / 30);
      }
      expect(a.dx, closeTo(b.dx, 1e-9));
      expect(a.dx, greaterThan(0.99));
    });
  });

  Future<AstronautState> place(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: PointerTracker(
          child: Scaffold(body: Center(child: Astronaut(width: 200))),
        ),
      ),
    );
    return tester.state<AstronautState>(find.byType(Astronaut));
  }

  testWidgets('the eyes follow the mouse and then hold still', (tester) async {
    final state = await place(tester);
    expect(state.gaze, Offset.zero);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(780, 300));
    await mouse.moveTo(const Offset(790, 300));
    await tester.pump(const Duration(milliseconds: 16));
    final early = state.gaze;
    // Settles: the ticker stops, so pumpAndSettle returns.
    await tester.pumpAndSettle();
    expect(state.gaze.dx, greaterThan(early.dx));
    expect(state.gaze.dx, greaterThan(0.8));

    // Up and to the left: both components turn negative.
    await mouse.moveTo(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(state.gaze.dx, lessThan(0));
    expect(state.gaze.dy, lessThan(0));
  });

  testWidgets('a touch also draws the eyes, and leaving looks ahead', (
    tester,
  ) async {
    final state = await place(tester);
    await tester.tapAt(const Offset(400, 590));
    await tester.pumpAndSettle();
    expect(state.gaze.dy, greaterThan(0.3));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(780, 300));
    await tester.pumpAndSettle();
    await mouse.removePointer();
    await tester.pumpAndSettle();
    expect(state.gaze.distance, lessThan(0.01));
  });

  testWidgets('with reduced motion the eyes still follow, without easing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const PointerTracker(
              child: Scaffold(body: Center(child: Astronaut(width: 200))),
            ),
          ),
        ),
      ),
    );
    final state = tester.state<AstronautState>(find.byType(Astronaut));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(780, 300));
    await mouse.moveTo(const Offset(790, 300));
    // One frame: no easing under reduced motion.
    await tester.pump();
    expect(state.gaze.dx, greaterThan(0.8));
  });

  testWidgets('the sign-in page shows the astronaut beside the form, and on '
      'a phone above it', (tester) async {
    final fb = FakeFirebase();
    final account = controllerFor(fb, FakeApi());
    addTearDown(account.dispose);
    await pumpRakia(tester, location: '/account', account: account);
    final window = tester.getRect(find.byKey(const Key('login-astronaut')));
    final form = tester.getRect(find.byKey(const Key('account-signed-out')));
    expect(window.right, lessThanOrEqualTo(form.left));

    await pumpRakia(
      tester,
      location: '/account',
      account: account,
      size: const Size(390, 844),
    );
    final w2 = tester.getRect(find.byKey(const Key('login-astronaut')));
    final f2 = tester.getRect(find.byKey(const Key('account-signed-out')));
    expect(w2.bottom, lessThanOrEqualTo(f2.top));
    expect(find.text('Welcome aboard'), findsOneWidget);
  });

  testWidgets('the dashboard greets with the astronaut and honest status', (
    tester,
  ) async {
    await pumpRakia(tester);
    expect(find.byKey(const Key('crew-greeting')), findsOneWidget);
    expect(find.byType(Astronaut), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('greeting-status'))).data,
      'No readings recorded yet.',
    );
  });

  test('greetings follow the time of day', () {
    expect(
      CrewGreetingCard.greetingFor(DateTime(2026, 1, 1, 8)),
      'Good morning',
    );
    expect(
      CrewGreetingCard.greetingFor(DateTime(2026, 1, 1, 14)),
      'Good afternoon',
    );
    expect(
      CrewGreetingCard.greetingFor(DateTime(2026, 1, 1, 21)),
      'Good evening',
    );
    expect(
      CrewGreetingCard.greetingFor(DateTime(2026, 1, 1, 2)),
      'Good evening',
    );
  });
}
