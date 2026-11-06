#!/usr/bin/env sh
# SPDX-License-Identifier: Apache-2.0
#
# Compiles librakia to a standalone WebAssembly module for the web backend.
# Requires Emscripten (emcc) on PATH. Output: core/dart/build/wasm/rakia.wasm,
# optionally copied to a second path given as $1 (e.g. app/web/rakia/rakia.wasm).
#
# Same floating-point contract as core/CMakeLists.txt (no FMA contraction, no
# fast-math). The module has no C runtime services: no filesystem, no stdio,
# no entry point. tool/check_wasm.mjs verifies its imports and exports.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
core="$here/../.."
out="$here/../build/wasm"
mkdir -p "$out"

exports="_malloc,_free,_rakia_version,_rakia_status_str,_rakia_flat_abi_version,\
_rakia_median_mad,_rakia_sha256,_rakia_trend_scratch_size,_rakia_correlation,\
_rakia_mahalanobis,_rakia_flat_baseline_config_default,\
_rakia_flat_assess_config_default,_rakia_flat_quality_assess,\
_rakia_flat_baseline_compute,_rakia_flat_robust_z,_rakia_flat_cusum,\
_rakia_flat_trend,_rakia_flat_assess,_rakia_flat_record_hash"

emcc "$core"/src/*.c \
  -I"$core/include" \
  -std=c11 -O2 \
  -Wall -Wextra -Wpedantic -Wconversion -Wsign-conversion -Werror \
  -ffp-contract=off -fno-fast-math \
  -sSTANDALONE_WASM=1 --no-entry \
  -sFILESYSTEM=0 \
  -sALLOW_MEMORY_GROWTH=1 \
  -sEXPORTED_FUNCTIONS="$exports" \
  -o "$out/rakia.wasm"

echo "built $out/rakia.wasm ($(wc -c < "$out/rakia.wasm") bytes)"

if [ "${1:-}" != "" ]; then
  mkdir -p "$(dirname "$1")"
  cp "$out/rakia.wasm" "$1"
  echo "copied to $1"
fi
