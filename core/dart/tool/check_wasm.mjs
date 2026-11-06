// SPDX-License-Identifier: Apache-2.0
//
// Verifies the librakia WebAssembly module: every export the Dart web
// backend calls is present, and the module needs no host services beyond an
// optional memory-growth notification. Then runs two known-answer checks.
// Usage: node tool/check_wasm.mjs build/wasm/rakia.wasm
import { readFileSync } from 'node:fs';

const path = process.argv[2];
const bytes = readFileSync(path);
const module = await WebAssembly.compile(bytes);

const allowedImports = new Set(['emscripten_notify_memory_growth']);
const imports = WebAssembly.Module.imports(module);
const unexpected = imports.filter((i) => !allowedImports.has(i.name));
if (unexpected.length > 0) {
  throw new Error(`unexpected imports: ${JSON.stringify(unexpected)}`);
}

const required = [
  'memory', 'malloc', 'free', 'rakia_version', 'rakia_status_str',
  'rakia_flat_abi_version', 'rakia_median_mad', 'rakia_sha256',
  'rakia_trend_scratch_size', 'rakia_correlation', 'rakia_mahalanobis',
  'rakia_flat_baseline_config_default', 'rakia_flat_assess_config_default',
  'rakia_flat_quality_assess', 'rakia_flat_baseline_compute',
  'rakia_flat_robust_z', 'rakia_flat_cusum', 'rakia_flat_trend',
  'rakia_flat_assess', 'rakia_flat_record_hash',
];
const exported = new Set(WebAssembly.Module.exports(module).map((e) => e.name));
const missing = required.filter((n) => !exported.has(n));
if (missing.length > 0) {
  throw new Error(`missing exports: ${missing.join(', ')}`);
}

const importObject = {};
for (const i of imports) {
  (importObject[i.module] ??= {})[i.name] = () => {};
}
const { exports: x } = await WebAssembly.instantiate(module, importObject);
if (typeof x._initialize === 'function') x._initialize();

const cstr = (p) => {
  const m = new Uint8Array(x.memory.buffer);
  let e = p;
  while (m[e] !== 0) e++;
  return new TextDecoder().decode(m.subarray(p, e));
};
if (cstr(x.rakia_version()) !== '0.1.0') throw new Error('version mismatch');

const data = x.malloc(3);
const out = x.malloc(32);
new Uint8Array(x.memory.buffer, data, 3).set([0x61, 0x62, 0x63]);
if (x.rakia_sha256(data, 3, out) !== 0) throw new Error('sha256 failed');
const hex = Buffer.from(new Uint8Array(x.memory.buffer, out, 32)).toString('hex');
if (hex !== 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad') {
  throw new Error(`sha256("abc") = ${hex}`);
}
x.free(data);
x.free(out);
console.log(`${path}: ${bytes.length} bytes, imports ${JSON.stringify(imports.map((i) => i.name))}, exports OK, known answers OK`);
