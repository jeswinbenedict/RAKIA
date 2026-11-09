// Space weather in the app: honest when not connected or unreachable, the
// live view with its source and freshness, a radiation storm raised in the
// Action center and on the Mission overview, and accessibility and layout.
// Responses come from a real API response recorded from staging.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakia/environment/space_weather.dart';

import 'helpers.dart';

Map<String, Object?> recorded() => jsonDecode(
  File('test/fixtures/space_weather_recorded.json').readAsStringSync(),
) as Map<String, Object?>;

void main() {
  /// Shortly after the recorded response was served.
  final fresh = DateTime.utc(2026, 11, 9, 16, 6);

  SpaceWeatherController controller(
    WidgetTester tester, {
    Map<String, Object?>? body,
    int status = 200,
    DateTime? now,
  }) {
    final c = SpaceWeatherController(
      SpaceWeatherClient(
        baseUrl: 'https://api.example.test',
        client: MockClient(
          (_) async => http.Response(jsonEncode(body ?? recorded()), status),
        ),
      ),
      every: Duration.zero,
      clock: () => now ?? fresh,
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> open(
    WidgetTester tester,
    SpaceWeatherController sw, {
    String location = '/environment',
    Size size = const Size(1280, 800),
    ThemeMode themeMode = ThemeMode.dark,
    double textScale = 1,
  }) async {
    await pumpRakia(
      tester,
      location: location,
      spaceWeather: sw,
      size: size,
      themeMode: themeMode,
      textScale: textScale,
    );
    await sw.refresh();
    await tester.pumpAndSettle();
  }

  Map<String, Object?> storm(int level) {
    final j = recorded();
    (j['radiation_storm'] as Map)['level'] = level;
    return j;
  }

  testWidgets('a build without an API says so and shows no values', (
    tester,
  ) async {
    await pumpRakia(tester, location: '/environment');
    expect(find.byKey(const Key('space-weather-unconfigured')), findsOneWidget);
    expect(find.textContaining('pfu'), findsNothing);
    // Personal dosimetry is still honestly empty.
    expect(find.text('No dosimetry or environment data yet'), findsOneWidget);
  });

  testWidgets('the live view shows the storm level, flux, Kp and source', (
    tester,
  ) async {
    await open(tester, controller(tester));
    final live = find.byKey(const Key('space-weather-live'));
    expect(live, findsOneWidget);
    expect(find.text('No radiation storm'), findsOneWidget);
    expect(
      find.text(
        '0.32 pfu at 15:55 UTC, below the S1 storm threshold of 10 pfu.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Kp 2.0 at 12:00 UTC: below storm level'),
      findsOneWidget,
    );
    expect(
      find.textContaining('NOAA Space Weather Prediction Center, GOES-18'),
      findsOneWidget,
    );
    expect(
      find.textContaining('not the dose you have received'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('space-weather-old')), findsNothing);
    expect(find.byKey(const Key('space-weather-alert')), findsNothing);
  });

  testWidgets('old measurements are called out', (tester) async {
    await open(
      tester,
      controller(tester, now: fresh.add(const Duration(hours: 2))),
    );
    final old = tester.widget<Text>(find.byKey(const Key('space-weather-old')));
    expect(old.data, contains('Showing data measured 2 h ago'));
  });

  testWidgets('an unreachable server is reported, and retry recovers', (
    tester,
  ) async {
    var status = 503;
    final sw = SpaceWeatherController(
      SpaceWeatherClient(
        baseUrl: 'https://api.example.test',
        client: MockClient(
          (_) async => http.Response(jsonEncode(recorded()), status),
        ),
      ),
      every: Duration.zero,
      clock: () => fresh,
    );
    addTearDown(sw.dispose);
    await open(tester, sw);
    expect(find.byKey(const Key('space-weather-error')), findsOneWidget);
    expect(find.textContaining('pfu'), findsNothing);

    status = 200;
    await tester.tap(find.byKey(const Key('space-weather-refresh')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('space-weather-live')), findsOneWidget);
  });

  testWidgets('a strong radiation storm is raised in the Action center with '
      'EVA advice, and on the Mission overview', (tester) async {
    final sw = controller(tester, body: storm(3));
    await open(tester, sw, location: '/actions');
    final alert = find.byKey(const Key('space-weather-alert'));
    expect(alert, findsOneWidget);
    expect(
      find.descendant(
        of: alert,
        matching: find.text('Solar radiation storm: S3 Strong'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: alert, matching: find.textContaining('on EVA')),
      findsOneWidget,
    );
    expect(find.text('No alerts'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await open(tester, sw, location: '/mission');
    expect(
      find.descendant(
        of: find.byKey(const Key('space-weather-summary')),
        matching: find.textContaining('S3 Strong'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('no storm, no space-weather alert', (tester) async {
    await open(tester, controller(tester), location: '/actions');
    expect(find.byKey(const Key('space-weather-alert')), findsNothing);
    expect(find.text('No alerts'), findsOneWidget);
  });

  group('accessibility', () {
    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      testWidgets('the live view meets the guidelines (${mode.name})', (
        tester,
      ) async {
        await open(tester, controller(tester, body: storm(2)), themeMode: mode);
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
      testWidgets('space weather fits ${vp.key} at 200% text', (tester) async {
        final sw = controller(tester, body: storm(4));
        for (final location in ['/environment', '/mission', '/actions']) {
          await tester.pumpWidget(const SizedBox());
          await open(
            tester,
            sw,
            location: location,
            size: vp.value,
            textScale: 2,
          );
          expect(tester.takeException(), isNull, reason: location);
        }
      });
    }
  });
}
