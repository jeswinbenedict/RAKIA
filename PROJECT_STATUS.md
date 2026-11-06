# RAKIA — Project Status

**Current phase:** Phase 5, core implementation. `librakia` and the app shell are merged; `feature/ffi-wasm` (librakia in the app) is in review.
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
- [ ] Phase 5/6: librakia in the app via `dart:ffi` and WebAssembly (`feature/ffi-wasm`, in review)

## Pending

- [ ] Review and merge `feature/ffi-wasm` (owner approval required); then add the `app bindings *` checks to the required checks
- [ ] `feature/db-schema` (needs local PostgreSQL credentials in `.env`)
- [ ] `feature/auth` (needs a Firebase project and Turnstile keys)
- [ ] `feature/api-skeleton`, `feature/ingest`, `feature/dashboard`

## Environment

| Tool | Status |
|---|---|
| Git 2.53, GitHub CLI 2.96 | ✅ logged in as `jeswinbenedict` |
| Flutter 3.47.7 / Dart 3.13.5 | ✅ web (Chrome), Windows desktop OK |
| Android SDK 36.1 | ⚠️ licences not accepted (`flutter doctor --android-licenses`) |
| iOS | ❌ needs macOS; CI-only builds (GitHub macOS runner, unsigned) |
| MSVC 14.44 (VS Build Tools 2022) + bundled CMake, clang-tidy | ✅ (not on PATH; will use a Developer shell or CMake presets) |
| PostgreSQL 18.6 | ✅ service running; libpq headers present |
| Docker 29.7 | ⚠️ installed, daemon not running |
| Emscripten 6.0.13 (emsdk) | ✅ installed in `C:\Users\jeswi\tools\emsdk` (outside the repo and OneDrive); same version pinned in CI |
| Supabase CLI 2.114, Firebase CLI 15.8, Node 25, Python 3.11 | ✅ |
| Perplexity | ⚠️ connected tool is dashboard-import only, with no search API |

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
- Flutter app shell: tokens and light/dark themes from the reference palette; bundled Geist fonts; adaptive navigation (bottom bar + More / icon rail / labelled sidebar); routes for all 9 modules with factual empty states; About page with disclaimer, theme choice and licences; status chip, simulated-data badge and empty-state components. No health data is displayed yet.
- librakia in the app (in review): struct-free flat C ABI; Dart package `core/dart` with a native backend (build hook + `dart:ffi`) and a web backend (Emscripten WebAssembly + `dart:js_interop`); the app loads the core at startup and the About page reports the backend and a known-answer self-test.

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

## Open pull requests

- `feature/ffi-wasm`: librakia in the app via `dart:ffi` and WebAssembly (see GitHub)

## Next actions

After `feature/ffi-wasm` merges: `feature/dashboard` (first module views on real librakia output, no external input needed), or `feature/db-schema` / `feature/auth` once credentials and keys are provided.
