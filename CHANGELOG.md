# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Local database bootstrap (`db/bootstrap/`): `bootstrap-local.ps1` (Windows PowerShell 5.1+) and `bootstrap-local.sh` (Linux, macOS) create the `rakia_migrator` and `rakia_api` roles, the `rakia` database and schema, and `.env`:
  - The superuser password is asked at a hidden prompt; role passwords are 32 random characters from the system's secure generator and are never printed or passed on a command line.
  - Least privilege: neither role is a superuser or can create roles or databases or bypass row-level security; only these two roles may connect; `rakia_api` cannot create objects; passwords are stored as SCRAM verifiers.
  - Each role signs in and its privileges are checked before `.env` is written, readable only by the current user. An existing `.env` is never overwritten; running again after moving it away rotates both passwords.
  - CI runs both scripts against a disposable PostgreSQL with a password generated for the run.

- Encryption at rest for the native on-device store:
  - The database file is encrypted with ChaCha20-Poly1305 (SQLite3 Multiple Ciphers, the checksum-verified build shipped by the `sqlite3` package).
  - A 256-bit key is generated on the device, saved in the system keystore (Keychain, Android Keystore, DPAPI, libsecret) and read back before any data is written. It is never stored in the file, the repository or the app.
  - A database written before encryption is encrypted in place, keeping every record and setting.
  - A missing or wrong key leaves the data untouched and is reported; the key is never silently replaced. Opening fails if the loaded SQLite cannot encrypt or the file on disk is not encrypted.
  - Data management shows the cipher in use, or that browser storage is not encrypted.
  - Android cloud backup and device transfer of the app's data are turned off.
  - 11 new tests, against the real cipher: ciphertext on disk, key reuse, wrong and missing keys, a keystore that does not keep the key, a malformed key, in-place encryption of an existing database, and the storage card.

- On-device store (`app/lib/storage`), the offline-first foundation:
  - SQLite through Drift on every platform: a file in the app's private support directory on Android, iOS, Windows, macOS and Linux; SQLite WebAssembly on OPFS or IndexedDB in a browser.
  - Schema version 1 in plain SQL (`schema.drift`), with integrity rules enforced by SQLite triggers: immutable measurements, the simulation firewall (simulated records only in simulation missions and vice versa), subject consistency, a continuous hash chain per mission, and deletion allowed only for simulation data.
  - Each record is hashed with librakia (`rakia_flat_record_hash`) and linked to the previous one; the chain is re-verified on every load, and a failure is shown on the Data management page.
  - The simulation mission is saved, analysed as read back, restored after a restart and deleted when ended. The theme choice is remembered.
  - If storage cannot be opened, the app keeps working in memory and says so, with the reason.
  - Web assets: `tool/build_web_sqlite.sh` downloads `sqlite3.wasm` from the locked package release (SHA-256 pinned) and compiles the database worker from source.
  - 29 new tests: every schema rule, an exact round trip of the simulation, reopening a database file, refusal of a newer schema, tamper and deletion detection, restart and theme persistence in the app, the unavailable-storage fallback, and layout at 200% text.
  - CI checks that generated database code and the schema export are up to date, and that the web build ships the store.
- Data management shows where the mission is kept, how many records are stored, and whether the hash chain verified. The reading count now excludes days without a recording (509, not 525).
- Mission dashboard on a clearly labelled, opt-in simulation mission (`app/lib/simulation`, `app/lib/analytics`, `app/lib/mission`):
  - Deterministic scenario with known ground truth: a step change in resting heart rate, a gradual HRV decline, stable SpO2 and exercise, and a sleep-sensor outage.
  - Every status, baseline, onset, trend and quality figure computed by librakia (quality gate, robust baseline, assessment, Theil-Sen trend).
  - Mission overview: mission context, status counts, what needs attention, indicator cards with sparklines.
  - Action center: explainable alerts in six parts (what changed, by how much, since when, from which readings, why it matters, what to check next).
  - Cardiovascular, Sleep and Physical modules: baseline-band charts with onset markers, statistics, trend and the simulation ground truth.
  - Data management: provenance and per-indicator quality against the 70% gate.
  - Persistent simulation banner, hatched and watermarked charts, and an explicit "End simulation".
- UI polish: shared `SurfaceCard`, responsive card headers, brand mark in the navigation, RAKIA app icons for every platform (`app/tool/generate_icons.py`), branded web loading screen without a white flash, manifest and platform display names set to "RAKIA".
- 29 new tests: simulation determinism, analysis outcomes against ground truth, alert ranking, explanations, page content, layout containment at every viewport, accessibility guidelines in both themes and at 200% text.

- librakia in the app (`core/dart`, package `rakia_core`):
  - Struct-free flat ABI (`rakia_flat.h`, `src/flat.c`) so one marshalling layout serves 64-bit, 32-bit Android and wasm32 callers; new C test suite `test_flat` and fuzzing of the flat entry points.
  - Native backend: a Dart build hook compiles librakia for Android, iOS, macOS, Linux and Windows with the same floating-point flags as CMake; called through `dart:ffi`.
  - Web backend: librakia compiled to a standalone WebAssembly module with Emscripten (`tool/build_wasm.sh`, verified by `tool/check_wasm.mjs`); called through `dart:js_interop` under dart2js and dart2wasm.
  - The Dart tests reproduce the C suite's cross-platform determinism digest on native and in Chrome.
  - The app loads the core at startup, and the About page shows which backend is running and the result of a known-answer self-test, or the real error if it cannot load.
  - CI: binding tests on Linux, Windows and macOS, browser tests under dart2js and dart2wasm, and the web build now ships the module.
- Flutter app shell (`app/`):
  - Design tokens and light ("Ground") and dark ("Mission") themes from the reference palette; bundled Geist and Geist Mono fonts (OFL).
  - Adaptive navigation: bottom bar plus "More" sheet on phones, icon rail on tablets, labelled sidebar on laptops and desktops.
  - Routes for all 9 modules and an About page with the medical disclaimer, theme choice and licences.
  - Components: status chip (colour + shape + word), simulated-data badge, empty state.
  - Accessibility: visible focus rings, 48 dp targets, semantics on headings and statuses, reduced motion, no page-transition animation.
  - 143 tests.
- CI for the app: format, analyze and tests, plus web, Android, iOS (unsigned) and Windows builds.
- `librakia` 0.1.0 (`core/`): portable C11 analytics core. Includes a data-quality gate, robust personal baselines (median/MAD), two-sided CUSUM with onset estimation, Theil–Sen/Mann–Kendall trend, shrunk correlation and Mahalanobis distance with per-feature contributions, SHA-256 and a hash-chained measurement ledger, and a quality-gated assessment (`INSUFFICIENT_DATA`, `DATA_QUALITY`, `WITHIN_BASELINE`, `WATCH`, `ACT`). Experimental; not clinically validated.
- 8 test suites, including NIST SHA-256 vectors, independent golden ledger hashes, synthetic validation scenarios and a cross-platform determinism digest.
- CI: MSVC, MSVC+ASan, GCC, Clang ASan+UBSan, macOS ARM64, clang-tidy, a 60-second libFuzzer run, and CodeQL (C/C++).
- `docs/algorithms/LIBRAKIA.md`: algorithms, assumptions, validation results and limitations.
- Repository foundation: README, Apache-2.0 licence, contributing guide, Code of Conduct (Contributor Covenant 2.1), security policy, issue and PR templates, CODEOWNERS, Dependabot for GitHub Actions, and a repository-hygiene CI workflow (secret scan, Markdown lint, YAML validation).
- Phase 1–3 documents: research and innovation report, design system specification, and architecture and database design.
- Development, roadmap and known-limitations documentation; `.env.example`.
