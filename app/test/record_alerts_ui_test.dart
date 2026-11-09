// Alerts on the astronaut's own record in the app: the Action center keeps
// them apart from simulated alerts, the confirmatory check and the other
// responses work end to end, the log shows on the record, and the pages
// meet the accessibility and layout requirements.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakia/analytics/metric_definitions.dart';
import 'package:rakia/components/simulated_data_badge.dart';
import 'package:rakia/record/record.dart';
import 'package:rakia/storage/database.dart';
import 'package:rakia/storage/local_store.dart';
import 'package:rakia/storage/store_controller.dart';
import 'package:rakia_core/rakia_core.dart';

import 'helpers.dart';

void main() {
  late Directory tmp;
  var n = 0;
  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('rakia_record_alerts_ui');
  });
  tearDownAll(() => tmp.delete(recursive: true));

  LocalStoreOpener fileStore() {
    final file = File('${tmp.path}/store-${n++}.sqlite');
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

  /// A store whose record has a stable baseline for [metric] and a normal
  /// week, except [todayValue] today.
  Future<LocalStoreOpener> seeded(
    WidgetTester tester, {
    MetricDefinition metric = restingHeartRate,
    required double usual,
    required double todayValue,
  }) async {
    final opener = fileStore();
    await tester.runAsync(() async {
      final store = await opener();
      final core = await loadRakiaCore();
      final id = await store.createPersonalRecord(label: 'Me');
      final today = calendarDay(DateTime.now());
      final wobble = metric.minSpread;
      for (var d = 22; d >= 0; d--) {
        final v = d == 0 ? todayValue : usual + (d % 3 - 1) * wobble;
        await store.addRecordEntry(
          recordId: id,
          metric: metric,
          value: v,
          day: today.subtract(Duration(days: d)),
          core: core,
        );
      }
      await store.close();
    });
    return opener;
  }

  /// Closes the running app, so the next pump starts it afresh.
  Future<void> quit(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  Future<void> open(
    WidgetTester tester,
    LocalStoreOpener opener, {
    String location = '/actions',
    Size size = const Size(1280, 800),
    ThemeMode themeMode = ThemeMode.dark,
    double textScale = 1,
  }) async {
    await quit(tester);
    await pumpRakia(
      tester,
      location: location,
      storeOpener: opener,
      size: size,
      themeMode: themeMode,
      textScale: textScale,
    );
    await settleIo(tester);
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  const rhrAlert = Key('record-alert-heart_rate.resting');

  testWidgets('without readings the Action center says how alerts will '
      'appear, and offers the simulation separately', (tester) async {
    await pumpRakia(tester, location: '/actions');
    expect(find.text('No alerts'), findsOneWidget);
    expect(find.text('Your readings'), findsOneWidget);
    expect(
      find.textContaining('Nothing here is ever based on simulated data'),
      findsOneWidget,
    );
    expect(find.text('Simulation mission'), findsOneWidget);
    expect(find.byType(SimulatedDataBadge), findsOneWidget);
    expect(find.byKey(const Key('start-simulation')), findsOneWidget);
  });

  testWidgets('a far-off reading is an alert from your readings; a normal '
      'confirmatory reading settles it and the response is kept', (
    tester,
  ) async {
    final opener = await seeded(tester, usual: 58, todayValue: 80);
    await open(tester, opener);
    expect(find.byKey(rhrAlert), findsOneWidget);
    expect(find.text('Your readings, resting heart rate'), findsOneWidget);
    expect(find.text('None yet.'), findsOneWidget);
    // Real alerts are never drawn as simulated.
    expect(
      find.descendant(
        of: find.byKey(rhrAlert),
        matching: find.text('SIMULATED'),
      ),
      findsNothing,
    );

    await tapKey(tester, 'confirm-heart_rate.resting');
    expect(find.text('Confirmatory reading'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('confirm-value')), '500');
    await tapKey(tester, 'confirm-save');
    await settleIo(tester);
    expect(find.byKey(const Key('confirm-error')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('confirm-value')), '58');
    await tapKey(tester, 'confirm-save');
    await settleIo(tester);
    expect(find.textContaining('Back within your usual range'), findsWidgets);
    expect(find.byKey(rhrAlert), findsNothing);
    expect(find.text('No alerts'), findsOneWidget);

    await open(tester, opener, location: '/record');
    expect(find.text('Your responses to alerts'), findsOneWidget);
    expect(
      find.textContaining('Took a confirmatory reading. Reading 58.0 bpm.'),
      findsOneWidget,
    );
  });

  testWidgets('keep watching and contacting medical support are logged '
      'with a note and survive a restart', (tester) async {
    final opener = await seeded(tester, usual: 58, todayValue: 80);
    await open(tester, opener);

    await tapKey(tester, 'watch-heart_rate.resting');
    await tapKey(tester, 'response-log');
    await settleIo(tester);
    await tapKey(tester, 'medical-heart_rate.resting');
    await tester.enterText(
      find.byKey(const Key('response-note')),
      'Called the flight surgeon.',
    );
    await tapKey(tester, 'response-log');
    await settleIo(tester);

    await open(tester, opener);
    expect(
      find.textContaining(
        'Contacted medical support. Called the flight surgeon.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Chose to keep watching.'), findsOneWidget);
    expect(find.text('None yet.'), findsNothing);
  });

  testWidgets('a daily total is checked, not re-measured', (tester) async {
    final opener = await seeded(
      tester,
      metric: sleepDuration,
      usual: 7.5,
      todayValue: 3,
    );
    await open(tester, opener);
    expect(find.byKey(const Key('confirm-sleep.duration')), findsNothing);
    await tapKey(tester, 'check-sleep.duration');
    expect(find.textContaining('Recorded 3.0 h on'), findsOneWidget);
    await tapKey(tester, 'check-is-correct');
    await settleIo(tester);
    expect(
      find.descendant(
        of: find.byKey(const Key('record-alert-sleep.duration')),
        matching: find.textContaining('Checked the reading: it is correct.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the Mission overview shows the record next to the '
      'simulation, and they stay apart', (tester) async {
    final opener = await seeded(tester, usual: 58, todayValue: 80);
    await open(tester, opener, location: '/mission');
    final card = find.byKey(const Key('record-overview'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.textContaining('need')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('No response yet.')),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byKey(const Key('start-simulation')));
    await tester.tap(find.byKey(const Key('start-simulation')));
    await settleIo(tester);
    expect(find.byKey(const Key('record-overview')), findsOneWidget);

    await open(tester, opener);
    expect(find.byKey(rhrAlert), findsOneWidget);
    expect(find.byKey(const Key('alert-heart_rate.resting')), findsOneWidget);
    // Only the simulated card carries the simulated controls; only the real
    // one can be answered.
    expect(
      find.descendant(
        of: find.byKey(const Key('alert-heart_rate.resting')),
        matching: find.byKey(const Key('confirm-heart_rate.resting')),
      ),
      findsNothing,
    );
  });

  group('accessibility', () {
    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      testWidgets('the Action center with a real alert meets the guidelines '
          '(${mode.name})', (tester) async {
        final opener = await seeded(tester, usual: 58, todayValue: 80);
        await open(tester, opener, themeMode: mode);
        expect(find.byKey(rhrAlert), findsOneWidget);
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
      testWidgets('a real alert fits ${vp.key} at 200% text', (tester) async {
        final opener = await seeded(tester, usual: 58, todayValue: 80);
        for (final location in ['/actions', '/mission']) {
          await open(
            tester,
            opener,
            location: location,
            size: vp.value,
            textScale: 2,
          );
          expect(tester.takeException(), isNull, reason: location);
        }
        expect(find.byKey(const Key('record-overview')), findsOneWidget);
      });
    }
  });
}
