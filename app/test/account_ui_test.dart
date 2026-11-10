// The Account page: signing in and out, errors in words, password reset,
// account creation's bot check (shown only where Turnstile runs), the
// emulator notice, and accessibility and layout.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakia/account/account_controller.dart';

import 'account_fakes.dart';
import 'helpers.dart';

void main() {
  FakeFirebase firebase({bool verified = false}) => FakeFirebase()
    ..users['astro@example.test'] = (
      password: 'correct-horse',
      uid: 'uid-1',
      verified: verified,
    );

  AccountController controller(
    FakeFirebase fb,
    FakeApi api, {
    String emulatorHost = '',
  }) {
    final c = controllerFor(fb, api, emulatorHost: emulatorHost);
    addTearDown(c.dispose);
    return c;
  }

  Future<void> open(
    WidgetTester tester,
    AccountController c, {
    Size size = const Size(1280, 800),
    ThemeMode themeMode = ThemeMode.dark,
    double textScale = 1,
  }) async {
    await pumpRakia(
      tester,
      location: '/account',
      account: c,
      size: size,
      themeMode: themeMode,
      textScale: textScale,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> signIn(WidgetTester tester, String password) async {
    await tester.enterText(
      find.byKey(const Key('account-email')),
      'astro@example.test',
    );
    await tester.enterText(find.byKey(const Key('account-password')), password);
    await tapKey(tester, 'account-submit');
  }

  testWidgets('sign in, see the account, sign out', (tester) async {
    final api = FakeApi()..accounts.add('uid-1');
    await open(tester, controller(firebase(), api));
    expect(find.byKey(const Key('account-signed-out')), findsOneWidget);
    expect(find.textContaining('Signing in does not upload'), findsWidgets);

    await signIn(tester, 'correct-horse');
    expect(find.byKey(const Key('account-signed-in')), findsOneWidget);
    expect(find.text('astro@example.test'), findsOneWidget);
    expect(find.textContaining('Email not verified yet'), findsOneWidget);
    expect(find.textContaining('No mission roles yet'), findsOneWidget);
    // Backup is shown once signed in. This test build names no API, so
    // the switch is disabled and the page says why.
    expect(find.byKey(const Key('backup-card')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('backup-status'))).data,
      'Backup is not available in this build.',
    );
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('backup-switch')))
          .onChanged,
      isNull,
    );

    await tapKey(tester, 'account-sign-out');
    expect(find.byKey(const Key('account-signed-out')), findsOneWidget);
  });

  testWidgets('a wrong password is explained', (tester) async {
    await open(tester, controller(firebase(), FakeApi()));
    await signIn(tester, 'wrong');
    expect(
      tester.widget<Text>(find.byKey(const Key('account-error'))).data,
      'The email or password is not correct.',
    );
    expect(find.byKey(const Key('account-signed-in')), findsNothing);
  });

  testWidgets('outside the web app, account creation points to the web app', (
    tester,
  ) async {
    await open(tester, controller(firebase(), FakeApi()));
    await tapKey(tester, 'account-mode-create');
    expect(find.byKey(const Key('turnstile-unsupported')), findsOneWidget);
    expect(find.byKey(const Key('account-submit')), findsNothing);
  });

  testWidgets('password reset confirms without saying whether the account '
      'exists', (tester) async {
    final fb = firebase();
    await open(tester, controller(fb, FakeApi()));
    await tapKey(tester, 'account-mode-reset');
    await tester.enterText(
      find.byKey(const Key('account-email')),
      'astro@example.test',
    );
    await tapKey(tester, 'account-submit');
    expect(
      find.textContaining('If an account exists for astro@example.test'),
      findsOneWidget,
    );
    expect(fb.oobRequests.single['requestType'], 'PASSWORD_RESET');
  });

  testWidgets('a sign-in without a RAKIA account asks to finish creating it', (
    tester,
  ) async {
    await open(tester, controller(firebase(verified: true), FakeApi()));
    await signIn(tester, 'correct-horse');
    expect(find.byKey(const Key('account-needs-account')), findsOneWidget);
    await tapKey(tester, 'account-sign-out');
    expect(find.byKey(const Key('account-signed-out')), findsOneWidget);
  });

  testWidgets('a development build says it uses the emulator', (tester) async {
    await open(
      tester,
      controller(firebase(), FakeApi(), emulatorHost: '127.0.0.1:9099'),
    );
    expect(find.byKey(const Key('account-emulator')), findsOneWidget);
  });

  group('accessibility', () {
    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      testWidgets(
        'signed out and signed in meet the guidelines (${mode.name})',
        (tester) async {
          final api = FakeApi()..accounts.add('uid-1');
          await open(tester, controller(firebase(), api), themeMode: mode);
          for (var pass = 0; pass < 2; pass++) {
            for (final g in [
              androidTapTargetGuideline,
              iOSTapTargetGuideline,
              labeledTapTargetGuideline,
              textContrastGuideline,
            ]) {
              await expectLater(tester, meetsGuideline(g));
            }
            if (pass == 0) await signIn(tester, 'correct-horse');
          }
        },
      );
    }

    for (final vp in kViewports.entries) {
      testWidgets('the Account page fits ${vp.key} at 200% text', (
        tester,
      ) async {
        final api = FakeApi()..accounts.add('uid-1');
        await open(
          tester,
          controller(firebase(), api),
          size: vp.value,
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
        await signIn(tester, 'correct-horse');
        expect(find.byKey(const Key('account-signed-in')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
