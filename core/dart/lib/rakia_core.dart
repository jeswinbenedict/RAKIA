// SPDX-License-Identifier: Apache-2.0
//
// rakia_core: Dart bindings for librakia, RAKIA's portable C11 analytics core.
//
// EXPERIMENTAL RESEARCH SOFTWARE. Not a medical device. The algorithms flag
// statistical changes relative to a person's own baseline; they do not
// diagnose and have not been clinically validated.

import 'dart:typed_data';

import 'src/backend_stub.dart'
    if (dart.library.js_interop) 'src/backend_wasm.dart'
    if (dart.library.ffi) 'src/backend_ffi.dart';
import 'src/core.dart';

export 'src/core.dart' show RakiaCore, kTrendMaxN, kMultivariateMaxD;
export 'src/types.dart';

/// Loads librakia for the current platform: the native library built by the
/// package's build hook, or on the web the WebAssembly module at [wasmUri]
/// (default `rakia/rakia.wasm` next to the page) or from [wasmBytes].
Future<RakiaCore> loadRakiaCore({Uri? wasmUri, Uint8List? wasmBytes}) async =>
    RakiaCore.withBackend(
      await openBackend(wasmUri: wasmUri, wasmBytes: wasmBytes),
    );
