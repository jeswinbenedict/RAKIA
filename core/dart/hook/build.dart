// SPDX-License-Identifier: Apache-2.0
//
// Build hook: compiles librakia (../src, ../include) into a dynamic library
// for the target the Dart or Flutter SDK is building (Android, iOS, macOS,
// Linux, Windows). Web builds do not run code-asset hooks; the web backend
// loads the WebAssembly module produced by tool/build_wasm.sh instead.

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

/// librakia translation units, relative to this package's root.
const sources = [
  '../src/assess.c',
  '../src/baseline.c',
  '../src/cusum.c',
  '../src/flat.c',
  '../src/ledger.c',
  '../src/multivariate.c',
  '../src/quality.c',
  '../src/sha256.c',
  '../src/stats.c',
  '../src/status.c',
  '../src/trend.c',
];

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }
    final isWindows = input.config.code.targetOS == OS.windows;
    final builder = CBuilder.library(
      name: 'rakia',
      assetName: 'src/ffi_bindings.dart',
      sources: sources,
      includes: const ['../include'],
      std: 'c11',
      defines: const {'RAKIA_SHARED': null, 'RAKIA_BUILDING': null},
      // Same floating-point contract as core/CMakeLists.txt: no fused
      // multiply-add contraction and no fast-math, so ARM devices produce the
      // same bits as x64 servers. MSVC's /fp:precise does not contract.
      flags: isWindows
          ? const ['/fp:precise', '/utf-8']
          : const ['-ffp-contract=off', '-fno-fast-math'],
    );
    await builder.run(
      input: input,
      output: output,
      logger: Logger('')
        ..level = Level.ALL
        ..onRecord.listen((r) => print(r.message)),
    );
    // Rebuild when any C source or header changes.
    output.dependencies.addAll([
      for (final s in sources) input.packageRoot.resolve(s),
      input.packageRoot.resolve('../include/rakia/rakia.h'),
      input.packageRoot.resolve('../include/rakia/rakia_flat.h'),
      input.packageRoot.resolve('../src/internal.h'),
    ]);
  });
}
