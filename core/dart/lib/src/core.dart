// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'backend.dart';
import 'types.dart';

/// Flat ABI layout this binding was written against (rakia_flat.h).
const int kFlatAbiVersion = 1;

// Array lengths and indices from rakia_flat.h.
const _qsLen = 5, _bcLen = 3, _bLen = 3, _cuLen = 7, _trLen = 6;
const _acLen = 8, _aLen = 8 + _cuLen, _aCusum = 8;
const _hashSize = 32;

/// Largest series accepted by trend() (RAKIA_TREND_MAX_N).
const int kTrendMaxN = 1024;

/// Largest feature count for correlation() and mahalanobis() (RAKIA_MV_MAX_D).
const int kMultivariateMaxD = 32;

/// librakia, the RAKIA analytics core, running on this device.
///
/// Every result comes from the C library; this class only copies inputs into
/// C memory, calls it and copies results back. Calls are synchronous and
/// allocation-free inside C; temporary buffers are freed before returning.
final class RakiaCore {
  RakiaCore.withBackend(this._b) {
    final abi = _b.flatAbiVersion();
    if (abi != kFlatAbiVersion) {
      throw StateError(
        'librakia flat ABI $abi does not match binding $kFlatAbiVersion',
      );
    }
    version = _readCString(_b.version());
    baselineDefaults = _scoped((s) {
      final p = s.alloc(_bcLen * 8);
      _check('rakia_flat_baseline_config_default', _b.baselineConfigDefault(p));
      final v = s.readDoubles(p, _bcLen);
      return BaselineConfig(
        minSamples: v[0].toInt(),
        minQuality: v[1],
        minSpread: v[2],
      );
    });
    assessDefaults = _scoped((s) {
      final p = s.alloc(_acLen * 8);
      _check('rakia_flat_assess_config_default', _b.assessConfigDefault(p));
      final v = s.readDoubles(p, _acLen);
      return AssessConfig(
        minSampleQuality: v[0],
        minWindowQuality: v[1],
        watchZ: v[2],
        actZ: v[3],
        confirmCount: v[4].toInt(),
        persistence: v[5].toInt(),
        cusumK: v[6],
        cusumH: v[7],
      );
    });
  }

  final RakiaBackend _b;

  /// librakia version string, e.g. "0.1.0".
  late final String version;

  /// Native (dart:ffi) or WebAssembly.
  RakiaBackendKind get backend => _b.kind;

  /// librakia's documented defaults (min_spread should be set per metric).
  late final BaselineConfig baselineDefaults;
  late final AssessConfig assessDefaults;

  MedianMad medianMad(List<double> x) => _scoped((s) {
    final px = s.doubles(x);
    final scratch = s.alloc(x.length * 8);
    final out = s.alloc(16);
    _check(
      'rakia_median_mad',
      _b.medianMad(px, x.length, scratch, out, out + 8),
    );
    final r = s.readDoubles(out, 2);
    return MedianMad(r[0], r[1]);
  });

  QualityResult qualityAssess(
    List<double> values, {
    required QualityConfig config,
    List<int>? sensorFlags,
  }) => _scoped((s) {
    final n = values.length;
    if (sensorFlags != null && sensorFlags.length != n) {
      throw ArgumentError('sensorFlags must have one entry per value');
    }
    final pv = s.doubles(values);
    final pf = sensorFlags == null ? 0 : s.uint32s(sensorFlags);
    final q = s.alloc(n * 8);
    final f = s.alloc(n * 4);
    final sum = s.alloc(_qsLen * 8);
    _check(
      'rakia_flat_quality_assess',
      _b.qualityAssess(
        pv,
        pf,
        n,
        config.plausibleMin,
        config.plausibleMax,
        config.expectedSamples,
        q,
        f,
        sum,
      ),
    );
    final r = s.readDoubles(sum, _qsLen);
    return QualityResult(
      quality: s.readDoubles(q, n),
      flags: s.readUint32s(f, n),
      nTotal: r[0].toInt(),
      nValid: r[1].toInt(),
      fractionValid: r[2],
      completeness: r[3],
      score: r[4],
    );
  });

  /// Robust baseline (median, floored scaled MAD) over a reference window.
  /// Throws [RakiaException] with [RakiaStatus.insufficient] when fewer than
  /// `minSamples` samples are usable.
  Baseline baseline(
    List<double> values, {
    List<double>? quality,
    BaselineConfig? config,
  }) => _scoped((s) {
    final c = config ?? baselineDefaults;
    final n = values.length;
    final pv = s.doubles(values);
    final pq = s.optionalDoubles(quality, n, 'quality');
    final cfg = s.doubles([c.minSamples.toDouble(), c.minQuality, c.minSpread]);
    final scratch = s.alloc(n * 8);
    final out = s.alloc(_bLen * 8);
    _check(
      'rakia_flat_baseline_compute',
      _b.baselineCompute(pv, pq, n, cfg, scratch, out),
    );
    final r = s.readDoubles(out, _bLen);
    return Baseline(center: r[0], spread: r[1], n: r[2].toInt());
  });

  double robustZ(double x, Baseline baseline) => _scoped((s) {
    final b = s.baseline(baseline);
    final out = s.alloc(8);
    _check('rakia_flat_robust_z', _b.robustZ(x, b, out));
    return s.readDoubles(out, 1)[0];
  });

  /// Two-sided CUSUM over standardised residuals. Defaults to the assessment
  /// defaults (k 0.5, h 8).
  CusumResult cusum(List<double> z, {double? k, double? h}) => _scoped((s) {
    final pz = s.doubles(z);
    final out = s.alloc(_cuLen * 8);
    _check(
      'rakia_flat_cusum',
      _b.cusum(
        pz,
        z.length,
        k ?? assessDefaults.cusumK,
        h ?? assessDefaults.cusumH,
        out,
      ),
    );
    return _cusumFrom(s.readDoubles(out, _cuLen), 0);
  });

  /// Theil-Sen slope with Mann-Kendall significance; 3..[kTrendMaxN] samples.
  Trend trend(List<double> t, List<double> y) => _scoped((s) {
    if (t.length != y.length) {
      throw ArgumentError('t and y must have the same length');
    }
    final n = t.length;
    if (n > kTrendMaxN) {
      // Checked here so an oversized series never allocates a huge scratch.
      throw RakiaException('rakia_flat_trend', RakiaStatus.range, _msg(4));
    }
    final pt = s.doubles(t);
    final py = s.doubles(y);
    final len = _b.trendScratchSize(n);
    final scratch = s.alloc(len * 8);
    final out = s.alloc(_trLen * 8);
    _check('rakia_flat_trend', _b.trend(pt, py, n, scratch, len, out));
    final r = s.readDoubles(out, _trLen);
    return Trend(
      slope: r[0],
      intercept: r[1],
      mkS: r[2],
      mkZ: r[3],
      pValue: r[4],
      n: r[5].toInt(),
    );
  });

  /// Shrunk correlation matrix (row-major d*d) of standardised samples
  /// (row-major n*d).
  Float64List correlation(
    List<double> samples, {
    required int n,
    required int d,
    double shrinkage = 0.0,
  }) => _scoped((s) {
    if (samples.length != n * d) {
      throw ArgumentError('samples must hold n * d values');
    }
    final px = s.doubles(samples);
    final out = s.alloc(d * d * 8);
    _check('rakia_correlation', _b.correlation(px, n, d, shrinkage, out));
    return s.readDoubles(out, d * d);
  });

  Mahalanobis mahalanobis(List<double> z, List<double> correlation) => _scoped((
    s,
  ) {
    final d = z.length;
    if (correlation.length != d * d) {
      throw ArgumentError('correlation must be d * d');
    }
    final pz = s.doubles(z);
    final pc = s.doubles(correlation);
    final work = s.alloc((d * d + d) * 8);
    final d2 = s.alloc(8);
    final contrib = s.alloc(d * 8);
    _check('rakia_mahalanobis', _b.mahalanobis(pz, pc, d, work, d2, contrib));
    return Mahalanobis(s.readDoubles(d2, 1)[0], s.readDoubles(contrib, d));
  });

  /// Quality-gated, explainable assessment of one metric's time-ordered
  /// window against a baseline. Statistical change, not a diagnosis.
  Assessment assess(
    List<double> values, {
    required Baseline baseline,
    List<double>? quality,
    AssessConfig? config,
  }) => _scoped((s) {
    final c = config ?? assessDefaults;
    final n = values.length;
    final pv = s.doubles(values);
    final pq = s.optionalDoubles(quality, n, 'quality');
    final b = s.baseline(baseline);
    final cfg = s.doubles([
      c.minSampleQuality,
      c.minWindowQuality,
      c.watchZ,
      c.actZ,
      c.confirmCount.toDouble(),
      c.persistence.toDouble(),
      c.cusumK,
      c.cusumH,
    ]);
    final z = s.alloc(n * 8);
    final out = s.alloc(_aLen * 8);
    _check('rakia_flat_assess', _b.assess(pv, pq, n, b, cfg, z, out));
    final r = s.readDoubles(out, _aLen);
    return Assessment(
      level: AssessmentLevel.values[r[0].toInt()],
      reasonBits: r[1].toInt(),
      latestValue: r[2],
      latestZ: r[3],
      deviation: r[4],
      latestIndex: r[5].toInt(),
      nUsable: r[6].toInt(),
      windowQuality: r[7],
      cusum: _cusumFrom(r, _aCusum),
      z: s.readDoubles(z, n),
    );
  });

  /// SHA-256 (FIPS 180-4).
  Uint8List sha256(List<int> data) => _scoped((s) {
    final p = s.bytes(data);
    final out = s.alloc(_hashSize);
    _check('rakia_sha256', _b.sha256(p, data.length, out));
    return s.readBytes(out, _hashSize);
  });

  /// Hash of a ledger record's canonical v1 encoding.
  ///
  /// [LedgerRecord.observedAtUs] and [LedgerRecord.clientSeq] must lie within
  /// ±(2^53 - 1) so they are exact on every platform, including the web.
  Uint8List recordHash(LedgerRecord r) => _scoped((s) {
    final id = s.bytes(r.id);
    final subject = s.bytes(r.subjectId);
    final metric = s.cString(r.metricCode, 'metricCode');
    final unit = s.cString(r.unit, 'unit');
    final ints = s.alloc(16);
    final v = _b.view(ints, 16);
    _setInt64(v, 0, r.observedAtUs, 'observedAtUs');
    _setInt64(v, 8, r.clientSeq, 'clientSeq');
    final prev = s.bytes(r.prevHash);
    final out = s.alloc(_hashSize);
    _check(
      'rakia_flat_record_hash',
      _b.recordHash(
        id,
        subject,
        metric,
        r.value,
        unit,
        ints,
        r.method.code,
        r.provenance.code,
        prev,
        out,
      ),
    );
    return s.readBytes(out, _hashSize);
  });

  // --------------------------------------------------------------------------

  static CusumResult _cusumFrom(Float64List r, int o) => CusumResult(
    alarm: r[o] != 0,
    direction: r[o + 1].toInt(),
    alarmIndex: r[o + 2].toInt(),
    onsetIndex: r[o + 3].toInt(),
    nUsed: r[o + 4].toInt(),
    sPos: r[o + 5],
    sNeg: r[o + 6],
  );

  void _check(String function, int status) {
    if (status != 0) {
      throw RakiaException(
        function,
        RakiaStatus.fromCode(status),
        _msg(status),
      );
    }
  }

  String _msg(int status) => _readCString(_b.statusStr(status));

  String _readCString(int address) {
    var len = 0;
    while (_b.view(address + len, 1).getUint8(0) != 0) {
      len++;
    }
    final v = _b.view(address, len);
    return utf8.decode(v.buffer.asUint8List(v.offsetInBytes, len));
  }

  T _scoped<T>(T Function(_Scope s) body) {
    final s = _Scope(_b);
    try {
      return body(s);
    } finally {
      s.freeAll();
    }
  }
}

/// Largest integer magnitude that is exact on every Dart platform.
const int _maxSafeInt = 9007199254740991;

/// Little-endian int64 write that also works when compiled to JavaScript,
/// where ByteData.setInt64 is unsupported.
void _setInt64(ByteData v, int offset, int value, String name) {
  if (value > _maxSafeInt || value < -_maxSafeInt) {
    throw ArgumentError.value(value, name, 'must be within ±(2^53 - 1)');
  }
  final hi = (value / 4294967296).floor();
  final lo = value - hi * 4294967296;
  v.setUint32(offset, lo, Endian.little);
  v.setUint32(offset + 4, hi & 0xFFFFFFFF, Endian.little);
}

/// Tracks temporary C allocations for one call and frees them together.
final class _Scope {
  _Scope(this._b);
  final RakiaBackend _b;
  final List<int> _live = [];

  int alloc(int bytes) {
    final p = _b.alloc(bytes < 8 ? 8 : bytes);
    _live.add(p);
    return p;
  }

  void freeAll() {
    for (final p in _live) {
      _b.free(p);
    }
    _live.clear();
  }

  int doubles(List<double> x) {
    final p = alloc(x.length * 8);
    final v = _b.view(p, x.length * 8);
    for (var i = 0; i < x.length; i++) {
      v.setFloat64(i * 8, x[i], Endian.little);
    }
    return p;
  }

  int optionalDoubles(List<double>? x, int n, String name) {
    if (x == null) {
      return 0;
    }
    if (x.length != n) {
      throw ArgumentError('$name must have one entry per value');
    }
    return doubles(x);
  }

  int uint32s(List<int> x) {
    final p = alloc(x.length * 4);
    final v = _b.view(p, x.length * 4);
    for (var i = 0; i < x.length; i++) {
      v.setUint32(i * 4, x[i], Endian.little);
    }
    return p;
  }

  int bytes(List<int> x) {
    final p = alloc(x.length);
    final v = _b.view(p, x.length);
    for (var i = 0; i < x.length; i++) {
      v.setUint8(i, x[i]);
    }
    return p;
  }

  int cString(String value, String name) {
    if (value.contains('\u0000')) {
      throw ArgumentError.value(value, name, 'must not contain NUL');
    }
    return bytes([...utf8.encode(value), 0]);
  }

  int baseline(Baseline b) => doubles([b.center, b.spread, b.n.toDouble()]);

  Float64List readDoubles(int p, int n) {
    final v = _b.view(p, n * 8);
    return Float64List(n)..setAll(0, [
      for (var i = 0; i < n; i++) v.getFloat64(i * 8, Endian.little),
    ]);
  }

  Uint32List readUint32s(int p, int n) {
    final v = _b.view(p, n * 4);
    return Uint32List(n)..setAll(0, [
      for (var i = 0; i < n; i++) v.getUint32(i * 4, Endian.little),
    ]);
  }

  Uint8List readBytes(int p, int n) {
    final v = _b.view(p, n);
    return Uint8List.fromList(v.buffer.asUint8List(v.offsetInBytes, n));
  }
}
