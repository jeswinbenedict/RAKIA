// My health record in the app: the empty state, entering and validating a
// reading, what survives a restart, correcting a reading, and accessibility
// and layout at 200% text on every window class.
import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakia/storage/database.dart';
import 'package:rakia/storage/local_store.dart';
import 'package:rakia/storage/store_controller.dart';

import 'helpers.dart';

void main() {
  late Directory tmp;
  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('rakia_record_ui_test');
  });
  tearDownAll(() => tmp.delete(recursive: true));

  LocalStoreOpener fileStore(String name) {
    final file = File('${tmp.path}/$name.sqlite');
    return () async => LocalStore(
      RakiaDatabase(NativeDatabase(file)),
      kind: StorageKind.nativeFile,
    );
  }

  /// Lets the database's real I/O finish, then settles the UI.
  Future<void> settleIo(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String value) async {
    await tester.enterText(find.byKey(const Key('record-value')), value);
    await tester.ensureVisible(find.byKey(const Key('record-save')));
    await tester.tap(find.byKey(const Key('record-save')));
    await settleIo(tester);
  }

  testWidgets('starts empty and honest', (tester) async {
    await pumpRakia(tester, location: '/record');
    expect(find.text('No readings yet'), findsOneWidget);
    expect(find.byKey(const Key('record-save')), findsOneWidget);
  });

  testWidgets('a reading is validated, saved and survives a restart', (
    tester,
  ) async {
    final opener = fileStore('restart');
    await pumpRakia(tester, location: '/record', storeOpener: opener);

    await enter(tester, '400');
    expect(find.byKey(const Key('record-error')), findsOneWidget);
    expect(find.text('No readings yet'), findsOneWidget);

    await enter(tester, '58');
    expect(find.byKey(const Key('record-error')), findsNothing);
    expect(find.textContaining('Latest 58.0 bpm'), findsOneWidget);
    expect(find.text('Baseline: 0 of 14 days'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await pumpRakia(tester, location: '/record', storeOpener: opener);
    await settleIo(tester);
    expect(find.textContaining('Latest 58.0 bpm'), findsOneWidget);
  });

  testWidgets('a correction replaces a reading in place', (tester) async {
    await pumpRakia(tester, location: '/record');
    await enter(tester, '85');
    expect(find.textContaining('Latest 85.0 bpm'), findsOneWidget);

    final correct = find.text('Correct').first;
    await tester.ensureVisible(correct);
    await tester.tap(correct);
    await tester.pumpAndSettle();
    final dialogValue = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byKey(const Key('record-value')),
    );
    await tester.enterText(dialogValue, '58');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byKey(const Key('record-save')),
      ),
    );
    await settleIo(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('Latest 58.0 bpm'), findsOneWidget);
    // The card shows only the correction (the snackbar may still mention
    // the original save).
    expect(
      find.descendant(
        of: find.byKey(const Key('record-card-heart_rate.resting')),
        matching: find.textContaining('85.0 bpm'),
      ),
      findsNothing,
    );
  });

  testWidgets('when storage never opens, the record works for the session '
      'and says so', (tester) async {
    final never = Completer<LocalStore>();
    await pumpRakia(
      tester,
      location: '/record',
      storeOpener: () => never.future,
    );
    // Past the 15-second deadline, the session store takes over.
    await tester.pump(const Duration(seconds: 16));
    await settleIo(tester);
    expect(
      find.textContaining('readings last only for this session'),
      findsOneWidget,
    );
    await enter(tester, '58');
    expect(find.textContaining('Latest 58.0 bpm'), findsOneWidget);
  });

  test('a storage open that never finishes times out with a reason', () async {
    final c = StoreController(
      opener: () => Completer<LocalStore>().future,
      timeout: const Duration(milliseconds: 50),
    );
    await c.open();
    expect(
      c.state,
      isA<StoreUnavailable>().having(
        (s) => s.reason,
        'reason',
        contains('did not open within'),
      ),
    );
    expect(c.store, isNull);
    expect(c.sessionStore?.kind, StorageKind.memory);
    c.dispose();
  });

  group('accessibility', () {
    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      testWidgets('the record meets the guidelines (${mode.name})', (
        tester,
      ) async {
        await pumpRakia(tester, location: '/record', themeMode: mode);
        await enter(tester, '58');
        for (final g in [
          androidTapTargetGuideline,
          iOSTapTargetGuideline,
          labeledTapTargetGuideline,
          textContrastGuideline,
        ]) {
          await expectLater(tester, meetsGuideline(g));
        }
      });
    }

    for (final vp in kViewports.entries) {
      testWidgets('the record fits ${vp.key} at 200% text', (tester) async {
        await pumpRakia(
          tester,
          size: vp.value,
          textScale: 2,
          location: '/record',
        );
        expect(tester.takeException(), isNull);
        await enter(tester, '58');
        expect(
          find.byKey(const Key('record-card-heart_rate.resting')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
