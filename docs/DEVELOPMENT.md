# Development Guide

> Status: librakia, its Dart bindings, the Flutter app with its mission dashboard, and the on-device store exist. The server and database are planned; sections marked **(planned)** are filled in as each component lands.

## Prerequisites

| Tool | Version used | Needed for |
|---|---|---|
| Git | 2.4x+ | everything |
| Flutter / Dart | 3.47 / 3.13 (stable) | `app/` |
| CMake | 3.25+ | `core/`, `server/` |
| C/C++ compiler | MSVC 2022 (Windows), GCC 13+ or Clang 17+ (Linux/macOS) | `core/`, `server/` |
| vcpkg | latest | C++ dependencies (manifest mode) |
| PostgreSQL | 18 | local database |
| Docker (optional) | 29+ | local Supabase stack, Linux container builds |
| Supabase CLI (optional) | 2.x | staging/production migrations |
| Firebase CLI (optional) | 15.x | auth project configuration |
| Emscripten | 6.0.13 (pinned in CI) | librakia WebAssembly module for the web build |

## Repository layout (target)

```text
app/          Flutter application
core/         librakia — C11 analytics core (core/dart: Dart bindings)
server/       rakia-api — C++20 HTTP API
db/           SQL migrations, migration runner, bootstrap scripts, tests
tools/        simulator and developer scripts (planned)
docs/         research, architecture, design, guides
```

## Local configuration

1. Local PostgreSQL (18): run the bootstrap script from the repository root. It asks for your PostgreSQL superuser password at a hidden prompt, generates random passwords for `rakia_migrator` and `rakia_api`, creates both roles and the `rakia` database and schema, signs in as each role to check its privileges, and writes `.env` readable only by you. It never prints a password and never overwrites an existing `.env`.

   ```bash
   powershell -ExecutionPolicy Bypass -File db\bootstrap\bootstrap-local.ps1   # Windows
   ```

   ```bash
   sh db/bootstrap/bootstrap-local.sh                                         # Linux, macOS
   ```

   Options: `-SuperUser`, `-DbHost`, `-Port`, `-Psql` (PowerShell) or `--superuser`, `--host`, `--port` (shell). To get new passwords, move `.env` away and run it again; the old passwords stop working.
2. Other values in `.env` (Firebase, Turnstile, Supabase) are filled in by hand when those services are set up. `.env` is git-ignored; never commit it or paste its values anywhere.

## Building and running

### librakia (`core/`)

See [core/README.md](../core/README.md). Summary:

```bash
cmake -S core -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```

### librakia Dart bindings (`core/dart/`)

See [core/dart/README.md](../core/dart/README.md). The build hook compiles librakia automatically for native targets. On Windows it uses MSVC through `vswhere`, so no Developer shell is needed. The web build needs the WebAssembly module, built once with Emscripten:

```bash
cd core/dart
dart test                                          # native
sh tool/build_wasm.sh ../../app/web/rakia/rakia.wasm
dart test -p chrome                                # WebAssembly
```

`app/web/rakia/` is git-ignored. CI builds the module from source for every web build.

### Flutter app (`app/`)

```bash
cd app
flutter pub get
flutter run -d chrome        # or: windows, an Android device or emulator
flutter test
flutter build web --release --csp --no-web-resources-cdn
```

The web build also needs the SQLite WebAssembly module and the database worker for the local store, prepared once (and again after updating `drift` or `sqlite3`):

```bash
sh tool/build_web_sqlite.sh    # from app/; output in app/web/sqlite3/ (git-ignored)
```

It downloads `sqlite3.wasm` from the official release of the locked `sqlite3` package, checks the pinned SHA-256, and compiles `drift_worker.js` from `tool/web/drift_worker.dart`. Without these files the web app still runs, but says local storage is unavailable and keeps nothing after closing.

### API (`server/`)

C++20 with CMake 3.24+. cpp-httplib and nlohmann/json are fetched at configure time and checked against pinned SHA-256 hashes (`server/cmake/dependencies.cmake`); libpq and OpenSSL 3 come from the system (`libpq-dev` and `libssl-dev` on Debian and Ubuntu; on Windows the PostgreSQL installation ships both, so pass `-DOPENSSL_ROOT_DIR` with the same path as `-DPostgreSQL_ROOT`). The ID-token tests sign real RS256 tokens with keys they generate; set `RAKIA_API_NETWORK_TESTS=1` to also fetch and parse Google's live certificates.

```bash
cmake -S server -B server/build -DCMAKE_BUILD_TYPE=Release   # Windows: add -DPostgreSQL_ROOT="C:/Program Files/PostgreSQL/18" -DOPENSSL_ROOT_DIR="C:/Program Files/PostgreSQL/18"
cmake --build server/build --parallel
ctest --test-dir server/build --output-on-failure
```

On Windows, configure from a Visual Studio developer shell (`vcvars64.bat`). In development the binary reads `./.env` from its working directory, and the process environment wins; with `RAKIA_ENV` set to `staging` or `production` it reads no file and takes every setting from the environment. Run it from the repository root after the bootstrap and migrations:

```bash
./server/build/rakia-api      # then: curl http://127.0.0.1:8080/v1/ready
```

`RAKIA_DB_USER` must be `rakia_api`; the API refuses the migrator and superusers. The PostgreSQL integration tests are read-only and run with `RAKIA_API_PG_TESTS=1` against a migrated database (`RAKIA_ENV_FILE` selects the settings). The endpoints are described in `docs/api/openapi.yaml`; lint it with `npx @redocly/cli@2.65.0 lint --config docs/api/redocly.yaml docs/api/openapi.yaml`.

### Database (`db/`)

Migrations are numbered SQL files in `db/migrations/` (`NNNN_name.up.sql` and `NNNN_name.down.sql`), applied as `rakia_migrator` by a small Dart runner with the settings in `.env`. Run from `db/`:

```bash
dart run bin/migrate.dart status        # applied and pending migrations
dart run bin/migrate.dart up            # apply all pending (or --to N)
dart run bin/migrate.dart down          # revert the last one (or --steps N)
```

Each migration runs in its own transaction under an advisory lock. The runner records a SHA-256 of every applied script and refuses to run if one was edited afterwards: never change an applied migration, add a new one. Every migration needs a down script that reverts it completely.

The tests in `db/test` (migration round trip, row-level security per role, integrity rules, the audit chain) **reset the schema and destroy its data**. They run only with `RAKIA_DB_ALLOW_RESET=1`, and only against a disposable database, never one holding anything of value:

```bash
RAKIA_DB_ALLOW_RESET=1 RAKIA_ENV_FILE=/path/to/throwaway.env dart test
```

Without that variable the database tests are skipped and only the file checks run. CI runs everything against a disposable PostgreSQL 18.

### Local store (`app/lib/storage/`)

The schema, including the triggers that enforce immutability, the simulation firewall and hash-chain continuity, is plain SQL in `lib/storage/schema.drift`. After changing it:

```bash
dart run build_runner build --delete-conflicting-outputs     # regenerates database.g.dart
dart run drift_dev schema dump lib/storage/database.dart drift_schemas/
dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
dart format test/generated_migrations
```

Bump `RakiaDatabase.currentSchemaVersion`, add the step to `onUpgrade` in `lib/storage/database.dart`, and commit the regenerated code, the new schema export and the regenerated migration helpers; CI fails if any is stale. `test/migration_test.dart` upgrades a database of every earlier version and checks the result matches the current schema exactly, so a missing or wrong step fails the tests. Version 2 added the private wellbeing tables (`self_checkins`, `reaction_tests`). Native databases live in the app's private support directory (`rakia.sqlite`), never in the documents folder.

Native databases are encrypted at rest. `pubspec.yaml` selects the SQLite3 Multiple Ciphers build of the `sqlite3` package (`hooks: user_defines: sqlite3: source: sqlite3mc`), downloaded by its build hook and checked against the SHA-256 published with the package. On first launch RAKIA generates a 256-bit key, saves it with `flutter_secure_storage` under `rakia.store.key.v1`, reads it back, and only then creates the database; a database from before encryption is encrypted in place (`PRAGMA rekey`). Opening refuses to continue if the loaded SQLite has no cipher or the file on disk is not encrypted. Tests run against the same library, so `flutter test` exercises real encryption (`test/store_encryption_test.dart`). Building for Linux needs `libsecret-1-dev`; macOS uses the login keychain and needs no extra entitlement. To inspect a development database, use a SQLite3 Multiple Ciphers shell with the key from the keystore; never copy the key into the repository.

App icons for every platform are generated from one design: `python -I tool/generate_icons.py` (run from `app/`, needs Pillow). It redraws each existing icon file at its current size.

The Mission overview offers a **simulation mission** when no real mission exists. It is deterministic, clearly labelled and opt-in; use it to explore and test the dashboard.

Other components add their commands here as they land.

## Testing

| Layer | Command | Status |
|---|---|---|
| Repository hygiene | runs in CI (`.github/workflows/repo-hygiene.yml`); locally: `npx markdownlint-cli2 "**/*.md"` | active |
| C core | `ctest --test-dir build` (add `-DRAKIA_SANITIZE=ON` for sanitizers); `clang-tidy -p build core/src/*.c` | active |
| API | CI (`.github/workflows/api.yml`): GCC, Clang with ASan and UBSan, and MSVC builds with warnings as errors; unit tests (configuration, CORS, security headers, request ids, rate limiting, proxy addresses) and HTTP tests over a real socket (routes, readiness states, JSON errors without database messages, CORS preflight, 429 with `Retry-After`, body limit); integration against a disposable PostgreSQL 18 as `rakia_api` (schema version, reference data, transaction-local caller claims, bound parameters, rollback, SQLSTATEs, privileges, unreachable database); the binary end to end with a clean SIGTERM stop and no password in its log; OpenAPI lint | active |
| Database bootstrap | CI (`.github/workflows/db.yml`): ShellCheck and PSScriptAnalyzer, then both scripts against a disposable PostgreSQL with a per-run password, checking privileges, refusal to overwrite `.env`, and password rotation | active |
| Database | CI (`db schema` job): `dart format`, `dart analyze --fatal-infos`, migrations up, status and idempotency, then `dart test` (round trip, refusal of edited or unknown migrations, row-level security for every role, privileges of `rakia_api`, simulation firewall, units, hash-chain continuity, immutability, corrections, alert transitions, audit chain and tamper detection, Turnstile replay) | active |
| Dart bindings | `dart test` (native), `dart test -p chrome` and `--compiler dart2wasm` (WebAssembly); both reproduce the C determinism digest | active |
| Flutter | `dart format --set-exit-if-changed lib test tool`, `flutter analyze`, `flutter test` (tokens, navigation, accessibility guidelines, 200% text scale, components, analytics core loading, dashboard, local store rules and persistence) | active |

## Environments

| Environment | App | API | Database | Auth | Turnstile |
|---|---|---|---|---|---|
| development | `flutter run` (Chrome/Windows/Android) | local `rakia-api` | local PostgreSQL 18 | Firebase dev project | Cloudflare test keys |
| staging | Cloudflare Pages, `staging` branch (`staging.rakia-app.pages.dev`) | Render `rakia-api-staging` | Supabase `rakia-staging` | Firebase `rakia-staging` | staging widget |
| production | Cloudflare Pages (`rakia-app.pages.dev`) | Render `rakia-api` | Supabase production project | Firebase `rakia-production` | production widget |

Secrets for staging and production live in Render's encrypted environment variables and secret files, never in the repository. Every hosted service runs on a free plan without a payment method; see [DEPLOYMENT.md](DEPLOYMENT.md#zero-cost-hosting).

## Deployment

Step-by-step instructions for the database, the API on Render, the web app on Cloudflare Pages and the native apps are in [DEPLOYMENT.md](DEPLOYMENT.md). The reasoning behind the hosting choices is in [architecture §9](architecture/ARCHITECTURE.md#9-deployment).
