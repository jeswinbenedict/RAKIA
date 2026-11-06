// SPDX-License-Identifier: Apache-2.0
//
// Public value types of the rakia_core API. Every number here is produced by
// librakia itself; the Dart layer only marshals it. Research software, not a
// medical device: levels describe statistical change against a person's own
// baseline, not a diagnosis.

import 'dart:typed_data';

/// librakia status codes (`rakia_status` in rakia.h).
enum RakiaStatus {
  ok(0),
  nullPointer(1),
  empty(2),
  nonFinite(3),
  range(4),
  buffer(5),
  insufficient(6),
  singular(7),
  degenerate(8);

  const RakiaStatus(this.code);

  /// Numeric value returned by the C library.
  final int code;

  static RakiaStatus fromCode(int code) => RakiaStatus.values.firstWhere(
    (s) => s.code == code,
    orElse: () => throw StateError('librakia returned unknown status $code'),
  );
}

/// A librakia call returned a status other than [RakiaStatus.ok].
final class RakiaException implements Exception {
  const RakiaException(this.function, this.status, this.message);

  /// C function that failed, e.g. `rakia_flat_assess`.
  final String function;
  final RakiaStatus status;

  /// librakia's own description (`rakia_status_str`).
  final String message;

  @override
  String toString() => 'RakiaException($function: ${status.name}, $message)';
}

/// Which implementation of librakia is executing.
enum RakiaBackendKind {
  /// Compiled for this device and called through `dart:ffi`.
  native,

  /// Compiled to WebAssembly and called through `dart:js_interop`.
  webAssembly,
}

final class MedianMad {
  const MedianMad(this.median, this.madScaled);
  final double median;

  /// MAD multiplied by 1.4826 (a consistent estimator of the SD).
  final double madScaled;
}

/// Per-sample quality flags (`RAKIA_QF_*`).
abstract final class QualityFlag {
  static const nonFinite = 1 << 0;
  static const implausible = 1 << 1;
  static const sensor = 1 << 2;
}

final class QualityConfig {
  const QualityConfig({
    required this.plausibleMin,
    required this.plausibleMax,
    this.expectedSamples = 0,
  });

  /// Physiologically plausible bounds, inclusive, in the metric's unit.
  final double plausibleMin;
  final double plausibleMax;

  /// Samples expected in the window; 0 disables the completeness check.
  final double expectedSamples;
}

final class QualityResult {
  const QualityResult({
    required this.quality,
    required this.flags,
    required this.nTotal,
    required this.nValid,
    required this.fractionValid,
    required this.completeness,
    required this.score,
  });

  /// 1.0 for a valid sample, 0.0 otherwise.
  final Float64List quality;

  /// [QualityFlag] bits explaining each rejected sample.
  final Uint32List flags;
  final int nTotal;
  final int nValid;
  final double fractionValid;
  final double completeness;

  /// fractionValid * completeness, in [0, 1].
  final double score;
}

final class BaselineConfig {
  const BaselineConfig({
    required this.minSamples,
    required this.minQuality,
    required this.minSpread,
  });

  final int minSamples;
  final double minQuality;

  /// Floor for the spread in the metric's unit. Override per metric.
  final double minSpread;

  BaselineConfig copyWith({
    int? minSamples,
    double? minQuality,
    double? minSpread,
  }) => BaselineConfig(
    minSamples: minSamples ?? this.minSamples,
    minQuality: minQuality ?? this.minQuality,
    minSpread: minSpread ?? this.minSpread,
  );
}

/// A robust personal baseline: median and floored, scaled MAD.
final class Baseline {
  const Baseline({required this.center, required this.spread, required this.n});
  final double center;
  final double spread;

  /// Valid samples used.
  final int n;
}

final class CusumResult {
  const CusumResult({
    required this.alarm,
    required this.direction,
    required this.alarmIndex,
    required this.onsetIndex,
    required this.nUsed,
    required this.sPos,
    required this.sNeg,
  });

  final bool alarm;

  /// +1 upward shift, -1 downward shift, 0 none.
  final int direction;
  final int alarmIndex;

  /// Estimated first index of the change.
  final int onsetIndex;
  final int nUsed;
  final double sPos;
  final double sNeg;
}

final class Trend {
  const Trend({
    required this.slope,
    required this.intercept,
    required this.mkS,
    required this.mkZ,
    required this.pValue,
    required this.n,
  });

  /// Theil-Sen slope, value units per time unit.
  final double slope;
  final double intercept;
  final double mkS;
  final double mkZ;

  /// Two-sided Mann-Kendall p-value (normal approximation). The only output
  /// that may differ in the last bits between platforms (it uses erfc).
  final double pValue;
  final int n;
}

final class Mahalanobis {
  const Mahalanobis(this.d2, this.contributions);

  /// Squared Mahalanobis distance.
  final double d2;

  /// Per-feature contributions; they sum to [d2] and may be negative.
  final Float64List contributions;
}

final class AssessConfig {
  const AssessConfig({
    required this.minSampleQuality,
    required this.minWindowQuality,
    required this.watchZ,
    required this.actZ,
    required this.confirmCount,
    required this.persistence,
    required this.cusumK,
    required this.cusumH,
  });

  final double minSampleQuality;
  final double minWindowQuality;
  final double watchZ;
  final double actZ;
  final int confirmCount;
  final int persistence;
  final double cusumK;
  final double cusumH;
}

/// Assessment levels (`rakia_level`), in the same order as the C enum.
enum AssessmentLevel {
  /// Nothing to assess yet.
  insufficientData,

  /// A data problem, not a health signal.
  dataQuality,
  withinBaseline,
  watch,
  act,
}

/// Reasons explaining an assessment (`RAKIA_REASON_*`).
enum AssessmentReason {
  pointDeviation(1 << 0),
  sustainedShift(1 << 1),
  persistentShift(1 << 2),
  confirmedExtreme(1 << 3),
  lowQuality(1 << 4),
  noValidData(1 << 5);

  const AssessmentReason(this.bit);
  final int bit;

  static Set<AssessmentReason> fromBits(int bits) => {
    for (final r in values)
      if (bits & r.bit != 0) r,
  };
}

final class Assessment {
  const Assessment({
    required this.level,
    required this.reasonBits,
    required this.latestValue,
    required this.latestZ,
    required this.deviation,
    required this.latestIndex,
    required this.nUsable,
    required this.windowQuality,
    required this.cusum,
    required this.z,
  });

  final AssessmentLevel level;

  /// Raw `RAKIA_REASON_*` bits.
  final int reasonBits;
  Set<AssessmentReason> get reasons => AssessmentReason.fromBits(reasonBits);

  /// Most recent usable value, or NaN when there is none.
  final double latestValue;
  final double latestZ;
  final double deviation;
  final int latestIndex;
  final int nUsable;
  final double windowQuality;
  final CusumResult cusum;

  /// Robust z per sample (NaN where unusable).
  final Float64List z;
}

/// `rakia_method`.
enum MeasurementMethod {
  measured(1),
  manual(2),
  estimated(3),
  derived(4);

  const MeasurementMethod(this.code);
  final int code;
}

/// `rakia_provenance`. Simulated data must always be labelled as such.
enum Provenance {
  real(1),
  imported(2),
  simulated(3);

  const Provenance(this.code);
  final int code;
}

/// A measurement in the hash-chained ledger (`rakia_record`).
final class LedgerRecord {
  LedgerRecord({
    required this.id,
    required this.subjectId,
    required this.metricCode,
    required this.value,
    required this.unit,
    required this.observedAtUs,
    required this.method,
    required this.provenance,
    required this.clientSeq,
    required this.prevHash,
  }) {
    _checkLength('id', id, 16);
    _checkLength('subjectId', subjectId, 16);
    _checkLength('prevHash', prevHash, 32);
  }

  /// UUID bytes.
  final Uint8List id;
  final Uint8List subjectId;

  /// ASCII `[a-z0-9_.]`, 1..64 bytes (validated by librakia).
  final String metricCode;
  final double value;

  /// UCUM unit code, printable ASCII, 1..32 bytes (validated by librakia).
  final String unit;

  /// Microseconds since the Unix epoch, UTC.
  final int observedAtUs;
  final MeasurementMethod method;
  final Provenance provenance;

  /// Per-device sequence number, starting at 1.
  final int clientSeq;

  /// Hash of the previous record (zeros or the genesis for the first).
  final Uint8List prevHash;

  static void _checkLength(String name, Uint8List v, int n) {
    if (v.length != n) {
      throw ArgumentError.value(v.length, name, 'must be $n bytes');
    }
  }
}
