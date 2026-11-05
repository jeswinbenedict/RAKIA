# RAKIA — Project Status

**Current phase:** Phase 4, repository foundation (Phases 1–3 approved by the owner on 2026-11-06).
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
- [x] Foundation docs, issue and PR templates, CODEOWNERS, Dependabot (GitHub Actions) and repo-hygiene CI (in the foundation PR)

## Pending (Phase 4)

- [ ] Foundation PR review and merge (owner approval required)
- [ ] Mark the CI checks as required in the `main` ruleset once they have run on `main`
- [ ] CodeQL: enabled when the first C/C++ code lands (CodeQL has nothing to analyse in a docs-only repo, and it does not support Dart)

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

None yet. Phase 4 is documentation and governance only.

## Testing results

| Check | Result |
|---|---|
| markdownlint-cli2 0.24.0 (local) | 0 issues across 13 files |
| YAML validation of `.github/**` (local) | all files parse |
| CI on the foundation PR | see the PR checks |

## Open pull requests

- `docs/foundation`: repository foundation (see GitHub)

## Next actions

After the foundation PR merges: `feature/db-schema` (needs PostgreSQL credentials) and `feature/librakia-core` (no external input needed).
