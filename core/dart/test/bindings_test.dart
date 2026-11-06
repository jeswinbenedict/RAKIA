// SPDX-License-Identifier: Apache-2.0
//
// Runs on the Dart VM (native librakia via dart:ffi) and in Chrome
// (librakia compiled to WebAssembly). Every expected value comes from the C
// test suite or an external reference, never from this binding itself.

import 'dart:convert';
import 'dart:typed_data';

import 'package:rakia_core/rakia_core.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late RakiaCore core;

  setUpAll(() async {
    core = await openCore();
  });

  test('reports version and backend', () {
    expect(core.version, '0.1.0');
    expect(
      core.backend,
      const bool.fromEnvironment('dart.library.js_interop')
          ? RakiaBackendKind.webAssembly
          : RakiaBackendKind.native,
    );
  });

  test('exposes the documented defaults (LIBRAKIA.md)', () {
    final b = core.baselineDefaults;
    expect([b.minSamples, b.minQuality, b.minSpread], [14, 0.5, 1e-6]);
    final a = core.assessDefaults;
    expect(
      [a.minSampleQuality, a.minWindowQuality, a.watchZ, a.actZ],
      [0.5, 0.7, 2.5, 4.0],
    );
    expect([a.confirmCount, a.persistence], [2, 3]);
    expect([a.cusumK, a.cusumH], [0.5, 8.0]);
  });

  test('median and scaled MAD', () {
    final r = core.medianMad([1, 2, 3, 4, 100]);
    expect(r.median, 3);
    expect(r.madScaled, closeTo(1.482602218505602, 1e-15));
  });

  test('SHA-256 matches FIPS 180-4 vectors', () {
    expect(
      hex(core.sha256(utf8.encode('abc'))),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(
      hex(core.sha256(const [])),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
  });

  test('quality gate flags non-finite, implausible and sensor samples', () {
    final r = core.qualityAssess(
      [60, double.nan, 250, 61, 59, 62],
      sensorFlags: [0, 0, 0, 1, 0, 0],
      config: const QualityConfig(
        plausibleMin: 20,
        plausibleMax: 220,
        expectedSamples: 8,
      ),
    );
    expect(r.quality, [1, 0, 0, 0, 1, 1]);
    expect(r.flags, [
      0,
      QualityFlag.nonFinite,
      QualityFlag.implausible,
      QualityFlag.sensor,
      0,
      0,
    ]);
    expect([r.nTotal, r.nValid], [6, 3]);
    expect(r.fractionValid, 0.5);
    expect(r.completeness, 3 / 8);
    expect(r.score, 0.5 * (3 / 8));
  });

  test('baseline errors carry the librakia status and message', () {
    expect(
      () => core.baseline([60, 61, 62]),
      throwsA(
        isA<RakiaException>()
            .having((e) => e.status, 'status', RakiaStatus.insufficient)
            .having((e) => e.message, 'message', 'not enough valid data')
            .having((e) => e.function, 'fn', 'rakia_flat_baseline_compute'),
      ),
    );
    expect(
      () => core.medianMad(const []),
      throwsA(
        isA<RakiaException>().having(
          (e) => e.status,
          'status',
          RakiaStatus.empty,
        ),
      ),
    );
  });

  test('baseline and robust z', () {
    final values = [for (var i = 0; i < 21; i++) 50.0 + i]; // 50..70
    final b = core.baseline(
      values,
      config: core.baselineDefaults.copyWith(minSpread: 0.5),
    );
    expect(b.center, 60);
    // |x - 60| for 50..70 has median 5; spread = 5 * 1.4826...
    expect(b.spread, closeTo(5 * 1.482602218505602, 1e-12));
    expect(b.n, 21);
    expect(core.robustZ(60 + b.spread * 2, b), closeTo(2, 1e-12));
  });

  test('Theil-Sen recovers an exact line', () {
    final t = [for (var i = 0; i < 20; i++) i.toDouble()];
    final y = [for (final x in t) 2 * x + 1];
    final tr = core.trend(t, y);
    expect(tr.slope, 2);
    expect(tr.intercept, 1);
    expect(tr.n, 20);
    expect(tr.mkS, 190); // all 20*19/2 pairs increase
    expect(tr.pValue, lessThan(1e-6));
    expect(
      () => core.trend(List.filled(kTrendMaxN + 1, 0), List.filled(1025, 0)),
      throwsA(isA<RakiaException>()),
    );
  });

  test('Mahalanobis distance with contributions', () {
    final m = core.mahalanobis([1, 2], [1, 0, 0, 1]);
    expect(m.d2, 5);
    expect(m.contributions, [1, 4]);
    // Correlated features: R = [[1, .5], [.5, 1]], z = (1, 1) -> D^2 = 4/3.
    final c = core.mahalanobis([1, 1], [1, .5, .5, 1]);
    expect(c.d2, closeTo(4 / 3, 1e-12));
    expect(c.contributions.reduce((a, b) => a + b), closeTo(c.d2, 1e-12));
  });

  test('correlation of perfectly correlated features, with shrinkage', () {
    final x = <double>[];
    for (var i = 0; i < 10; i++) {
      x.addAll([i.toDouble(), 2.0 * i]);
    }
    final r = core.correlation(x, n: 10, d: 2, shrinkage: 0.25);
    expect(r[0], closeTo(1, 1e-12));
    expect(r[1], closeTo(0.75, 1e-12)); // (1 - 0.25) * 1 + 0.25 * 0
    expect(r[2], closeTo(0.75, 1e-12));
  });

  test('CUSUM detects an upward step', () {
    final z = [...List.filled(20, 0.0), ...List.filled(20, 2.0)];
    final r = core.cusum(z);
    expect(r.alarm, isTrue);
    expect(r.direction, 1);
    expect(r.onsetIndex, 20);
    // S+ grows by 2 - 0.5 per sample; crosses h = 8 on the 6th shifted one.
    expect(r.alarmIndex, 25);
  });

  test('assessment levels, reasons and missing samples', () {
    const b = Baseline(center: 60, spread: 2, n: 60);
    final calm = core.assess(List.filled(30, 60.5), baseline: b);
    expect(calm.level, AssessmentLevel.withinBaseline);
    expect(calm.reasons, isEmpty);
    expect(calm.latestZ, 0.25);

    final none = core.assess([double.nan, double.nan], baseline: b);
    expect(none.level, AssessmentLevel.insufficientData);
    expect(none.reasons, contains(AssessmentReason.noValidData));
    expect(none.latestValue.isNaN, isTrue);

    final shifted = core.assess([
      ...List.filled(20, 60.0),
      ...List.filled(20, 66.0),
    ], baseline: b);
    expect(shifted.level, AssessmentLevel.act);
    expect(shifted.reasons, contains(AssessmentReason.sustainedShift));
    expect(shifted.cusum.onsetIndex, 20);
    expect(shifted.z[39], 3);
  });

  test('ledger record hash matches the C golden chain', () {
    final r = LedgerRecord(
      id: Uint8List.fromList([for (var i = 0; i < 16; i++) i]),
      subjectId: Uint8List.fromList([for (var i = 0; i < 16; i++) 16 + i]),
      metricCode: 'heart_rate.resting',
      value: 62.5,
      unit: '/min',
      observedAtUs: 1762387200000000,
      method: MeasurementMethod.measured,
      provenance: Provenance.simulated,
      clientSeq: 1,
      prevHash: Uint8List(32),
    );
    expect(
      hex(core.recordHash(r)),
      'e9e40565746a10e6b782260284dd52fcead9cc9233bbb6c99368bf2596cca03d',
    );
    LedgerRecord withCode(String code, {int seq = 1, int at = 0}) =>
        LedgerRecord(
          id: r.id,
          subjectId: r.subjectId,
          metricCode: code,
          value: 1,
          unit: '%',
          observedAtUs: at,
          method: MeasurementMethod.measured,
          provenance: Provenance.real,
          clientSeq: seq,
          prevHash: r.prevHash,
        );
    expect(
      () => core.recordHash(withCode('Heart Rate')),
      throwsA(isA<RakiaException>()),
    );
    expect(
      () => core.recordHash(withCode('spo2', seq: 0)),
      throwsA(isA<RakiaException>()),
    );
    expect(() => core.recordHash(withCode('spo2\u0000x')), throwsArgumentError);
    expect(
      () => core.recordHash(withCode('spo2', at: 9007199254740992)),
      throwsArgumentError,
    );
    expect(
      () => LedgerRecord(
        id: Uint8List(15),
        subjectId: r.subjectId,
        metricCode: 'spo2',
        value: 1,
        unit: '%',
        observedAtUs: 0,
        method: MeasurementMethod.measured,
        provenance: Provenance.real,
        clientSeq: 1,
        prevHash: r.prevHash,
      ),
      throwsArgumentError,
    );
  });

  test('reproduces the cross-platform determinism digest of the C suite', () {
    // Port of core/tests/test_validation.c: 3 scenarios x 2000 runs, digest of
    // every baseline and assessment output. Golden value from the C suite.
    const runs = 2000, refN = 60, monN = 60, changeAt = 30;
    const mu = 60.0, sigma = 2.0;
    final rng = SplitMix64(0x52, 0x414B4941); // "RAKIA"
    final bcfg = core.baselineDefaults.copyWith(minSpread: 0.5);
    final digest = BytesBuilder(copy: false);
    final rec = ByteData(5 * 8 + 4 * 4);

    for (var sc = 0; sc < 3; sc++) {
      for (var r = 0; r < runs; r++) {
        final ref = [for (var i = 0; i < refN; i++) mu + sigma * rng.normal()];
        final mon = <double>[];
        for (var i = 0; i < monN; i++) {
          var shift = 0.0;
          if (sc == 1 && i >= changeAt) {
            shift = 1.5 * sigma;
          } else if (sc == 2) {
            shift = 3.0 * sigma * i.toDouble() / (monN - 1).toDouble();
          }
          mon.add(mu + shift + sigma * rng.normal());
        }
        final b = core.baseline(ref, config: bcfg);
        final a = core.assess(mon, baseline: b);
        rec
          ..setFloat64(0, b.center, Endian.little)
          ..setFloat64(8, b.spread, Endian.little)
          ..setFloat64(16, a.latestZ, Endian.little)
          ..setFloat64(24, a.cusum.sPos, Endian.little)
          ..setFloat64(32, a.cusum.sNeg, Endian.little)
          ..setUint32(40, a.level.index, Endian.little)
          ..setUint32(44, a.reasonBits, Endian.little)
          ..setUint32(48, a.cusum.alarmIndex, Endian.little)
          ..setUint32(52, a.cusum.onsetIndex, Endian.little);
        digest.add(Uint8List.fromList(rec.buffer.asUint8List()));
      }
    }
    expect(
      hex(core.sha256(digest.takeBytes())),
      'ba385f8cf40a97910b2c3a0a918936908a119014fb87b2269c7f4ccc733b18bc',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
