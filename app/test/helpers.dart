import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakia/app.dart';
import 'package:rakia/app_settings.dart';
import 'package:rakia/environment/space_weather.dart';
import 'package:rakia/mission/mission_controller.dart';
import 'package:rakia/storage/local_store.dart';
import 'package:rakia/storage/open_store.dart';
import 'package:rakia/storage/store_controller.dart';

/// Representative viewport per window class (logical pixels).
const Map<String, Size> kViewports = {
  'compact phone 390x844': Size(390, 844),
  'medium tablet 800x1100': Size(800, 1100),
  'expanded laptop 1280x800': Size(1280, 800),
  'large desktop 1600x1000': Size(1600, 1000),
};

/// A fresh, empty in-memory SQLite store with the production schema.
LocalStore newMemoryStore() {
  // Each test opens its own database; that is intended here.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return memoryStore(NativeDatabase.memory());
}

/// Opens [newMemoryStore]; the default for widget tests.
Future<LocalStore> memoryStoreOpener() async => newMemoryStore();

/// Pumps the whole app at a given logical size, theme and text scale.
Future<void> pumpRakia(
  WidgetTester tester, {
  Size size = const Size(1280, 800),
  ThemeMode themeMode = ThemeMode.dark,
  double textScale = 1.0,
  String location = '/mission',
  MissionController? mission,
  LocalStoreOpener? storeOpener,
  SpaceWeatherController? spaceWeather,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    RakiaApp(
      initialLocation: location,
      settings: AppSettingsController(themeMode),
      mission: mission,
      storeOpener: storeOpener ?? memoryStoreOpener,
      spaceWeather: spaceWeather,
    ),
  );
  await tester.pumpAndSettle();
}
