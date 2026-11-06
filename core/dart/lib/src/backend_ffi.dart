// SPDX-License-Identifier: Apache-2.0
//
// Native backend: librakia compiled by hook/build.dart, called via dart:ffi.

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart' show malloc;

import 'backend.dart';
import 'ffi_bindings.dart' as c;
import 'types.dart';

Future<RakiaBackend> openBackend({Uri? wasmUri, Uint8List? wasmBytes}) async =>
    const FfiBackend();

Pointer<T> _p<T extends NativeType>(int address) =>
    Pointer<T>.fromAddress(address);

final class FfiBackend implements RakiaBackend {
  const FfiBackend();

  @override
  RakiaBackendKind get kind => RakiaBackendKind.native;

  @override
  int alloc(int bytes) {
    // malloc returns memory aligned for any fundamental type.
    final p = malloc.allocate<Uint8>(bytes);
    return p.address;
  }

  @override
  void free(int address) => malloc.free(_p<Uint8>(address));

  @override
  ByteData view(int address, int length) =>
      ByteData.sublistView(_p<Uint8>(address).asTypedList(length));

  @override
  int version() => c.rakiaVersion().address;

  @override
  int statusStr(int status) => c.rakiaStatusStr(status).address;

  @override
  int flatAbiVersion() => c.rakiaFlatAbiVersion();

  @override
  int medianMad(int x, int n, int scratch, int outMedian, int outMad) =>
      c.rakiaMedianMad(_p(x), n, _p(scratch), _p(outMedian), _p(outMad));

  @override
  int sha256(int data, int len, int out) =>
      c.rakiaSha256(_p(data), len, _p(out));

  @override
  int trendScratchSize(int n) => c.rakiaTrendScratchSize(n);

  @override
  int correlation(int x, int n, int d, double shrinkage, int out) =>
      c.rakiaCorrelation(_p(x), n, d, shrinkage, _p(out));

  @override
  int mahalanobis(int z, int corr, int d, int work, int outD2, int contrib) =>
      c.rakiaMahalanobis(_p(z), _p(corr), d, _p(work), _p(outD2), _p(contrib));

  @override
  int baselineConfigDefault(int out) =>
      c.rakiaFlatBaselineConfigDefault(_p(out));

  @override
  int assessConfigDefault(int out) => c.rakiaFlatAssessConfigDefault(_p(out));

  @override
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
  ) => c.rakiaFlatQualityAssess(
    _p(values),
    _p(sensorFlags),
    n,
    plausibleMin,
    plausibleMax,
    expectedSamples,
    _p(qualityOut),
    _p(flagsOut),
    _p(summaryOut),
  );

  @override
  int baselineCompute(
    int values,
    int quality,
    int n,
    int cfg,
    int scratch,
    int out,
  ) => c.rakiaFlatBaselineCompute(
    _p(values),
    _p(quality),
    n,
    _p(cfg),
    _p(scratch),
    _p(out),
  );

  @override
  int robustZ(double x, int baseline, int out) =>
      c.rakiaFlatRobustZ(x, _p(baseline), _p(out));

  @override
  int cusum(int z, int n, double k, double h, int out) =>
      c.rakiaFlatCusum(_p(z), n, k, h, _p(out));

  @override
  int trend(int t, int y, int n, int scratch, int scratchLen, int out) =>
      c.rakiaFlatTrend(_p(t), _p(y), n, _p(scratch), scratchLen, _p(out));

  @override
  int assess(
    int values,
    int quality,
    int n,
    int baseline,
    int cfg,
    int zScratch,
    int out,
  ) => c.rakiaFlatAssess(
    _p(values),
    _p(quality),
    n,
    _p(baseline),
    _p(cfg),
    _p(zScratch),
    _p(out),
  );

  @override
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
  ) => c.rakiaFlatRecordHash(
    _p(id),
    _p(subjectId),
    _p(metricCode),
    value,
    _p(unit),
    _p(ints),
    method,
    provenance,
    _p(prevHash),
    _p(out),
  );
}
