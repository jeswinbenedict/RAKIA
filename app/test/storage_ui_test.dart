// The app with its on-device store: what survives a restart, what the user
// is told when storage is unavailable, and how a failed ledger check shows.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakia/simulation/simulated_mission.dart';
import 'package:rakia/storage/database.dart';
import 'package:rakia/storage/local_store.dart';
import 'package:rakia/storage/store_controller.dart';
import 'package:rakia_core/rakia_core.dart';

import 'helpers.dart';

void main() {
  late Directory tmp;
  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('rakia_storage_ui_test');
  });
  tearDownAll(() => tmp.delete(recursive: true));

  /// Opens the same database file on every app launch, like a device would.
  LocalStoreOpener fileStore(String name) {
    final file = File('${tmp.path}/$name.sqlite');
    return () async => LocalStore(
      RakiaDatabase(NativeDatabase(file)),
      kind: StorageKind.nativeFile,
    );
  }

  /// Replaces the app so the previous instance is disposed and its store
  /// closed, as when RAKIA is quit.
  Future<void> quit(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets('the simulation mission survives a restart, then ends for good', (
    tester,
  ) async {
    final opener = fileStore('restart');
    await pumpRakia(tester, size: const Size(1440, 1000), storeOpener: opener);
    await tester.tap(find.byKey(const Key('start-simulation')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('simulation-banner')), findsOneWidget);
    await quit(tester);

    await pumpRakia(
      tester,
      size: const Size(1440, 1000),
      location: '/data',
      storeOpener: opener,
    );
    expect(find.byKey(const Key('simulation-banner')), findsOneWidget);
    final storage = find.byKey(const Key('storage-card'));
    expect(
      find.descendant(
        of: storage,
        matching: find.text('SQLite database on this device'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: storage, matching: find.text('Verified')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('end-simulation')));
    await tester.pumpAndSettle();
    await quit(tester);

    await pumpRakia(tester, size: const Size(1440, 1000), storeOpener: opener);
    expect(find.byKey(const Key('simulation-banner')), findsNothing);
    expect(find.text('No active mission'), findsOneWidget);
  });

  testWidgets('the storage card states how the data is protected at rest', (
    tester,
  ) async {
    final file = File('${tmp.path}/encryption-label.sqlite');
    await pumpRakia(
      tester,
      size: const Size(1440, 1000),
      // The encrypted open itself is covered by store_encryption_test.dart;
      // this checks what the user is told about it.
      storeOpener: () async => LocalStore(
        RakiaDatabase(NativeDatabase(file)),
        kind: StorageKind.nativeFile,
        encryption: const StoreEncryption.cipher('chacha20'),
      ),
    );
    await tester.tap(find.byKey(const Key('start-simulation')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Data management').first);
    await tester.pumpAndSettle();
    final storage = find.byKey(const Key('storage-card'));
    expect(
      find.descendant(of: storage, matching: find.text('ChaCha20-Poly1305')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: storage,
        matching: find.textContaining('secure keystore'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the theme choice is remembered', (tester) async {
    final opener = fileStore('theme');
    await pumpRakia(tester, location: '/about', storeOpener: opener);
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    await quit(tester);

    // The test harness starts every launch in dark mode; the saved choice
    // must win once the store is open.
    await pumpRakia(tester, location: '/about', storeOpener: opener);
    final context = tester.element(find.text('About RAKIA').first);
    expect(Theme.of(context).brightness, Brightness.light);
  });

  testWidgets('without storage the app still works and says so', (
    tester,
  ) async {
    await pumpRakia(
      tester,
      size: const Size(1440, 1000),
      storeOpener: () async => throw const FileSystemException('disk full'),
    );
    expect(find.textContaining('Local storage is unavailable'), findsOneWidget);
    await tester.tap(find.byKey(const Key('start-simulation')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('simulation-banner')), findsOneWidget);

    await tester.tap(find.text('Data management').first);
    await tester.pumpAndSettle();
    final storage = find.byKey(const Key('storage-card'));
    expect(
      find.descendant(of: storage, matching: find.text('Memory only')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: storage, matching: find.textContaining('disk full')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: storage, matching: find.text('Not applicable')),
      findsOneWidget,
    );
  });

  testWidgets('a ledger that fails verification is reported', (tester) async {
    final opener = fileStore('tampered');
    // Prepare a saved mission, then alter one stored value behind RAKIA's
    // back, as someone with direct access to the file could.
    await tester.runAsync(() async {
      final core = await loadRakiaCore();
      final store = await opener();
      final saved = await store.saveSimulation(
        SimulatedMission.generate(),
        core,
      );
      await store.db.customStatement('DROP TRIGGER measurements_immutable');
      await store.db.customStatement(
        'UPDATE measurements SET value = value + 1 '
        'WHERE mission_id = ? AND client_seq = 42',
        [saved.missionId],
      );
      await store.close();
    });

    await pumpRakia(
      tester,
      size: const Size(1440, 1000),
      location: '/data',
      storeOpener: opener,
    );
    final storage = find.byKey(const Key('storage-card'));
    expect(
      find.descendant(of: storage, matching: find.text('Failed at record 42')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: storage,
        matching: find.textContaining('may have been altered outside RAKIA'),
      ),
      findsOneWidget,
    );
  });

  for (final vp in kViewports.entries) {
    testWidgets('the storage card fits ${vp.key} at 200% text', (tester) async {
      final opener = fileStore('layout-${vp.value.width.toInt()}');
      await pumpRakia(tester, size: vp.value, storeOpener: opener);
      await tester.tap(find.byKey(const Key('start-simulation')));
      await tester.pumpAndSettle();
      await quit(tester);
      await pumpRakia(
        tester,
        size: vp.value,
        location: '/data',
        textScale: 2,
        storeOpener: opener,
      );
      expect(find.byKey(const Key('storage-card')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
