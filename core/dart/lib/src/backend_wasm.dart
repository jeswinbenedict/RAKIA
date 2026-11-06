// SPDX-License-Identifier: Apache-2.0
//
// Web backend: librakia compiled to a standalone WebAssembly module by
// tool/build_wasm.sh, instantiated with the browser's WebAssembly API and
// called through dart:js_interop. Works with dart2js and dart2wasm.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'backend.dart';
import 'types.dart';

/// Default module location, relative to the page (Flutter: `web/rakia/`).
final Uri defaultWasmUri = Uri.base.resolve('rakia/rakia.wasm');

Future<RakiaBackend> openBackend({Uri? wasmUri, Uint8List? wasmBytes}) async {
  final bytes = wasmBytes ?? await _fetchBytes(wasmUri ?? defaultWasmUri);
  final module = await _compile(bytes.toJS).toDart;
  final instance = await _instantiate(module, _imports(module)).toDart;
  final exports = instance.exports;
  // A standalone (reactor) module must run its initialiser before any call.
  if (exports.has('_initialize')) {
    exports.callMethodVarArgs<JSAny?>('_initialize'.toJS);
  }
  return WasmBackend._(exports);
}

Future<Uint8List> _fetchBytes(Uri uri) async {
  final response = await _fetch(uri.toString().toJS).toDart;
  if (!response.ok) {
    throw StateError(
      'Could not load librakia WebAssembly from $uri (HTTP ${response.status})',
    );
  }
  final buffer = await response.arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}

/// Builds the import object. The module is built without a C runtime that
/// needs host services; the only import it may declare is the memory-growth
/// notification, which needs no action because views are re-fetched. Any
/// other import fails loudly rather than silently doing nothing.
JSObject _imports(_Module module) {
  final imports = JSObject();
  for (final entry in _moduleImports(module).toDart) {
    final ns = entry.module;
    final name = entry.name;
    var nsObject = imports.getProperty<JSObject?>(ns.toJS);
    if (nsObject == null) {
      nsObject = JSObject();
      imports.setProperty(ns.toJS, nsObject);
    }
    if (name == 'emscripten_notify_memory_growth') {
      nsObject.setProperty(name.toJS, ((JSAny? _) {}).toJS);
    } else {
      nsObject.setProperty(
        name.toJS,
        (() => _unsupportedImport('$ns.$name')).toJS,
      );
    }
  }
  return imports;
}

// Typed as returning JSAny? (not Never) so it can be converted with toJS.
JSAny? _unsupportedImport(String name) =>
    throw StateError('librakia WebAssembly import $name called');

@JS('fetch')
external JSPromise<_Response> _fetch(JSString url);

extension type _Response._(JSObject _) implements JSObject {
  external bool get ok;
  external int get status;
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

extension type _Module._(JSObject _) implements JSObject {}

extension type _ImportDescriptor._(JSObject _) implements JSObject {
  external String get module;
  external String get name;
}

extension type _Instance._(JSObject _) implements JSObject {
  external JSObject get exports;
}

@JS('WebAssembly.compile')
external JSPromise<_Module> _compile(JSUint8Array bytes);

@JS('WebAssembly.Module.imports')
external JSArray<_ImportDescriptor> _moduleImports(_Module module);

@JS('WebAssembly.instantiate')
external JSPromise<_Instance> _instantiate(_Module module, JSObject imports);

extension type _Memory._(JSObject _) implements JSObject {
  external JSArrayBuffer get buffer;
}

final class WasmBackend implements RakiaBackend {
  WasmBackend._(this._exports)
    : _memory = _exports.getProperty<_Memory>('memory'.toJS);

  final JSObject _exports;
  final _Memory _memory;

  @override
  RakiaBackendKind get kind => RakiaBackendKind.webAssembly;

  int _call(String fn, List<Object> args) {
    final jsArgs = <JSAny?>[
      for (final a in args) a is int ? a.toJS : (a as double).toJS,
    ];
    final r = _exports.callMethodVarArgs<JSNumber>(fn.toJS, jsArgs);
    return r.toDartInt;
  }

  @override
  int alloc(int bytes) {
    final p = _call('malloc', [bytes]);
    if (p == 0) {
      throw StateError('librakia WebAssembly malloc($bytes) failed');
    }
    return p;
  }

  @override
  void free(int address) {
    _exports.callMethodVarArgs<JSAny?>('free'.toJS, [address.toJS]);
  }

  @override
  ByteData view(int address, int length) =>
      _memory.buffer.toDart.asByteData(address, length);

  @override
  int version() => _call('rakia_version', const []);

  @override
  int statusStr(int status) => _call('rakia_status_str', [status]);

  @override
  int flatAbiVersion() => _call('rakia_flat_abi_version', const []);

  @override
  int medianMad(int x, int n, int scratch, int outMedian, int outMad) =>
      _call('rakia_median_mad', [x, n, scratch, outMedian, outMad]);

  @override
  int sha256(int data, int len, int out) =>
      _call('rakia_sha256', [data, len, out]);

  @override
  int trendScratchSize(int n) => _call('rakia_trend_scratch_size', [n]);

  @override
  int correlation(int x, int n, int d, double shrinkage, int out) =>
      _call('rakia_correlation', [x, n, d, shrinkage, out]);

  @override
  int mahalanobis(int z, int corr, int d, int work, int outD2, int contrib) =>
      _call('rakia_mahalanobis', [z, corr, d, work, outD2, contrib]);

  @override
  int baselineConfigDefault(int out) =>
      _call('rakia_flat_baseline_config_default', [out]);

  @override
  int assessConfigDefault(int out) =>
      _call('rakia_flat_assess_config_default', [out]);

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
  ) => _call('rakia_flat_quality_assess', [
    values,
    sensorFlags,
    n,
    plausibleMin,
    plausibleMax,
    expectedSamples,
    qualityOut,
    flagsOut,
    summaryOut,
  ]);

  @override
  int baselineCompute(
    int values,
    int quality,
    int n,
    int cfg,
    int scratch,
    int out,
  ) => _call('rakia_flat_baseline_compute', [
    values,
    quality,
    n,
    cfg,
    scratch,
    out,
  ]);

  @override
  int robustZ(double x, int baseline, int out) =>
      _call('rakia_flat_robust_z', [x, baseline, out]);

  @override
  int cusum(int z, int n, double k, double h, int out) =>
      _call('rakia_flat_cusum', [z, n, k, h, out]);

  @override
  int trend(int t, int y, int n, int scratch, int scratchLen, int out) =>
      _call('rakia_flat_trend', [t, y, n, scratch, scratchLen, out]);

  @override
  int assess(
    int values,
    int quality,
    int n,
    int baseline,
    int cfg,
    int zScratch,
    int out,
  ) => _call('rakia_flat_assess', [
    values,
    quality,
    n,
    baseline,
    cfg,
    zScratch,
    out,
  ]);

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
  ) => _call('rakia_flat_record_hash', [
    id,
    subjectId,
    metricCode,
    value,
    unit,
    ints,
    method,
    provenance,
    prevHash,
    out,
  ]);
}
