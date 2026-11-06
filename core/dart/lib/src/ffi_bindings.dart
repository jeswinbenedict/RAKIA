// SPDX-License-Identifier: Apache-2.0
//
// dart:ffi declarations for librakia. The library is the code asset built by
// hook/build.dart; its asset id is this file's URI, so @Native resolves it
// without an explicit assetId. Signatures mirror rakia.h and rakia_flat.h:
// rakia_status is returned as Int32, size_t is Size.
//
// Hand-written rather than generated: the surface is small and deliberately
// struct-free, and this avoids a libclang dependency in every build.
// test/bindings_test.dart exercises every declaration.

import 'dart:ffi';

@Native<Pointer<Uint8> Function()>(symbol: 'rakia_version', isLeaf: true)
external Pointer<Uint8> rakiaVersion();

@Native<Pointer<Uint8> Function(Int32)>(
  symbol: 'rakia_status_str',
  isLeaf: true,
)
external Pointer<Uint8> rakiaStatusStr(int status);

@Native<Int32 Function()>(symbol: 'rakia_flat_abi_version', isLeaf: true)
external int rakiaFlatAbiVersion();

@Native<
  Int32 Function(
    Pointer<Double>,
    Size,
    Pointer<Double>,
    Pointer<Double>,
    Pointer<Double>,
  )
>(symbol: 'rakia_median_mad', isLeaf: true)
external int rakiaMedianMad(
  Pointer<Double> x,
  int n,
  Pointer<Double> scratch,
  Pointer<Double> outMedian,
  Pointer<Double> outMad,
);

@Native<Int32 Function(Pointer<Void>, Size, Pointer<Uint8>)>(
  symbol: 'rakia_sha256',
  isLeaf: true,
)
external int rakiaSha256(Pointer<Void> data, int len, Pointer<Uint8> out);

@Native<Size Function(Size)>(symbol: 'rakia_trend_scratch_size', isLeaf: true)
external int rakiaTrendScratchSize(int n);

@Native<Int32 Function(Pointer<Double>, Size, Size, Double, Pointer<Double>)>(
  symbol: 'rakia_correlation',
  isLeaf: true,
)
external int rakiaCorrelation(
  Pointer<Double> x,
  int n,
  int d,
  double shrinkage,
  Pointer<Double> out,
);

@Native<
  Int32 Function(
    Pointer<Double>,
    Pointer<Double>,
    Size,
    Pointer<Double>,
    Pointer<Double>,
    Pointer<Double>,
  )
>(symbol: 'rakia_mahalanobis', isLeaf: true)
external int rakiaMahalanobis(
  Pointer<Double> z,
  Pointer<Double> corr,
  int d,
  Pointer<Double> work,
  Pointer<Double> outD2,
  Pointer<Double> contrib,
);

@Native<Int32 Function(Pointer<Double>)>(
  symbol: 'rakia_flat_baseline_config_default',
  isLeaf: true,
)
external int rakiaFlatBaselineConfigDefault(Pointer<Double> out);

@Native<Int32 Function(Pointer<Double>)>(
  symbol: 'rakia_flat_assess_config_default',
  isLeaf: true,
)
external int rakiaFlatAssessConfigDefault(Pointer<Double> out);

@Native<
  Int32 Function(
    Pointer<Double>,
    Pointer<Uint32>,
    Size,
    Double,
    Double,
    Double,
    Pointer<Double>,
    Pointer<Uint32>,
    Pointer<Double>,
  )
>(symbol: 'rakia_flat_quality_assess', isLeaf: true)
external int rakiaFlatQualityAssess(
  Pointer<Double> values,
  Pointer<Uint32> sensorFlags,
  int n,
  double plausibleMin,
  double plausibleMax,
  double expectedSamples,
  Pointer<Double> qualityOut,
  Pointer<Uint32> flagsOut,
  Pointer<Double> summaryOut,
);

@Native<
  Int32 Function(
    Pointer<Double>,
    Pointer<Double>,
    Size,
    Pointer<Double>,
    Pointer<Double>,
    Pointer<Double>,
  )
>(symbol: 'rakia_flat_baseline_compute', isLeaf: true)
external int rakiaFlatBaselineCompute(
  Pointer<Double> values,
  Pointer<Double> quality,
  int n,
  Pointer<Double> cfg,
  Pointer<Double> scratch,
  Pointer<Double> out,
);

@Native<Int32 Function(Double, Pointer<Double>, Pointer<Double>)>(
  symbol: 'rakia_flat_robust_z',
  isLeaf: true,
)
external int rakiaFlatRobustZ(
  double x,
  Pointer<Double> baseline,
  Pointer<Double> out,
);

@Native<Int32 Function(Pointer<Double>, Size, Double, Double, Pointer<Double>)>(
  symbol: 'rakia_flat_cusum',
  isLeaf: true,
)
external int rakiaFlatCusum(
  Pointer<Double> z,
  int n,
  double k,
  double h,
  Pointer<Double> out,
);

@Native<
  Int32 Function(
    Pointer<Double>,
    Pointer<Double>,
    Size,
    Pointer<Double>,
    Size,
    Pointer<Double>,
  )
>(symbol: 'rakia_flat_trend', isLeaf: true)
external int rakiaFlatTrend(
  Pointer<Double> t,
  Pointer<Double> y,
  int n,
  Pointer<Double> scratch,
  int scratchLen,
  Pointer<Double> out,
);

@Native<
  Int32 Function(
    Pointer<Double>,
    Pointer<Double>,
    Size,
    Pointer<Double>,
    Pointer<Double>,
    Pointer<Double>,
    Pointer<Double>,
  )
>(symbol: 'rakia_flat_assess', isLeaf: true)
external int rakiaFlatAssess(
  Pointer<Double> values,
  Pointer<Double> quality,
  int n,
  Pointer<Double> baseline,
  Pointer<Double> cfg,
  Pointer<Double> zScratch,
  Pointer<Double> out,
);

@Native<
  Int32 Function(
    Pointer<Uint8>,
    Pointer<Uint8>,
    Pointer<Uint8>,
    Double,
    Pointer<Uint8>,
    Pointer<Int64>,
    Uint32,
    Uint32,
    Pointer<Uint8>,
    Pointer<Uint8>,
  )
>(symbol: 'rakia_flat_record_hash', isLeaf: true)
external int rakiaFlatRecordHash(
  Pointer<Uint8> id,
  Pointer<Uint8> subjectId,
  Pointer<Uint8> metricCode,
  double value,
  Pointer<Uint8> unit,
  Pointer<Int64> ints,
  int method,
  int provenance,
  Pointer<Uint8> prevHash,
  Pointer<Uint8> out,
);
