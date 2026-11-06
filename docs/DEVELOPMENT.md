# Development Guide

> Status: librakia, its Dart bindings and the Flutter app shell exist. The server and database are planned; sections marked **(planned)** are filled in as each component lands.

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
server/       rakia-api — C++20 service (planned)
db/           SQL migrations, RLS policies, tests (planned)
tools/        simulator and developer scripts (planned)
docs/         research, architecture, design, guides
```

## Local configuration

1. Copy `.env.example` to `.env` and fill in values locally. `.env` is git-ignored.
2. Local PostgreSQL: create a `rakia` database and the `rakia_migrator` / `rakia_api` roles **(planned: script in `db/`)**.

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
flutter build web --release
```

App icons for every platform are generated from one design: `python -I tool/generate_icons.py` (run from `app/`, needs Pillow). It redraws each existing icon file at its current size.

The Mission overview offers a **simulation mission** when no real mission exists. It is deterministic, clearly labelled and opt-in; use it to explore and test the dashboard.

Other components add their commands here as they land.

## Testing

| Layer | Command | Status |
|---|---|---|
| Repository hygiene | runs in CI (`.github/workflows/repo-hygiene.yml`); locally: `npx markdownlint-cli2 "**/*.md"` | active |
| C core | `ctest --test-dir build` (add `-DRAKIA_SANITIZE=ON` for sanitizers); `clang-tidy -p build core/src/*.c` | active |
| API | integration tests against disposable Postgres | planned |
| Database | migration + RLS tests | planned |
| Dart bindings | `dart test` (native), `dart test -p chrome` and `--compiler dart2wasm` (WebAssembly); both reproduce the C determinism digest | active |
| Flutter | `dart format --set-exit-if-changed lib test`, `flutter analyze`, `flutter test` (tokens, navigation, accessibility guidelines, 200% text scale, components, analytics core loading) | active |

## Environments

| Environment | App | API | Database | Auth | Turnstile |
|---|---|---|---|---|---|
| development | `flutter run` (Chrome/Windows/Android) | local `rakia-api` | local PostgreSQL 18 | Firebase dev project | Cloudflare test keys |
| staging | Cloudflare Pages preview branch | Cloud Run staging service | Supabase staging project | Firebase staging project | staging widget |
| production | Cloudflare Pages | Cloud Run production service | Supabase production project | Firebase production project | production widget |

Secrets for staging and production live in the hosting providers' secret stores and in GitHub Actions environment secrets, never in the repository.

## Deployment **(planned, Phase 8)**

Described in [architecture §9](architecture/ARCHITECTURE.md#9-deployment).
