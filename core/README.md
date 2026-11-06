# librakia

Portable C11 analytics core for RAKIA. It covers data-quality gating, personal baselines, CUSUM change and onset detection, Theil–Sen/Mann–Kendall trends, Mahalanobis distance with per-feature contributions, and a SHA-256 hash-chained measurement ledger.

> Experimental research software. Not clinically validated. Not a medical device.

Algorithms, assumptions and validation results: [docs/algorithms/LIBRAKIA.md](../docs/algorithms/LIBRAKIA.md). Public API: [include/rakia/rakia.h](include/rakia/rakia.h). Struct-free API for foreign-function callers: [include/rakia/rakia_flat.h](include/rakia/rakia_flat.h). Dart bindings (native and WebAssembly): [dart/](dart/README.md).

## Build and test

Linux / macOS:

```bash
cmake -S core -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```

Windows (Visual Studio 2022 or Build Tools with the C++ workload), from a *Developer PowerShell*:

```powershell
cmake -S core -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
ctest --test-dir build --output-on-failure
```

If CMake reports `cannot open file 'ucrtd.lib'`, the Windows SDK's debug runtime is missing. Use `-G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_TRY_COMPILE_CONFIGURATION=Release`, or add the Windows SDK component in the Visual Studio Installer.

## Options

| Option | Default | Effect |
|---|---|---|
| `RAKIA_BUILD_TESTS` | `ON` | Build the test executables |
| `RAKIA_WARNINGS_AS_ERRORS` | `ON` | `/WX` or `-Werror` |
| `RAKIA_SANITIZE` | `OFF` | AddressSanitizer (MSVC), ASan + UBSan (GCC/Clang) |
| `RAKIA_FUZZ` | `OFF` | libFuzzer target `fuzz_core` (Clang only) |
| `BUILD_SHARED_LIBS` | `OFF` | Build a shared library for `dart:ffi` |

Static analysis: `clang-tidy -p build core/src/*.c` (configuration in `.clang-tidy`).
