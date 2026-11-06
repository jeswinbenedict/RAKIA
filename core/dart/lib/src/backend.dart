// SPDX-License-Identifier: Apache-2.0
//
// The minimal surface both backends implement: raw memory plus the C entry
// points, with every pointer carried as an integer address. All marshalling
// lives once in core.dart on top of this, so the native and WebAssembly paths
// cannot drift apart.

import 'dart:typed_data';

import 'types.dart';

abstract interface class RakiaBackend {
  RakiaBackendKind get kind;

  /// Allocates [bytes] (> 0) bytes of C memory, aligned for doubles.
  int alloc(int bytes);
  void free(int address);

  /// A view of C memory. Fetch a fresh view after any call that may allocate:
  /// WebAssembly memory can grow, which detaches earlier views.
  ByteData view(int address, int length);

  int version();
  int statusStr(int status);
  int flatAbiVersion();

  int medianMad(int x, int n, int scratch, int outMedian, int outMad);
  int sha256(int data, int len, int out);
  int trendScratchSize(int n);
  int correlation(int x, int n, int d, double shrinkage, int out);
  int mahalanobis(int z, int corr, int d, int work, int outD2, int contrib);

  int baselineConfigDefault(int out);
  int assessConfigDefault(int out);
  int qualityAssess(
    int values,
    int sensorFlags,
    int n,
    double plausibleMin,
    double plausibleMax,
    double expectedSamples,
    int qualityOut,
    int flagsOut,
    int summaryOut,
  );
  int baselineCompute(
    int values,
    int quality,
    int n,
    int cfg,
    int scratch,
    int out,
  );
  int robustZ(double x, int baseline, int out);
  int cusum(int z, int n, double k, double h, int out);
  int trend(int t, int y, int n, int scratch, int scratchLen, int out);
  int assess(
    int values,
    int quality,
    int n,
    int baseline,
    int cfg,
    int zScratch,
    int out,
  );
  int recordHash(
    int id,
    int subjectId,
    int metricCode,
    double value,
    int unit,
    int ints,
    int method,
    int provenance,
    int prevHash,
    int out,
  );
}
