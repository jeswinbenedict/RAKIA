// The live space-radiation environment: parsing and validating the API's
// response (a real response recorded from the staging API, thinned to one
// point an hour), how the client reports each failure, and how the
// controller keeps the last good snapshot.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakia/environment/space_weather.dart';

Map<String, Object?> recorded() => jsonDecode(
  File('test/fixtures/space_weather_recorded.json').readAsStringSync(),
) as Map<String, Object?>;

/// Applies [change] to a fresh copy of the recorded response.
Map<String, Object?> variant(void Function(Map<String, dynamic> j) change) {
  final j = recorded();
  change(j);
  return j;
}

SpaceWeatherClient clientFor(http.Response Function(http.Request) answer) =>
    SpaceWeatherClient(
      baseUrl: 'https://api.example.test',
      client: MockClient((req) async => answer(req)),
    );

void main() {
  group('parsing', () {
    test('the recorded response parses with its source and ranges', () {
      final s = SpaceWeatherSnapshot.fromJson(recorded());
      expect(s.sourceName, 'NOAA Space Weather Prediction Center');
      expect(s.satellite, startsWith('GOES-'));
      expect(s.stormLevel, 0);
      expect(s.kp, 2.0);
      expect(s.geomagneticLevel, 0);
      expect(s.s1Threshold, 10);
      expect(s.stale, isFalse);
      expect(s.points, hasLength(25));
      expect(s.latest.flux, closeTo(0.3168, 1e-4));
      expect(s.latest.time, DateTime.utc(2026, 11, 9, 15, 55));
      expect(s.retrievedAt.isUtc, isTrue);
    });

    final broken = <String, void Function(Map<String, dynamic>)>{
      'not an object': (j) => j['source'] = 'NOAA',
      'missing satellite': (j) => (j['source'] as Map).remove('satellite'),
      'negative flux': (j) =>
          (((j['proton_flux_10mev'] as Map)['points'] as List).first
                  as Map)['flux'] =
              -1,
      'points out of order': (j) {
        final pts = (j['proton_flux_10mev'] as Map)['points'] as List;
        final first = pts.removeAt(0);
        pts.add(first);
      },
      'no points': (j) =>
          (j['proton_flux_10mev'] as Map)['points'] = <Object>[],
      'wrong unit': (j) => (j['proton_flux_10mev'] as Map)['unit'] = 'mSv',
      'storm level 6': (j) => (j['radiation_storm'] as Map)['level'] = 6,
      'Kp 10': (j) => (j['geomagnetic'] as Map)['kp'] = 10,
      'local time': (j) => j['retrieved_at'] = '2026-11-09T16:03:08',
      'stale missing': (j) => j.remove('stale'),
    };
    for (final b in broken.entries) {
      test('refuses a response with ${b.key}', () {
        expect(
          () => SpaceWeatherSnapshot.fromJson(variant(b.value)),
          throwsFormatException,
        );
      });
    }

    test('geomagnetic storm levels follow Kp', () {
      SpaceWeatherSnapshot withKp(double kp) => SpaceWeatherSnapshot.fromJson(
        variant((j) => (j['geomagnetic'] as Map)['kp'] = kp),
      );
      expect(withKp(4.67).geomagneticLevel, 0);
      expect(withKp(5).geomagneticLevel, 1);
      expect(withKp(6.33).geomagneticLevel, 2);
      expect(withKp(9).geomagneticLevel, 5);
    });
  });

  group('client', () {
    test(
      'asks the API for /v1/space-weather and returns the snapshot',
      () async {
        Uri? asked;
        final c = clientFor((req) {
          asked = req.url;
          return http.Response(jsonEncode(recorded()), 200);
        });
        final s = await c.fetch();
        expect(asked.toString(), 'https://api.example.test/v1/space-weather');
        expect(s.stormLevel, 0);
      },
    );

    Future<String> failure(http.Response Function(http.Request) a) async {
      try {
        await clientFor(a).fetch();
      } on SpaceWeatherException catch (e) {
        return e.message;
      }
      fail('no exception');
    }

    test('reports each failure in words, never with invented data', () async {
      expect(
        await failure((_) => http.Response('', 503)),
        contains('NOAA data is unavailable'),
      );
      expect(
        await failure((_) => http.Response('', 500)),
        contains('error (500)'),
      );
      expect(
        await failure((_) => http.Response('{"stale": true}', 200)),
        contains('unexpected format'),
      );
      expect(
        await failure((_) => http.Response('<html>', 200)),
        contains('unexpected format'),
      );
      expect(
        await failure((_) => throw http.ClientException('offline')),
        contains('cannot be reached'),
      );
    });
  });

  group('controller', () {
    test('without an API URL it is not configured and never fetches', () {
      final c = SpaceWeatherController(null)..start();
      expect(c.configured, isFalse);
      expect(c.loading, isFalse);
      expect(c.snapshot, isNull);
      c.dispose();
    });

    test(
      'a failed refresh keeps the last good snapshot and says why',
      () async {
        var up = true;
        final c = SpaceWeatherController(
          clientFor(
            (_) => up
                ? http.Response(jsonEncode(recorded()), 200)
                : http.Response('', 503),
          ),
          every: Duration.zero,
        );
        await c.refresh();
        expect(c.snapshot, isNotNull);
        expect(c.error, isNull);

        up = false;
        await c.refresh();
        expect(c.snapshot, isNotNull);
        expect(c.error, contains('unavailable'));

        up = true;
        await c.refresh();
        expect(c.error, isNull);
        c.dispose();
      },
    );

    test('notifies while loading and after', () async {
      final c = SpaceWeatherController(
        clientFor((_) => http.Response(jsonEncode(recorded()), 200)),
        every: Duration.zero,
      );
      final seen = <bool>[];
      c.addListener(() => seen.add(c.loading));
      await c.refresh();
      expect(seen, [true, false]);
      c.dispose();
    });
  });

  group('wording', () {
    test('flux, ages and times', () {
      final now = DateTime.utc(2026, 11, 9, 16, 10);
      expect(formatFlux(0.3168), '0.32 pfu');
      expect(formatFlux(12.4), '12 pfu');
      expect(formatFlux(1430), '1,430 pfu');
      expect(
        formatAge(now.subtract(const Duration(seconds: 20)), now: now),
        'just now',
      );
      expect(
        formatAge(now.subtract(const Duration(minutes: 7)), now: now),
        '7 min ago',
      );
      expect(
        formatAge(now.subtract(const Duration(hours: 3)), now: now),
        '3 h ago',
      );
      expect(
        formatUtc(DateTime.utc(2026, 11, 9, 15, 55), now: now),
        '15:55 UTC',
      );
      expect(
        formatUtc(DateTime.utc(2026, 11, 8, 16, 5), now: now),
        '8 Nov, 16:05 UTC',
      );
    });

    test('every storm level has NOAA effect and advice; EVA from S3', () {
      expect(StormLevel.all, hasLength(6));
      for (var k = 0; k < 6; k++) {
        expect(StormLevel.all[k].noaaEffect, isNotEmpty);
        expect(StormLevel.all[k].advice, isNotEmpty);
        expect(StormLevel.all[k].noaaEffect.contains('EVA'), k >= 3);
      }
      for (final l in StormLevel.all.skip(3)) {
        expect(l.advice, contains('flight rules'));
      }
    });
  });
}
