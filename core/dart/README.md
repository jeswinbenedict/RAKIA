# rakia_core

Dart bindings for [librakia](../README.md), RAKIA's portable C11 analytics core. The same C code runs on every platform the app supports:

| Platform | How librakia runs |
|---|---|
| Android, iOS, macOS, Linux, Windows | Compiled for the device by the package's [build hook](hook/build.dart) and called through `dart:ffi` |
| Web | Compiled to a standalone WebAssembly module by [`tool/build_wasm.sh`](tool/build_wasm.sh) and called through `dart:js_interop` (works with both dart2js and dart2wasm) |

> Experimental research software. Not clinically validated. Not a medical device.

## Usage

```dart
import 'package:rakia_core/rakia_core.dart';

final core = await loadRakiaCore();
final baseline = core.baseline(
  referenceWindow,
  config: core.baselineDefaults.copyWith(minSpread: 0.5),
);
final assessment = core.assess(latestWindow, baseline: baseline);
print('${assessment.level} ${assessment.reasons}');
```

On the web, `loadRakiaCore()` fetches `rakia/rakia.wasm` relative to the page. Pass `wasmUri` or `wasmBytes` to load it from somewhere else.

Errors from librakia are thrown as `RakiaException`. Each one carries the C status code and librakia's own message.

## Design

- **Struct-free ABI.** The bindings call the entry points in [`rakia_flat.h`](../include/rakia/rakia_flat.h), which take only scalars and pointers to arrays. The structs in `rakia.h` contain `size_t` and pointer fields, so their layout differs between 64-bit targets, 32-bit Android (`armeabi-v7a`) and wasm32. Packing everything into arrays lets one marshalling layer ([`lib/src/core.dart`](lib/src/core.dart)) serve every backend.
- **One marshalling layer, two backends.** [`backend_ffi.dart`](lib/src/backend_ffi.dart) and [`backend_wasm.dart`](lib/src/backend_wasm.dart) only provide memory and the raw calls. All copying and type conversion happens once, in `core.dart`.
- **Same floating-point contract everywhere.** The build hook and the WebAssembly build both use `-ffp-contract=off -fno-fast-math` (`/fp:precise` on MSVC), the same flags as `core/CMakeLists.txt`. This stops ARM compilers fusing multiply-adds, which would change results in the last bits.
- **Hand-written bindings.** The surface is small, so the `@Native` declarations are written by hand instead of generated with ffigen. That avoids a libclang dependency, and the tests call every declaration.

## Tests

The test suite runs unchanged on the Dart VM (native) and in Chrome (WebAssembly). Beyond the FIPS 180-4 SHA-256 vectors and the golden ledger hash from the C suite, it ports `core/tests/test_validation.c` to Dart. The port runs 6,000 simulated assessments through the bindings and must reproduce the C suite's cross-platform determinism digest, `ba385f8c…33b18bc`, exactly.

```bash
dart test                                   # native, via the build hook
sh tool/build_wasm.sh                       # needs Emscripten (emcc) on PATH
node tool/check_wasm.mjs build/wasm/rakia.wasm
dart test -p chrome                         # WebAssembly module, dart2js
dart test -p chrome --compiler dart2wasm    # WebAssembly module, dart2wasm
```

CI pins Emscripten 6.0.13 (see `.github/workflows/app.yml`).

## Not yet bound

`rakia_chain_verify` and `rakia_record_encode` are not exposed to Dart. Chain verification belongs to the ground server, which links librakia directly. The device only needs `recordHash`. `observedAtUs` and `clientSeq` must lie within ±(2^53 − 1), so they are exact on the web as well.
