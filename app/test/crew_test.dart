// The sign-in page after the owner's reference: the 3D crew fills the large
// left area (above the card on phones), the card has the password toggle
// and the forgot-password and create-account links. Widget tests run on the
// VM, where the crew falls back to a still panel; the WebGL scene itself is
// checked in a browser (see the PR).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakia/components/crew/crew_scene.dart';
import 'package:rakia/features/crew_greeting.dart';

import 'account_fakes.dart';
import 'helpers.dart';

void main() {
  Future<void> openSignIn(WidgetTester tester, {Size? size}) async {
    final account = controllerFor(FakeFirebase(), FakeApi());
    addTearDown(account.dispose);
    await pumpRakia(
      tester,
      location: '/account',
      account: account,
      size: size ?? const Size(1440, 900),
    );
  }

  testWidgets('on a wide window the crew fills the left and the card stands '
      'on the right', (tester) async {
    await openSignIn(tester);
    final crew = tester.getRect(find.byKey(const Key('login-crew')));
    final card = tester.getRect(find.byKey(const Key('account-signed-out')));
    expect(crew.right, lessThan(card.left));
    expect(crew.width, greaterThan(card.width));
    expect(crew.height, greaterThanOrEqualTo(520));
    expect(find.byType(CrewScene), findsOneWidget);
    expect(find.byKey(const Key('crew-fallback')), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('on a phone the crew sits above the card, uncropped', (
    tester,
  ) async {
    await openSignIn(tester, size: const Size(390, 844));
    final crew = tester.getRect(find.byKey(const Key('login-crew')));
    final card = tester.getRect(find.byKey(const Key('account-signed-out')));
    expect(crew.bottom, lessThanOrEqualTo(card.top));
    expect(crew.height, greaterThanOrEqualTo(260));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the password can be shown and hidden', (tester) async {
    await openSignIn(tester);
    EditableText field() => tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('account-password')),
        matching: find.byType(EditableText),
      ),
    );
    expect(field().obscureText, isTrue);
    await tester.tap(find.byKey(const Key('account-password-visibility')));
    await tester.pump();
    expect(field().obscureText, isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);
    await tester.tap(find.byKey(const Key('account-password-visibility')));
    await tester.pump();
    expect(field().obscureText, isTrue);
  });

  testWidgets('forgot password and create account switch the card', (
    tester,
  ) async {
    await openSignIn(tester);
    await tester.tap(find.byKey(const Key('account-mode-reset')));
    await tester.pumpAndSettle();
    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.byKey(const Key('account-password')), findsNothing);
    await tester.tap(find.byKey(const Key('account-mode-signin')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-mode-create')));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Already have an account?'), findsOneWidget);
  });

  testWidgets('the dashboard greets with the compact crew and honest status', (
    tester,
  ) async {
    await pumpRakia(tester);
    expect(find.byKey(const Key('crew-greeting')), findsOneWidget);
    expect(find.byType(CrewScene), findsOneWidget);
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
