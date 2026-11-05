# Development Guide

> Status: the application components do not exist yet. This guide lists the toolchain and conventions that later PRs will follow. Sections marked **(planned)** are filled in as each component lands.

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

## Repository layout (target)

```text
app/          Flutter application (planned)
core/         librakia — C11 analytics core (planned)
server/       rakia-api — C++20 service (planned)
db/           SQL migrations, RLS policies, tests (planned)
tools/        simulator and developer scripts (planned)
docs/         research, architecture, design, guides
```

## Local configuration

1. Copy `.env.example` to `.env` and fill in values locally. `.env` is git-ignored.
2. Local PostgreSQL: create a `rakia` database and the `rakia_migrator` / `rakia_api` roles **(planned: script in `db/`)**.

## Building and running **(planned)**

Each component PR adds its exact build, run and test commands here.

## Testing

| Layer | Command | Status |
|---|---|---|
| Repository hygiene | runs in CI (`.github/workflows/repo-hygiene.yml`); locally: `npx markdownlint-cli2 "**/*.md"` | active |
| C core | `ctest` with sanitizers | planned |
| API | integration tests against disposable Postgres | planned |
| Database | migration + RLS tests | planned |
| Flutter | `flutter analyze`, `flutter test`, golden + integration tests | planned |

## Environments

| Environment | App | API | Database | Auth | Turnstile |
|---|---|---|---|---|---|
| development | `flutter run` (Chrome/Windows/Android) | local `rakia-api` | local PostgreSQL 18 | Firebase dev project | Cloudflare test keys |
| staging | Cloudflare Pages preview branch | Cloud Run staging service | Supabase staging project | Firebase staging project | staging widget |
| production | Cloudflare Pages | Cloud Run production service | Supabase production project | Firebase production project | production widget |

Secrets for staging and production live in the hosting providers' secret stores and in GitHub Actions environment secrets, never in the repository.

## Deployment **(planned, Phase 8)**

Described in [architecture §9](architecture/ARCHITECTURE.md#9-deployment).
