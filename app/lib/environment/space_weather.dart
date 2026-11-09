// Live space-radiation environment, served by the RAKIA API from the NOAA
// Space Weather Prediction Center (GET /v1/space-weather).
//
// This is the environment near Earth, measured by a GOES satellite at
// geostationary orbit. It is context for crew decisions, such as planning a
// spacewalk, and never a measurement of a person's dose.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

/// The API's base URL, fixed at build time:
/// `flutter build web --dart-define=RAKIA_API_URL=https://...`.
/// Empty means this build has no live data connection.
const String kApiUrl = String.fromEnvironment('RAKIA_API_URL');

@immutable
class FluxPoint {
  const FluxPoint(this.time, this.flux);
  final DateTime time;

  /// Integral proton flux above 10 MeV, in pfu (particles cm⁻² s⁻¹ sr⁻¹).
  final double flux;
}

/// One snapshot as published by the API, validated.
@immutable
class SpaceWeatherSnapshot {
  const SpaceWeatherSnapshot({
    required this.sourceName,
    required this.sourceUrl,
    required this.satellite,
    required this.retrievedAt,
    required this.stale,
    required this.points,
    required this.s1Threshold,
    required this.stormLevel,
    required this.stormObservedAt,
    required this.kp,
    required this.kpObservedAt,
  });

  final String sourceName;
  final String sourceUrl;
  final String satellite;

  /// When the API last fetched the feeds from NOAA.
  final DateTime retrievedAt;

  /// True when the API could not reach NOAA on its last refresh and is
  /// serving the previous snapshot.
  final bool stale;

  /// Proton flux above 10 MeV over the last day, oldest first.
  final List<FluxPoint> points;

  /// The flux at which NOAA declares an S1 radiation storm (10 pfu).
  final double s1Threshold;

  /// NOAA solar radiation storm level, 0 (none) to 5 (extreme).
  final int stormLevel;
  final DateTime stormObservedAt;

  /// Planetary K index, 0 to 9.
  final double kp;
  final DateTime kpObservedAt;

  FluxPoint get latest => points.last;

  /// NOAA geomagnetic storm level derived from Kp: G1 at Kp 5 up to G5 at
  /// Kp 9; 0 below 5.
  int get geomagneticLevel => kp < 5 ? 0 : (kp.floor() - 4).clamp(1, 5);

  /// Parses and validates the API response. Throws [FormatException] for
  /// anything that does not match the documented shape and ranges.
  factory SpaceWeatherSnapshot.fromJson(Object? json) {
    Map<String, Object?> obj(Object? v, String what) {
      if (v is Map<String, Object?>) return v;
      throw FormatException('$what is not an object');
    }

    String str(Map<String, Object?> m, String k) {
      final v = m[k];
      if (v is String && v.isNotEmpty) return v;
      throw FormatException('$k is missing');
    }

    double number(Map<String, Object?> m, String k) {
      final v = m[k];
      if (v is num && v.isFinite) return v.toDouble();
      throw FormatException('$k is not a number');
    }

    DateTime time(Map<String, Object?> m, String k) {
      final t = DateTime.tryParse(str(m, k));
      if (t == null || !t.isUtc) throw FormatException('$k is not a UTC time');
      return t;
    }

    final root = obj(json, 'response');
    final source = obj(root['source'], 'source');
    final protons = obj(root['proton_flux_10mev'], 'proton_flux_10mev');
    final storm = obj(root['radiation_storm'], 'radiation_storm');
    final geo = obj(root['geomagnetic'], 'geomagnetic');
    if (protons['unit'] != 'pfu') {
      throw const FormatException('proton flux is not in pfu');
    }
    final rawPoints = protons['points'];
    if (rawPoints is! List || rawPoints.isEmpty) {
      throw const FormatException('points is empty');
    }
    final points = <FluxPoint>[];
    for (final p in rawPoints) {
      final m = obj(p, 'point');
      final f = number(m, 'flux');
      if (f < 0) throw const FormatException('negative flux');
      final t = time(m, 'time');
      if (points.isNotEmpty && !t.isAfter(points.last.time)) {
        throw const FormatException('points are not in time order');
      }
      points.add(FluxPoint(t, f));
    }
    final level = storm['level'];
    if (level is! int || level < 0 || level > 5) {
      throw const FormatException('storm level out of range');
    }
    final kp = number(geo, 'kp');
    if (kp < 0 || kp > 9) throw const FormatException('Kp out of range');
    final threshold = number(protons, 's1_threshold');
    if (threshold <= 0) throw const FormatException('S1 threshold invalid');
    final stale = root['stale'];
    if (stale is! bool) throw const FormatException('stale is missing');
    return SpaceWeatherSnapshot(
      sourceName: str(source, 'name'),
      sourceUrl: str(source, 'url'),
      satellite: str(source, 'satellite'),
      retrievedAt: time(root, 'retrieved_at'),
      stale: stale,
      points: List.unmodifiable(points),
      s1Threshold: threshold,
      stormLevel: level,
      stormObservedAt: time(storm, 'observed_at'),
      kp: kp,
      kpObservedAt: time(geo, 'observed_at'),
    );
  }
}

/// NOAA's Space Weather Scale for solar radiation storms: the name and the
/// biological effect NOAA publishes for each level
/// (https://www.swpc.noaa.gov/noaa-scales-explanation), and what that means
/// for the astronaut. RAKIA does not set flight rules; it points to them.
@immutable
class StormLevel {
  const StormLevel(this.name, this.noaaEffect, this.advice);

  final String name;
  final String noaaEffect;
  final String advice;

  static const List<StormLevel> all = [
    StormLevel(
      'No radiation storm',
      'No solar radiation storm is in progress.',
      'Space weather does not call for any change to your activities.',
    ),
    StormLevel(
      'S1 Minor',
      'NOAA lists no biological impact at this level.',
      'No change is needed. Storms can strengthen, so keep an eye on this '
          'page and on messages from the ground.',
    ),
    StormLevel(
      'S2 Moderate',
      'NOAA: passengers and crew in high-flying aircraft at high latitudes '
          'may be exposed to elevated radiation risk.',
      'Check with the ground before planning a spacewalk, and follow your '
          "mission's radiation flight rules.",
    ),
    StormLevel(
      'S3 Strong',
      'NOAA: radiation hazard avoidance recommended for astronauts on EVA.',
      "Follow your mission's radiation flight rules and instructions from "
          'the ground. Spacewalks are normally avoided at this level, and you '
          'may be directed to a more shielded area.',
    ),
    StormLevel(
      'S4 Severe',
      'NOAA: unavoidable radiation hazard to astronauts on EVA.',
      "Follow your mission's radiation flight rules and instructions from "
          'the ground. Expect spacewalks to be stopped and to move to the '
          'most shielded area when directed.',
    ),
    StormLevel(
      'S5 Extreme',
      'NOAA: unavoidable high radiation hazard to astronauts on EVA.',
      "Follow your mission's radiation flight rules and instructions from "
          'the ground. Expect spacewalks to be stopped and to move to the '
          'most shielded area when directed.',
    ),
  ];
}

class SpaceWeatherException implements Exception {
  const SpaceWeatherException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Fetches snapshots from the RAKIA API.
class SpaceWeatherClient {
  SpaceWeatherClient({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// The API runs on a free host that sleeps when idle; waking it can take
  /// most of a minute, so the timeout allows for that.
  static const Duration timeout = Duration(seconds: 90);

  Future<SpaceWeatherSnapshot> fetch() async {
    final http.Response res;
    try {
      res = await _client
          .get(
            Uri.parse('$baseUrl/v1/space-weather'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const SpaceWeatherException(
        'The RAKIA server did not answer in time.',
      );
    } on Object {
      throw const SpaceWeatherException('The RAKIA server cannot be reached.');
    }
    if (res.statusCode == 503) {
      throw const SpaceWeatherException(
        'NOAA data is unavailable right now. The server keeps retrying.',
      );
    }
    if (res.statusCode != 200) {
      throw SpaceWeatherException(
        'The RAKIA server answered with an error (${res.statusCode}).',
      );
    }
    try {
      return SpaceWeatherSnapshot.fromJson(jsonDecode(res.body));
    } on FormatException {
      throw const SpaceWeatherException(
        'The server sent space-weather data in an unexpected format.',
      );
    }
  }

  void close() => _client.close();
}

/// Keeps the latest snapshot for the UI and refreshes it every [every]
/// (NOAA publishes every five minutes). On failure the previous snapshot
/// stays visible, with the error alongside it.
class SpaceWeatherController extends ChangeNotifier {
  SpaceWeatherController(
    this._client, {
    this.every = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final SpaceWeatherClient? _client;

  /// Refresh interval; zero disables automatic refresh.
  final Duration every;
  final DateTime Function() _clock;
  Timer? _timer;
  bool _disposed = false;

  SpaceWeatherSnapshot? _snapshot;
  String? _error;
  bool _loading = false;
  DateTime? _lastAttempt;

  SpaceWeatherSnapshot? get snapshot => _snapshot;

  /// Why the last refresh failed, if it did.
  String? get error => _error;
  bool get loading => _loading;

  /// False when this build has no API URL: the app then says so instead of
  /// showing anything.
  bool get configured => _client != null;

  /// Now, from the injected clock.
  DateTime get now => _clock().toUtc();

  /// When a refresh was last attempted.
  DateTime? get lastAttempt => _lastAttempt;

  void start() {
    if (_client == null || _timer != null || _disposed) return;
    unawaited(refresh());
    if (every > Duration.zero) {
      _timer = Timer.periodic(every, (_) => refresh());
    }
  }

  Future<void> refresh() async {
    final client = _client;
    if (client == null || _loading || _disposed) return;
    _loading = true;
    _lastAttempt = now;
    notifyListeners();
    try {
      _snapshot = await client.fetch();
      _error = null;
    } on SpaceWeatherException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _client?.close();
    super.dispose();
  }
}

class SpaceWeatherScope extends InheritedNotifier<SpaceWeatherController> {
  const SpaceWeatherScope({
    super.key,
    required SpaceWeatherController controller,
    required super.child,
  }) : super(notifier: controller);

  static SpaceWeatherController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<SpaceWeatherScope>();
    assert(scope != null, 'SpaceWeatherScope is missing from the widget tree');
    return scope!.notifier!;
  }
}

/// "16:05 UTC" or "8 Nov, 16:05 UTC".
String formatUtc(DateTime t, {required DateTime now}) {
  final u = t.toUtc();
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hm =
      '${u.hour.toString().padLeft(2, '0')}:'
      '${u.minute.toString().padLeft(2, '0')} UTC';
  final n = now.toUtc();
  final sameDay = u.year == n.year && u.month == n.month && u.day == n.day;
  return sameDay ? hm : '${u.day} ${months[u.month - 1]}, $hm';
}

/// "just now", "12 min ago", "3 h ago".
String formatAge(DateTime t, {required DateTime now}) {
  final d = now.difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 120) return '${d.inMinutes} min ago';
  return '${d.inHours} h ago';
}

/// A flux value in words: "0.32 pfu", "12 pfu", "1,400 pfu".
String formatFlux(double pfu) {
  if (pfu < 10) return '${pfu.toStringAsFixed(2)} pfu';
  final whole = pfu.round().toString();
  final grouped = whole.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  return '$grouped pfu';
}

/// How old the measurements are when it matters: NOAA publishes every five
/// minutes, so data older than this is called out.
const Duration kSpaceWeatherFreshFor = Duration(minutes: 30);
