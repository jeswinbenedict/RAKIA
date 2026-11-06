# librakia — Algorithms, Assumptions and Validation

> **Experimental research software. Not clinically validated. Not a medical device.**
> librakia flags statistical change relative to a person's own baseline. It never diagnoses.

`librakia` (`core/`) is RAKIA's portable C11 analytics core. The same code is meant to run on the crew device (Flutter via `dart:ffi`, or WebAssembly on the web) and on the ground server (C++ API), so both sides compute the same answer from the same data.

## 1. Engineering rules

| Rule | Why |
|---|---|
| C11, no global mutable state | Thread-safe by construction; easy to bind from Dart, C++ and WebAssembly. |
| No heap allocation; callers pass every buffer | Predictable memory, no leaks, suitable for embedded habitat hardware. |
| Every function validates its arguments and returns `rakia_status` | Malformed or missing input is an error code, never undefined behaviour. |
| Strict IEEE 754: `/fp:precise` (MSVC), `-ffp-contract=off -fno-fast-math` (GCC/Clang) | Stops compilers from fusing multiply-adds differently per platform, which would break determinism. |
| Warnings are errors: `/W4 /WX`, `-Wall -Wextra -Wpedantic -Wconversion -Wsign-conversion …` | |

**Determinism.** Every output is bit-identical across platforms, with one exception: trend p-values come from the platform's `erfc()`, which can differ in the last bits. CI enforces this with a SHA-256 digest of 6,000 simulated assessments, which must match exactly on MSVC x64, GCC, Clang and macOS ARM64.

## 2. Data quality gate — `rakia_quality_assess`

Each sample scores 1 (valid) or 0. A sample scores 0 if it is non-finite, outside the metric's plausible range, or flagged by the device. Window score = fraction valid × completeness, where completeness = min(1, valid / expected samples).

*Assumption:* plausible ranges are set per metric by the caller. They are wide sanity bounds, not clinical reference ranges.

## 3. Personal baseline — `rakia_baseline_compute`

- **Centre** = median of the reference window. **Spread** = MAD × 1.4826, which is a consistent estimate of the standard deviation for normal data.
- Samples that are non-finite or below `min_quality` are excluded.
- A minimum sample count is enforced (default 14) and returns `RAKIA_E_INSUFFICIENT` below it. **We recommend ≥ 60 samples** (see §7).
- **Spread floor (`min_spread`).** Quantised data, such as whole-number heart rates, can give MAD = 0. The floor must be set per metric, at roughly the sensor's resolution or a small physiologically meaningful variation.

*Why median and MAD:* they tolerate artefacts and outliers that would distort a mean and standard deviation. *Limitation:* MAD is a less efficient estimator than the standard deviation, so small windows give noisy spreads.

## 4. Point deviation — `rakia_robust_z`

z = (x − centre) / spread.

## 5. Sustained change and onset — `rakia_cusum`

Two-sided tabular CUSUM over robust z:
S⁺ₜ = max(0, S⁺ₜ₋₁ + zₜ − k) and S⁻ₜ = max(0, S⁻ₜ₋₁ − zₜ − k). An alarm fires when either statistic exceeds h.

- **Onset estimate:** the first sample after the triggering statistic was last zero. This answers "since when?" in every alert.
- Missing (non-finite) samples are skipped, not imputed.
- **Defaults: k = 0.5, h = 8.** The textbook h = 5 assumes the baseline mean and standard deviation are known exactly. Personal baselines are estimated from tens of samples, and the synthetic validation (§7) showed h = 5 with a 30-sample baseline false-alarming in 37 % of no-change 60-sample windows. With h = 8 and a 60-sample baseline, that falls to about 8 %, at the cost of about 3 extra samples of detection delay.

## 6. Assessment — `rakia_assess`

| Level | Rule |
|---|---|
| `INSUFFICIENT_DATA` | No usable samples. |
| `DATA_QUALITY` | Usable fraction < `min_window_quality` (default 0.7). This is a data problem, not a health signal, and no health level is reported. |
| `WITHIN_BASELINE` | None of the rules below apply. |
| `WATCH` | Latest \|z\| ≥ 2.5, **or** a sustained shift: a CUSUM alarm supported by ≥ 2 usable samples between onset and alarm. |
| `ACT` | A sustained shift **and** ≥ `persistence` (3) usable samples after the alarm, a strict majority of them still beyond k (that is, the post-alarm median stays shifted); **or** ≥ 2 consecutive values with \|z\| ≥ 4 and the same sign. |

A single extreme value is never enough for `ACT`; it produces `WATCH` with a request to confirm. The result carries reason bits, the latest value and z, the deviation from baseline, and the CUSUM onset and alarm indices. These feed the six-question alert explanation in the app.

*These thresholds are engineering defaults chosen for a low false-alarm rate on synthetic data. They are not clinical thresholds, and they should be tuned per metric with domain experts.*

## 7. Synthetic validation (`core/tests/test_validation.c`)

**Setup.** Each run builds a baseline from a 60-sample reference window, then assesses a 60-sample monitoring window. Values are N(60, 2²). Normal draws come from Irwin–Hall (the sum of 12 uniforms) so the generated data is identical on every platform. There are 2,000 runs per scenario with a fixed seed.

| Scenario | Result |
|---|---|
| No change | CUSUM alarm 7.4 % · `ACT` 1.7 % · `WATCH` or `ACT` at window end 8.5 % |
| +1.5 SD step at sample 30 | Detected after the change 97.2 % · median delay 7 samples · median onset error 1 sample · `ACT` 98.3 % |
| Linear drift to +3 SD | CUSUM alarm 100 % · `ACT` 100 % |

Parameter sweep: 4,000 runs per cell. Columns give the "no change" `WATCH`-or-`ACT` rate / step detected after the change.

| Reference samples | h = 5 | h = 6 | h = 8 | h = 10 |
|---|---|---|---|---|
| 30 | 38.6 % / 76.3 % | 28.7 % / 83.4 % | 17.0 % / 91.8 % | 11.3 % / 94.5 % |
| 60 | 27.1 % / 86.4 % | 17.4 % / 91.4 % | 7.8 % / 97.0 % | 4.5 % / 98.4 % |
| 90 | 22.2 % / 89.2 % | 12.6 % / 94.7 % | 5.2 % / 98.3 % | 2.7 % / 99.4 % |

**What this does and does not show.** It shows the engine behaves as designed on independent, normally distributed data. Real physiological series are autocorrelated, follow circadian patterns, and contain artefacts, so real false-alarm rates will be higher. Before these defaults are trusted beyond demonstration, they need evaluation on real or analog datasets, with domain experts.

## 8. Trend — `rakia_trend_compute`

The Theil–Sen slope (median of pairwise slopes) is robust to up to about 29 % outliers. The Mann–Kendall S statistic uses tie-corrected variance, a continuity-corrected z, and a two-sided normal p-value; it is reliable from n ≥ 10. Cost is O(n²) time and scratch memory, so n is capped at 1,024. Longer series should be aggregated first, for example to daily medians.

## 9. Multivariate — `rakia_correlation`, `rakia_mahalanobis`

- **Correlation.** Pearson correlation over complete rows of standardised features, shrunk towards the identity: R = (1−λ)C + λI. Shrinkage keeps R invertible with few samples or collinear features.
- **Distance.** D² = zᵀR⁻¹z, computed by Cholesky decomposition. Per-feature contributions zᵢ(R⁻¹z)ᵢ sum exactly to D² and explain which features drive an unusual combination. They can be negative when features are correlated.
- **Error handling.** A non-symmetric or non-positive-definite matrix returns `RAKIA_E_SINGULAR`.
- **Status.** Not yet wired into `rakia_assess`. Integration and threshold selection come with the alerts work in Phase 6.

## 10. Ledger — `rakia_record_hash`, `rakia_chain_verify`

- **SHA-256.** Implemented from FIPS 180-4 and checked against the NIST example vectors, including one million "a" characters.
- **Canonical encoding v1.** Big-endian. Fields in order: domain tag `RAKIA/MEAS/1`, id, subject id, length-prefixed metric code and UCUM unit, IEEE 754 value bits (−0 normalised to +0), observed time in µs, method, provenance, client sequence number, previous hash. The golden test hashes come from an independent Python implementation using `hashlib`.
- **Chain verification.** Checks the link to the previous hash (or the genesis hash), a +1 sequence step, and that each recomputed hash matches.

The hash chain is **tamper-evident, not tamper-proof.** It detects edits to stored history, but it does not authenticate the device. Device signatures are planned for the sync protocol.

## 11. Testing

| Suite | Covers |
|---|---|
| `test_stats` | Median and MAD, invalid input, aliasing |
| `test_quality_baseline` | Quality flags, completeness, outlier-robust baseline, spread floor |
| `test_cusum` | Hand-computed step up and step down, missing samples, invalid configuration |
| `test_trend` | Exact line, outlier robustness, ties, hand-computed Mann–Kendall |
| `test_multivariate` | Identity and 2-D closed form, contributions sum, singular and asymmetric matrices, shrinkage |
| `test_ledger` | NIST vectors, golden chain, tamper/gap/genesis detection, encoding validation |
| `test_assess` | Every level and reason, including a reverted shift and the quality gate |
| `test_validation` | Synthetic scenarios and the cross-platform determinism digest |
| `test_flat` | The flat ABI gives bit-identical results to the struct API and rejects counts that are not exact integers |

CI also runs AddressSanitizer (MSVC), ASan + UBSan (Clang), clang-tidy, a 60-second libFuzzer run, and CodeQL.

## 12. Flat ABI and language bindings — `rakia_flat.h`

The structs in `rakia.h` contain `size_t` and pointer fields, so their layout differs between 64-bit targets, 32-bit Android (`armeabi-v7a`) and wasm32. `rakia_flat.h` adds struct-free wrappers for foreign-function callers: configurations and results are packed into `double` arrays with documented indices, and counts travel as doubles (exact up to 2^53). A count that is negative, fractional or non-finite returns `RAKIA_E_RANGE` or `RAKIA_E_NONFINITE` instead of being truncated. The wrappers only convert arguments, so they inherit the validation, determinism and no-allocation rules above. `RAKIA_FLAT_ABI_VERSION` is checked by the bindings at load time.

The Dart package [`core/dart`](../../core/dart/README.md) (`rakia_core`) uses this ABI:

- **Native.** A Dart build hook compiles librakia for Android, iOS, macOS, Linux and Windows, and the package calls it through `dart:ffi`.
- **Web.** Emscripten compiles librakia to a standalone WebAssembly module, which the package calls through `dart:js_interop`.

Both builds use the same floating-point flags as CMake. The Dart test suite ports `test_validation` and must reproduce the same determinism digest on the Dart VM and in Chrome. That shows the app gets bit-identical results from the same data on native and web builds.
