# RAKIA — Project Status

**Current phase:** Phase 5, core implementation. `librakia`, the app shell, the librakia bindings and the mission dashboard are merged; `feature/offline-store` is in review.
**Last updated:** 2026-11-06

## Completed

- [x] Environment inspection (see below)
- [x] Six design reference repos cloned to `_reference/design/` (all MIT; knowledge only, git-ignored)
- [x] Four colour references downloaded to `_reference/palette/` and measured (git-ignored)
- [x] Phase 1: research and originality report, in `docs/research/RESEARCH_AND_INNOVATION_REPORT.md`
- [x] Phase 2: design direction and tokens, in `docs/design/DESIGN_SYSTEM.md`
- [x] Phase 3: architecture and database design, in `docs/architecture/ARCHITECTURE.md`
- [x] Phases 1–3 approved by the owner
- [x] Public repository created: <https://github.com/jeswinbenedict/RAKIA> (default branch `main`, bootstrap commit with LICENSE, `.gitignore`, `.gitattributes`)
- [x] Repository settings: description, 14 topics, squash-merge only, delete branch on merge, wiki/projects off, discussions on
- [x] Foundation docs, issue and PR templates, CODEOWNERS, Dependabot (GitHub Actions) and repo-hygiene CI: [jeswinbenedict/RAKIA#1](https://github.com/jeswinbenedict/RAKIA/pull/1), merged
- [x] `main` ruleset requires the `Secret scan` and `Markdown and YAML lint` checks
- [x] Phase 5: `librakia` 0.1.0 C analytics core with tests, sanitizers, fuzzing and CodeQL: [jeswinbenedict/RAKIA#2](https://github.com/jeswinbenedict/RAKIA/pull/2), merged
- [x] `main` ruleset requires all 10 checks (repo hygiene, 7 core jobs, CodeQL c-cpp)
- [x] Phase 5: Flutter app shell (design system, adaptive navigation, module routes, accessibility tests): [jeswinbenedict/RAKIA#3](https://github.com/jeswinbenedict/RAKIA/pull/3), merged
- [x] `main` ruleset requires 15 checks (adds `app analyze and test` and the 4 `app build *` jobs)
- [x] Phase 5/6: librakia in the app via `dart:ffi` and WebAssembly: [jeswinbenedict/RAKIA#4](https://github.com/jeswinbenedict/RAKIA/pull/4), merged
- [x] `main` ruleset requires 19 checks (adds the 4 `app bindings *` jobs)
- [x] Repository-wide emoji removal and CI guard: [jeswinbenedict/RAKIA#5](https://github.com/jeswinbenedict/RAKIA/pull/5), merged
- [x] Phase 5: mission dashboard on the opt-in simulation mission, plus UI polish: [jeswinbenedict/RAKIA#6](https://github.com/jeswinbenedict/RAKIA/pull/6), merged
- [ ] Phase 5/6: on-device store (SQLite via Drift, hash-chained ledger, persistence of the simulation and preferences): `feature/offline-store`, in review

## Pending

- [ ] Review and merge `feature/offline-store` (owner approval required)
- [ ] `feature/store-encryption`: encryption at rest for the native store (must land before ingest stores real data)
- [ ] `feature/db-schema` (needs local PostgreSQL credentials in `.env`)
- [ ] `feature/auth` (needs a Firebase project and Turnstile keys)
- [ ] `feature/api-skeleton`, `feature/ingest`

## Environment

| Tool | Status |
|---|---|
| Git 2.53, GitHub CLI 2.96 | OK: logged in as `jeswinbenedict` |
| Flutter 3.47.7 / Dart 3.13.5 | OK: web (Chrome), Windows desktop OK |
| Android SDK 36.1 | Attention: licences not accepted (`flutter doctor --android-licenses`) |
| iOS | Unavailable: needs macOS; CI-only builds (GitHub macOS runner, unsigned) |
| MSVC 14.44 (VS Build Tools 2022) + bundled CMake, clang-tidy | OK: (not on PATH; will use a Developer shell or CMake presets) |
| PostgreSQL 18.6 | OK: service running; libpq headers present |
| Docker 29.7 | Attention: installed, daemon not running |
| Emscripten 6.0.13 (emsdk) | OK: installed in `C:\Users\jeswi\tools\emsdk` (outside the repo and OneDrive); same version pinned in CI |
| Supabase CLI 2.114, Firebase CLI 15.8, Node 25, Python 3.11 | OK |
| Perplexity | Attention: connected tool is dashboard-import only, with no search API |

## Phased plan & PR strategy

Branches: `main` (protected, PR-only) plus short-lived `feature/*`, `fix/*`, `docs/*` and `chore/*` branches. There is no `develop` branch. One PR per independently tested task; nothing is merged without owner approval.

| Phase | PRs |
|---|---|
| 4 Foundation | `docs/foundation` |
| 5 Core | `feature/db-schema` · `feature/librakia-core` · `feature/api-skeleton` · `feature/app-shell` · `feature/auth` · `feature/ingest` · `feature/dashboard` |
| 6 Intelligence | `feature/baselines-alerts` · `feature/offline-sync` · `feature/ffi-wasm` · one PR per monitoring module |
| 7 Hardening | security review, accessibility audit, responsive goldens, sync chaos tests |
| 8 Deploy | Cloudflare Pages + Cloud Run + Supabase, staging then production; monitoring; demo script |

## Active blockers / owner input needed

1. **Licence:** Apache-2.0 applied (recommended default). Tell me before the foundation PR merges if you prefer MIT.
2. **Firebase project:** create it and enable Google, Email/Password and Phone providers (needed for `feature/auth`).
3. **Cloudflare Turnstile:** site key and secret (put the secret in `.env`, never in chat).
4. **Local PostgreSQL credentials** in `.env` (needed for `feature/db-schema`).
5. **C++ API host:** confirm Google Cloud Run (needed by Phase 8).
6. Accept Android licences; start Docker Desktop if you want the local Supabase stack.

## Implemented features

- `librakia` 0.1.0 (experimental, not clinically validated): data-quality gate, robust personal baselines, CUSUM sustained-change detection with onset estimate, Theil–Sen/Mann–Kendall trend, Mahalanobis distance with per-feature contributions, SHA-256 hash-chained ledger, and quality-gated assessment levels. Details: `docs/algorithms/LIBRAKIA.md`.
- Flutter app shell: tokens and light/dark themes from the reference palette; bundled Geist fonts; adaptive navigation (bottom bar + More / icon rail / labelled sidebar); routes for all 9 modules with factual empty states; About page with disclaimer, theme choice and licences; status chip, simulated-data badge and empty-state components.
- librakia in the app: struct-free flat C ABI; Dart package `core/dart` with a native backend (build hook + `dart:ffi`) and a web backend (Emscripten WebAssembly + `dart:js_interop`); the app loads the core at startup and the About page reports the backend and a known-answer self-test.
- Mission dashboard: opt-in, deterministic simulation mission with known ground truth; Mission overview, Action center with six-part explainable alerts, detailed Cardiovascular / Sleep / Physical modules with baseline-band charts, and Data management with provenance and quality. Every status and number comes from librakia. Real data appears only after ingest and is never mixed with simulated data.
- On-device store (in review): SQLite through Drift on every platform (private app directory natively; OPFS or IndexedDB in a browser). SQLite triggers enforce immutable measurements, the simulation firewall, subject consistency, a continuous per-mission hash chain and simulation-only deletion; librakia re-verifies the chain on every load. The simulation mission and the theme choice survive restarts; without storage the app runs in memory and says why. Not yet encrypted at rest.

## Testing results

| Check | Result |
|---|---|
| Foundation PR #1 CI (secret scan, Markdown/YAML lint) | passed |
| librakia: MSVC 14.44 `/W4 /WX`, Release (local) | 8/8 test suites passed |
| librakia: MSVC AddressSanitizer (local) | 8/8 test suites passed |
| librakia: clang-tidy 19 over `core/src` (local) | 0 findings |
| librakia: Clang strict warnings (`-Wconversion -Wsign-conversion …`) via clang-tidy (local) | 0 findings in `src/` and `tests/` |
| librakia: synthetic validation (2,000 runs per scenario) | no-change `ACT` 1.7 %; +1.5 SD step detected 97.2 %, `ACT` 98.3 % |
| librakia CI on PR #2 (11 checks, incl. GCC, Clang ASan+UBSan, macOS ARM64, fuzzing, CodeQL) | all passed; determinism digest identical on every platform |
| app: `flutter analyze` (strict) | no issues |
| app: `flutter test` | 143/143 passed (contrast of every token pair in both themes, navigation per breakpoint, Android/iOS tap-target, labelled-target and text-contrast guidelines at 4 viewports × 2 themes × 3 pages, 200 % text scale, components) |
| app: `flutter build web --release`, `flutter build apk --debug` (local) | built |
| app: Windows and iOS builds | CI only (local Windows SDK lacks the debug CRT; iOS needs macOS) |
| librakia flat ABI: `test_flat` (MSVC `/W4 /WX`, local) | passed; all 9 C suites pass |
| librakia: all C sources, tests and fuzz harness with strict Clang warnings (Emscripten clang, local) | 0 warnings |
| rakia_core: `dart test` (native via build hook, MSVC, local) | 14/14 passed, including the C determinism digest |
| rakia_core: `dart test -p chrome` (WebAssembly, dart2js and dart2wasm, local) | 14/14 passed in each, same digest |
| librakia WebAssembly module (`check_wasm.mjs`, local) | 24,615 bytes; only import is the memory-growth notification; known answers OK |
| app: `flutter test` with the native core (local) | 147/147 passed |
| app: `flutter build apk --debug` (local) | built; `librakia.so` for arm64-v8a, armeabi-v7a, x86_64 |
| app: `flutter build web --release` served locally | About page shows librakia 0.1.0 running as WebAssembly, self-test passed |
| dashboard: `flutter test` (local) | 176/176 passed (29 new: determinism, outcomes vs ground truth, layout at 4 viewports, a11y guidelines in both themes, 200% text) |
| dashboard: simulated outcomes (librakia) | resting HR: Act, onset day 28 = injected day; sleep: data quality (27/45 usable); HRV: within baseline with significant declining trend (p = 1.4e-4); SpO2, exercise: within baseline |
| dashboard: visual review (web release, headless Chrome) | 1440 and 1280 px desktop in dark and light, 390 px phone |
| PR #5 and PR #6 CI | all checks passed; merged; `main` CI green after both merges |
| offline store: `flutter test` (local) | 205/205 passed (29 new: schema rules, exact round trip, reopen, newer-schema refusal, tamper and deletion detection, restart and theme persistence, unavailable-storage fallback, 200% text layout) |
| offline store: web release in headless Chrome | stored 509 records in IndexedDB, chain verified; mission restored after a full browser restart |

## Open pull requests

- `feature/offline-store`: on-device store (see GitHub)

## Next actions

After the store merges: `feature/store-encryption` needs no external input; `feature/db-schema` and `feature/auth` wait for credentials and keys.
