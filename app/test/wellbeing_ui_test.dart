// Behavioural health in the app: completing a check-in, what survives a
// restart, deleting records, the memory-only fallback, the reaction-time
// test on a controlled clock, and accessibility and layout.
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rakia/design/theme.dart';
import 'package:rakia/features/reaction_test_page.dart';
import 'package:rakia/features/wellbeing_page.dart';
import 'package:rakia/navigation/modules.dart';
import 'package:rakia/storage/database.dart';
import 'package:rakia/storage/local_store.dart';
import 'package:rakia/storage/store_controller.dart';
import 'package:rakia/wellbeing/wellbeing_controller.dart';

import 'helpers.dart';

void main() {
  late Directory tmp;
  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('rakia_wellbeing_ui_test');
  });
  tearDownAll(() => tmp.delete(recursive: true));

  LocalStoreOpener fileStore(String name) {
    final file = File('${tmp.path}/$name.sqlite');
    return () async => LocalStore(
      RakiaDatabase(NativeDatabase(file)),
      kind: StorageKind.nativeFile,
    );
  }

  Future<void> quit(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  Future<void> completeCheckIn(
    WidgetTester tester, {
    int sleepiness = 3,
    int stress = 2,
    int mood = 4,
  }) async {
    await tester.ensureVisible(find.byKey(const Key('start-check-in')));
    await tester.tap(find.byKey(const Key('start-check-in')));
    await tester.pumpAndSettle();
    for (final (id, v) in [
      ('sleepiness', sleepiness),
      ('stress', stress),
      ('mood', mood),
    ]) {
      final answer = find.byKey(Key('answer-$id-$v'));
      await tester.ensureVisible(answer);
      await tester.tap(answer);
      await tester.pumpAndSettle();
    }
    final save = find.byKey(const Key('save-check-in'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
  }

  testWidgets('a check-in is saved only once every question is answered', (
    tester,
  ) async {
    await pumpRakia(
      tester,
      size: const Size(1280, 900),
      location: '/behavioural',
    );
    expect(find.text('No check-ins yet'), findsOneWidget);
    await tester.tap(find.byKey(const Key('start-check-in')));
    await tester.pumpAndSettle();
    expect(find.text('Check-in'), findsWidgets);

    final save = find.byKey(const Key('save-check-in'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    expect(
      find.text('Answer the remaining 3 questions to save.'),
      findsOneWidget,
    );
    for (final key in ['answer-sleepiness-7', 'answer-stress-4']) {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    expect(find.text('Answer the remaining question to save.'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('answer-mood-2')));
    await tester.tap(find.byKey(const Key('answer-mood-2')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);

    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Check-in saved.'), findsOneWidget);
    final card = find.byKey(const Key('check-ins-card'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(
        of: card,
        matching: find.textContaining(
          'Sleepy, but no effort to keep awake',
          findRichText: true,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('cancelling a check-in saves nothing', (tester) async {
    await pumpRakia(tester, location: '/behavioural');
    await tester.tap(find.byKey(const Key('start-check-in')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('answer-sleepiness-3')));
    await tester.pumpAndSettle();
    final cancel = find.byKey(const Key('cancel-check-in'));
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(find.text('No check-ins yet'), findsOneWidget);
  });

  testWidgets('check-ins survive a restart and can be deleted for good', (
    tester,
  ) async {
    final opener = fileStore('restart');
    await pumpRakia(
      tester,
      size: const Size(1280, 900),
      location: '/behavioural',
      storeOpener: opener,
    );
    await completeCheckIn(tester, sleepiness: 5);
    await quit(tester);

    await pumpRakia(
      tester,
      size: const Size(1280, 900),
      location: '/behavioural',
      storeOpener: opener,
    );
    expect(find.byKey(const Key('check-ins-card')), findsOneWidget);
    expect(
      find.textContaining('Neither alert nor sleepy', findRichText: true),
      findsOneWidget,
    );

    final delete = find.byKey(const Key('delete-wellbeing'));
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(find.text('Delete all wellbeing records?'), findsOneWidget);
    expect(
      find.textContaining('1 check-in and 0 reaction-time'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('confirm-delete-wellbeing')));
    await tester.pumpAndSettle();
    expect(find.text('No check-ins yet'), findsOneWidget);
    await quit(tester);

    await pumpRakia(tester, location: '/behavioural', storeOpener: opener);
    expect(find.text('No check-ins yet'), findsOneWidget);
  });

  testWidgets('without storage check-ins still work and the page says so', (
    tester,
  ) async {
    await pumpRakia(
      tester,
      size: const Size(1280, 900),
      location: '/behavioural',
      storeOpener: () async => throw const FileSystemException('disk full'),
    );
    expect(find.byKey(const Key('wellbeing-memory-only')), findsOneWidget);
    await completeCheckIn(tester);
    expect(find.byKey(const Key('check-ins-card')), findsOneWidget);
    expect(find.byKey(const Key('wellbeing-memory-only')), findsOneWidget);
  });

  group('the reaction-time test', () {
    late Duration now;
    late WellbeingController wellbeing;

    Future<void> pumpTest(WidgetTester tester) async {
      now = Duration.zero;
      wellbeing = WellbeingController();
      addTearDown(wellbeing.dispose);
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final module = kModules.firstWhere((m) => m.id == 'behavioural');
      final router = GoRouter(
        initialLocation: kReactionTestPath,
        routes: [
          GoRoute(
            path: '/behavioural',
            builder: (context, state) =>
                Scaffold(body: WellbeingPage(module: module)),
            routes: [
              GoRoute(
                path: 'reaction-test',
                builder: (context, state) => Scaffold(
                  body: ReactionTestPage(
                    clock: () => now,
                    random: Random(7),
                    duration: const Duration(seconds: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        WellbeingScope(
          controller: wellbeing,
          child: MaterialApp.router(
            theme: buildRakiaTheme(Brightness.dark),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Advances the controlled clock and the frame clock together.
    Future<void> advance(WidgetTester tester, Duration d) async {
      now += d;
      await tester.pump(d);
    }

    /// Waits for the next stimulus; false when the test ended first.
    Future<bool> waitForStimulus(WidgetTester tester) async {
      for (var i = 0; i < 400; i++) {
        if (find.byKey(const Key('reaction-result')).evaluate().isNotEmpty) {
          return false;
        }
        if (find.byKey(const Key('reaction-stimulus')).evaluate().isNotEmpty) {
          await advance(tester, const Duration(milliseconds: 16));
          return true;
        }
        await advance(tester, const Duration(milliseconds: 16));
      }
      fail('no stimulus appeared within 6 s');
    }

    testWidgets('records responses, false starts and saves the result', (
      tester,
    ) async {
      await pumpTest(tester);
      expect(find.text('Before you start'), findsOneWidget);
      await tester.tap(find.byKey(const Key('begin-reaction-test')));
      await advance(tester, const Duration(milliseconds: 16));
      expect(find.text('Wait for the counter'), findsOneWidget);

      // A tap before any stimulus is a false start.
      await tester.tap(find.byKey(const Key('reaction-area')));
      await advance(tester, const Duration(milliseconds: 16));

      var responses = 0;
      while (await waitForStimulus(tester)) {
        await advance(tester, const Duration(milliseconds: 280));
        await tester.tap(find.byKey(const Key('reaction-area')));
        responses++;
        await advance(tester, const Duration(milliseconds: 16));
        expect(responses, lessThan(20));
      }
      final result = find.byKey(const Key('reaction-result'));
      expect(
        find.descendant(of: result, matching: find.text('$responses')),
        findsWidgets,
      );
      expect(
        find.descendant(of: result, matching: find.text('1')),
        findsWidgets,
      );

      await tester.tap(find.byKey(const Key('save-reaction-test')));
      await tester.pumpAndSettle();
      expect(wellbeing.reactionTests, hasLength(1));
      final saved = wellbeing.reactionTests.single;
      expect(saved.responses, responses);
      expect(saved.falseStarts, 1);
      expect(saved.lapses, 0);
      expect(saved.medianRtMs, inInclusiveRange(280, 320));
      expect(find.byKey(const Key('reaction-tests-card')), findsOneWidget);
    });

    testWidgets('the keyboard responds too', (tester) async {
      await pumpTest(tester);
      await tester.tap(find.byKey(const Key('begin-reaction-test')));
      await advance(tester, const Duration(milliseconds: 16));
      expect(await waitForStimulus(tester), isTrue);
      await advance(tester, const Duration(milliseconds: 250));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await advance(tester, const Duration(milliseconds: 16));
      expect(find.textContaining(' ms'), findsWidgets);
    });

    testWidgets('stopping saves nothing', (tester) async {
      await pumpTest(tester);
      await tester.tap(find.byKey(const Key('begin-reaction-test')));
      await advance(tester, const Duration(milliseconds: 16));
      await tester.tap(find.byKey(const Key('stop-reaction-test')));
      await tester.pumpAndSettle();
      expect(wellbeing.reactionTests, isEmpty);
      expect(find.text('No check-ins yet'), findsOneWidget);
    });
  });

  group('accessibility', () {
    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      testWidgets('check-in and history meet the guidelines (${mode.name})', (
        tester,
      ) async {
        await pumpRakia(
          tester,
          size: const Size(1280, 900),
          themeMode: mode,
          location: '/behavioural',
        );
        await completeCheckIn(tester);
        await completeCheckIn(tester, sleepiness: 6, stress: 3, mood: 3);
        for (final g in [
          androidTapTargetGuideline,
          iOSTapTargetGuideline,
          labeledTapTargetGuideline,
          textContrastGuideline,
        ]) {
          await expectLater(tester, meetsGuideline(g));
        }
        await tester.tap(find.byKey(const Key('start-check-in')));
        await tester.pumpAndSettle();
        for (final g in [
          androidTapTargetGuideline,
          labeledTapTargetGuideline,
          textContrastGuideline,
        ]) {
          await expectLater(tester, meetsGuideline(g));
        }
      });
    }

    for (final vp in kViewports.entries) {
      testWidgets('pages fit ${vp.key} at 200% text', (tester) async {
        await pumpRakia(
          tester,
          size: vp.value,
          textScale: 2,
          location: '/behavioural',
        );
        expect(tester.takeException(), isNull);
        await completeCheckIn(tester);
        expect(find.byKey(const Key('check-ins-card')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.byKey(const Key('start-reaction-test')),
        );
        await tester.tap(find.byKey(const Key('start-reaction-test')));
        await tester.pumpAndSettle();
        expect(find.text('Before you start'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
