# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Zero-cost hosting: every hosted service runs on a free plan that needs no payment method.
  - `render.yaml`: Render Blueprint for the API, with free Docker web services for staging (deploys on push to `main`) and production (manual). Secrets are entered in Render and never stored in the file.
  - [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md): a cost table with each free plan's limits; the API on Render, with Cloud Run as an alternative that needs billing; the database through Supabase's session pooler (IPv4, `verify-full`); Pages project `rakia-app`; and backups by `pg_dump`, since the free plan has none.
- The API refuses to connect as `postgres`, `supabase_admin` or `rakia_migrator` when the role carries a pooler suffix (`<role>.<project ref>`), not only under the bare names. Tests cover both forms and accept `rakia_api.<ref>`.

### Removed

- `RAKIA_SUPABASE_URL` and `RAKIA_SUPABASE_SERVICE_ROLE_KEY` from `.env.example`: nothing used them (the API connects to PostgreSQL directly), and a slot for a service-role key invited storing one.

- CI keeps building through a GitHub download outage: pinned dependency archives (nlohmann/json, cpp-httplib), the Gradle distribution and the SQLite native and WebAssembly binaries are cached between runs and reused only when they match their pinned SHA-256. The Gradle wrapper now verifies its distribution checksum, and the API image accepts the cached archives as an optional build context.
- Sign-in on the API: Firebase ID-token verification and `GET /v1/me`:
  - Tokens are verified as Firebase documents for third-party servers: RS256 only (never `none` or HMAC), a key id from Google's published X.509 certificates, a valid signature, `aud` and `iss` naming the project, `exp`, `iat` and `auth_time` within 60 s of clock leeway, and a well-formed `sub`. No Firebase service account or admin secret is used.
  - Google's certificates are fetched over verified HTTPS, cached for their advertised `max-age` (between a minute and a day) and refreshed at most once a minute when an unknown key id appears.
  - `GET /v1/me` creates the caller's account on first use and returns it with their mission roles, as that user, so row-level security applies. Without a token: 401 with a `WWW-Authenticate: Bearer` challenge; with an invalid one: 401 `invalid_token`; without a configured project: 503. Refusals are logged with a reason code, never the token.
  - `RAKIA_FIREBASE_PROJECT_ID`: validated, optional in development, required in staging and production.
  - 20 new tests: every refusal reason against real RS256 tokens signed with generated keys (wrong algorithm, unknown or missing key id, another key, altered payload, short signature, expiry and future times, audience, issuer, subject, missing claims, malformed input, non-canonical base64url, weak certificates), the endpoint over HTTP, account creation and refusal of someone else's account in PostgreSQL (rolled back), configuration, and a live fetch of Google's certificates in CI. CI also runs the binary with a project id and checks forged tokens are refused and never logged.
- OpenSSL 3 is a new build dependency of the API (TLS client for Google's certificates and RSA signature checks).

- Behavioural health: private check-ins and a reaction-time test (`app/lib/wellbeing`, `app/lib/features/wellbeing_page.dart`, `check_in_page.dart`, `reaction_test_page.dart`):
  - Check-ins ask about sleepiness (Karolinska Sleepiness Scale, all nine steps labelled), stress (single-item measure of stress symptoms, Elo and colleagues, 2003) and mood (a simple self-rating, labelled as not a validated scale). Each question shows its source; nothing is saved until all three are answered.
  - A 3-minute reaction-time test after PVT-B (1 to 4 s intervals, 355 ms lapses, 100 ms false starts, 30 s timeout). It responds to pointer down, Space and Enter, and times each stimulus from the frame that shows it. It reports median response time, mean response speed, lapses and false starts, and saves only if the astronaut chooses.
  - History with a trace per question, the latest answer in words, and the device each test ran on; no scores, interpretation or alerts.
  - The records belong to no mission, so they never mix with simulated data. They are stored in the encrypted on-device database, cannot be edited, and can all be deleted by the astronaut after a confirmation. Without storage they are kept in memory and the page says so.
- On-device schema version 2 (`self_checkins`, `reaction_tests`), with the first real migration step. `test/migration_test.dart` upgrades a version 1 database and checks it matches the current schema exactly, with data kept; CI checks the generated migration helpers are current.
- 33 new tests: scoring, the test session on a controlled clock, store rules (ranges, immutability, deletion that leaves missions untouched), the in-memory fallback, migrations, the full check-in and test flows in the app, restart and deletion, accessibility guidelines in both themes and layout at four viewports with 200% text.
- Deployment readiness:
  - `server/Dockerfile`: multi-stage image for Cloud Run; the unit and HTTP tests run during the build; the binary runs as a non-root user; production mode by default (no `.env` file read, verified TLS to the database required); Debian base pinned by digest, with Dependabot tracking it.
  - `RAKIA_DB_SSLROOTCERT` for the API and the migration runner: a CA certificate file for providers with a private CA (Supabase), or the system roots (the default with `verify-full`).
  - A self-contained web build (`--csp --no-web-resources-cdn`): CanvasKit and every other resource from the app's own origin, so the web app also loads offline from its cache and makes no third-party requests. The splash screen's inline style and script moved into files.
  - `app/web/_headers`: Content-Security-Policy without inline scripts, cross-origin isolation (the browser database now uses the Origin Private File System), HSTS, framing and referrer protection.
  - `app/tool/web/serve_with_headers.mjs` and `check_web_build.mjs`: serve a build with its own headers and check it in headless Chrome (renders, no CSP violations, console errors or external requests, cross-origin isolated, database on OPFS); CI runs the check on every web build.
  - CI builds the container image, checks it runs as a non-root user, refuses to start in production without TLS to the database, serves and reports ready against PostgreSQL, and stops cleanly.
  - [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md): database roles and migrations on a hosted PostgreSQL, Cloud Run with secrets and probes, Cloudflare Pages, native builds.
- CodeQL fetches the API's third-party headers outside the checkout, so its results cover RAKIA's own code (the 159 open alerts were all in cpp-httplib and nlohmann/json).

- C++ API skeleton (`server/`, `rakia-api` 0.1.0):
  - Endpoints `GET /v1/health`, `GET /v1/ready` (database reachable and schema at the version this build expects) and `GET /v1/metric-definitions`, described in `docs/api/openapi.yaml`.
  - Configuration from environment variables, validated at start-up: TLS to the database (`verify-full`) and public https CORS origins outside development; refuses to connect as the migrator or a superuser; secrets never logged.
  - Security headers and `Cache-Control: no-store` on every response, exact-match CORS allow-list with preflight limits, per-address rate limiting with `Retry-After` (health probes exempt), request ids, JSON errors that never include database messages, JSON access logs without addresses or bodies, a 1 MiB body limit and a clean stop on SIGTERM.
  - libpq connection pool as `rakia_api`: lazy connections that recover after an outage, bound parameters only, one transaction per request with the caller in `request.jwt.claims`, statement and idle-transaction timeouts.
  - cpp-httplib 0.62.0 and nlohmann/json 3.12.0, fetched at configure time and checked against pinned SHA-256 hashes.
  - 44 tests: configuration, CORS, rate limiting, HTTP behaviour over a real socket, and PostgreSQL integration; CI builds with GCC, Clang (ASan and UBSan) and MSVC, runs the binary end to end and lints the OpenAPI description.
- Migration `0002_schema_version`: `rakia.schema_version()` lets the API check the schema without reading the migration history.

- PostgreSQL schema, migrations and their tests (`db/`):
  - Migration `0001_core`: users, missions and membership with five roles, crew members, the app's five indicators, data sources, devices, app installations (`clients`), measurements, sync batches, alerts and their status history, an append-only audit log and Turnstile replay protection.
  - Integrity rules enforced by the database whoever writes: the simulation firewall in both directions, units that must match the indicator, finite values, crew members of the same mission, a continuous hash chain per client and mission, immutable measurements with corrections that supersede a record of the same series, deletion only of simulation data, alert status changed only through recorded events.
  - Row-level security for `rakia_api`, keyed on the verified Firebase uid in `request.jwt.claims`: astronauts see only their own health data, medical staff the whole crew's, the mission admin none; outsiders and unauthenticated requests see nothing.
  - The audit log is hash-chained (SHA-256), append-only even for the owner role, and verifiable with `rakia.verify_audit_chain()`.
  - A Dart migration runner (`dart run bin/migrate.dart status | up | down`) that applies each migration in a transaction under an advisory lock and refuses edited or unknown migrations.
  - 54 tests, run in CI against a disposable PostgreSQL 18.

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

### Changed

- Phone (SMS) sign-in is no longer planned: Firebase sends SMS only on its paid plan. Email/password and Google remain.
- The Behavioural health module describes what it does (it previously listed isolation and workload reports and sharing, which do not exist).

### Fixed

- Two store tests hard-coded schema version numbers; they now follow `RakiaDatabase.currentSchemaVersion`.
