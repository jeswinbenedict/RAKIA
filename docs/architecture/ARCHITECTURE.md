# RAKIA — System Architecture & Database Design

> Phase 3 deliverable · Status: **DRAFT FOR APPROVAL**

## 1. Overview

```text
┌──────────────────────── Crew device (onboard, offline-first) ────────────────────────┐
│ Flutter app (Android · iOS · Web · Windows/macOS/Linux)                               │
│  UI ─ Riverpod state ─ Repository ─┬─ Local store: SQLite via Drift (web: sqlite3.wasm)│
│                                    ├─ librakia (C11) via dart:ffi  | via WASM on web  │
│                                    └─ Sync agent (ledger, outbox, retries)            │
└───────────────┬───────────────────────────────────────────────────────────────────────┘
                │ HTTPS/TLS 1.3 · Firebase ID token · idempotent batches (delay-tolerant)
┌───────────────▼──────────── Ground / habitat server ──────────────────────────────────┐
│ rakia-api (C++20, cpp-httplib + libpq)                                                │
│  auth (Firebase ID-token verify, RBAC) · turnstile verify · ingest/sync · query API   │
│  analytics worker → librakia (same C core) · SSE stream for live updates · /healthz   │
└───────────────┬───────────────────────────────────────────────────────────────────────┘
                │ libpq, TLS, least-privilege role
┌───────────────▼───────────────┐      ┌────────────────────┐   ┌──────────────────────┐
│ PostgreSQL 18 (dev: local)    │      │ Firebase Auth      │   │ Cloudflare Turnstile │
│ prod: Supabase Postgres + RLS │      │ Google/email/phone │   │ siteverify           │
└───────────────────────────────┘      └────────────────────┘   └──────────────────────┘
```

## 2. Components and why each language

| Component | Language | Responsibility | Why |
|---|---|---|---|
| `core/librakia` | **C11** | Baselines, robust statistics, CUSUM onset, Theil–Sen trend, multivariate robust distance + per-feature contributions, quality gates, hash chaining | Must run *identically* on servers, phones, browsers (WASM) and potentially embedded habitat hardware. C gives the smallest, most portable ABI for `dart:ffi` and Emscripten. No allocation in hot paths; caller-owned buffers; fuzzed. |
| `server/rakia-api` | **C++20** (cpp-httplib and nlohmann/json, both MIT and header-only; libpq) | REST API, auth, RBAC, ingest/sync, query, SSE, analytics jobs | Performance and the challenge's C/C++ requirement where it fits; RAII for resource safety. Drogon was the first choice; the skeleton uses cpp-httplib instead because it is a single pinned header with no further native dependencies (Drogon needs jsoncpp, OpenSSL, zlib, uuid and its own build), its thread-pool model is ample for crew-sized load, and TLS terminates in front of the API anyway. The HTTP layer is confined to `app.cpp`, so it can be replaced if load ever requires. |
| `app/` | **Dart/Flutter** | All UI, offline store, sync agent | Required stack; one codebase for 6 targets. |
| `db/migrations` | SQL | Versioned schema, RLS, audit triggers | Plain SQL, tool-agnostic (applied by a small migration runner + compatible with `supabase db push`). |
| `tools/simulator` | C++ (CLI) | Generates labelled SIMULATED scenarios with known ground truth (step, drift, artefact, missing data) | Same engine for validation tests. **Status:** the in-app simulation mission (`app/lib/simulation`) implements the same scenario types in Dart today, with the same deterministic generator as the C test suite; the CLI is still planned for server-side seeding. |

**Not forced into C/C++:** UI, auth UX, and the web host stay in their natural stacks.

Key C++/C deps (all permissive): Drogon, libpq, jwt-cpp, OpenSSL, nlohmann/json, GoogleTest. Managed with vcpkg manifest. Flutter deps kept minimal: riverpod, go_router, drift, firebase_auth, google_sign_in, ffi, a charting approach decided in Phase 5 (custom painters preferred for the baseline-band chart).

## 3. Communication

- **REST/JSON over HTTPS** (OpenAPI 3.1 spec in `docs/api/openapi.yaml`). gRPC rejected for v1: poor browser support without a proxy and no benefit at our data rates.
- **Live updates:** Server-Sent Events from `rakia-api` (dev/self-hosted); in production, Supabase Realtime may be added as an optimisation, not a dependency.
- **Sync protocol:** client sends `POST /v1/sync/batches` with `{client_id, batch_id (UUIDv7), records[] (each with client_seq, prev_hash, hash)}`. Server verifies chain continuity, is idempotent on `batch_id`, and returns `acked_through_seq` + server-side changes since cursor. Conflict rules: measurements are immutable (no conflicts; corrections are new records that supersede by `supersedes_id`); mutable entities (alert status, profile) use last-writer-wins on hybrid logical clock with full history in audit log.
- **On-device store (implemented):** `app/lib/storage`, SQLite through Drift, schema in `schema.drift`. Tables `settings`, `missions` and `measurements` mirror the server columns that matter offline (UUIDv7 ids, method, provenance, quality flags, `supersedes_id`, `client_seq`, `prev_hash`, `hash`). SQLite triggers enforce immutability, the simulation firewall, subject consistency, chain continuity and simulation-only deletion. Refinement of the protocol above: each mission has its own chain on the device (unique `(mission_id, client_seq)`), so removing a simulation never breaks a real mission's chain; the server key becomes `(client_id, mission_id, client_seq)`. On native targets the file is encrypted at rest with SQLite3 Multiple Ciphers (ChaCha20-Poly1305) and a 256-bit key from the system keystore (`flutter_secure_storage`); browser storage is not encrypted. The outbox for sync is not implemented yet (see [Known limitations](../KNOWN_LIMITATIONS.md)). Schema version 2 adds `self_checkins` and `reaction_tests`: the astronaut's private wellbeing records, deliberately not linked to any mission (so they cannot mix with simulated data and are not part of what a mission shares), immutable once written and deletable only by the astronaut. Schema version 3 adds `alert_responses`: what the astronaut did about an alert on their own record (confirmatory reading and its outcome, value checked or corrected, keep watching, contacted medical support). Rows belong to the real record only (a trigger refuses simulation missions) and can be neither edited nor deleted.

- **API skeleton (implemented):** `server/`. Configuration from environment variables only, validated at start-up (TLS to the database and https origins required outside development; refuses to run as the migrator or a superuser); `GET /v1/health`, `GET /v1/ready` (database reachable and schema at the expected version via `rakia.schema_version()`), `GET /v1/metric-definitions`; security headers and `Cache-Control: no-store` on every response; exact-match CORS allow-list; per-address token-bucket rate limiting (probes exempt; `X-Forwarded-For` trusted only for a configured number of proxy hops); request ids; JSON errors that never include database messages; JSON access logs without addresses, queries, headers or bodies; 1 MiB body limit; graceful stop on SIGTERM. Database access through a lazily connected libpq pool as `rakia_api`, bound parameters only, one transaction per request with the verified caller in `request.jwt.claims` (transaction-local). Spec: `docs/api/openapi.yaml`.

## 4. Authentication & authorisation

- **Firebase Auth** on the client: Google Sign-In, email/password (+ verification, password reset), persistence, logout with token revocation. Phone OTP is not enabled: SMS needs Firebase's paid Blaze plan, and the deployment is zero-cost.
- **Backend verification without a service account:** `rakia-api` verifies Firebase ID tokens (RS256) against Google's public certificates, checking `iss`, `aud` (project id), `exp`, `iat`, `auth_time`. No Firebase admin secret is needed by the API or ever shipped to the client.
- **RBAC:** roles per mission — `astronaut`, `crew_medical_officer`, `flight_surgeon`, `researcher` (de-identified read only), `mission_admin`. Checked in the API *and* enforced again in Postgres with Row-Level Security (defence in depth). An astronaut sees only their own data; behavioural data obeys consent scopes.
- **Turnstile:** on sign-up, password reset, phone-OTP request (prevents SMS-cost abuse) and any public form. Server-side `siteverify` with secret; reject on failure/`timeout-or-duplicate`; store SHA-256 of token for 10 min to block replay; check `action`/`hostname`; fail closed on public forms, with a clear retry message. Turnstile is bot friction, not identity.

**Implemented in the API:** `server/src/firebase_auth.cpp` verifies ID tokens exactly as above (RS256 only, key id from Google's published X.509 certificates fetched over verified TLS and cached for their `max-age`, refreshed at most once a minute on an unknown key id; `aud`, `iss`, `exp`, `iat`, `auth_time` and `sub` checked with 60 s of clock leeway). `GET /v1/me` creates the caller's `app_users` row on first use and returns it with their mission roles, running as that user so row-level security applies. Refusals are logged with a reason code, never the token. The app's sign-in screens, Turnstile and RBAC-gated endpoints follow once a Firebase project exists.

## 5. Supabase integration — honest assessment

Your local PostgreSQL 18 is vanilla Postgres. Supabase's PostgREST, Realtime, Storage and Auth are **separate services** and do not exist on it. Therefore:

- **Dev:** `rakia-api` talks directly to local Postgres. Migrations are written to be Supabase-compatible (no superuser-only extensions; RLS reads the caller identity from `current_setting('request.jwt.claims')`, the same mechanism Supabase uses).
- **Prod:** Supabase-hosted Postgres; Supabase supports Firebase Auth as a *third-party auth provider*, so RLS can trust Firebase JWTs directly if we later expose PostgREST/Realtime. *(To re-verify against current Supabase docs at Phase 3 start.)*
- **Optional local Supabase stack** (`supabase start`) needs Docker Desktop running — it is installed but the daemon is currently off.

## 6. Database design (PostgreSQL, schema `rakia`)

```text
missions ─┬─< mission_phases
          ├─< mission_members >── app_users (firebase_uid, role)
          ├─< crew_members ──┬─< measurements (partitioned monthly) >── metric_definitions
          │                  ├─< baselines                              devices >── data_sources
          │                  ├─< context_events (exercise, EVA, sleep episode, workload)
          │                  ├─< self_assessments (private by default) ── consent_grants
          │                  ├─< alerts ─< alert_events ; alerts >─< alert_contributions
          │                  └─< confirmatory_checks
          ├─< habitat_modules ─< environment_readings (CO₂, ppO₂, T, RH, dose rate)
          └─< radiation_dose_records (per crew, per period, cumulative view)
evidence_references (citation, DOI, url, verified bool) >─< recommendation_templates
sync_batches · audit_log (append-only, hash-chained) · turnstile_replay (token_hash, expires_at)
```

**Implemented (migration `0001_core`, `db/migrations/`):** `app_users`, `missions`, `mission_members`, `crew_members`, `metric_definitions` (seeded with the app's five indicators), `data_sources`, `devices`, `clients`, `measurements`, `sync_batches`, `alerts`, `alert_events`, `audit_log` and `turnstile_replay`, with the rules and row-level security below. Mission phases, context events, self-assessments and consent grants, baselines, confirmatory checks, habitat and radiation records, evidence references and the `rakia_readonly` research views are added by the PRs that use them. Two deliberate refinements of the design below:

- `measurements` is not partitioned yet. PostgreSQL requires every unique key and primary key of a partitioned table to include the partition key, which would weaken the chain key `(client_id, mission_id, client_seq)` and the `supersedes_id` reference. A BRIN index on `observed_at` keeps time scans cheap at current volumes; partitioning by month is a later migration when volumes need it.
- `quality_flags` is an integer bit mask, the same as on the device (bit 0: sensor fault), and the chain key includes the mission, as on the device. Each installation of the app is a row in `clients`, owned by one user.

Row-level security, enforced for `rakia_api` (which is not the owner and cannot bypass it): an astronaut reads only their own measurements and alerts; the crew medical officer and flight surgeon read the whole crew's; the mission admin manages missions, members and crew but reads no health data; researchers read nothing directly (de-identified views come later); outsiders and requests without a verified caller see nothing. Writes go only through the caller's own client. Alert status changes only by recording an `alert_events` row (medical staff), which applies the change and refuses a stale `from_status`. `rakia_api` cannot read the audit log, the migration history or change reference data. The tests in `db/test` exercise each of these rules.

Key rules:

- `measurements`: `id uuid (v7)`, `crew_member_id`, `metric_code` → `metric_definitions`, `value double precision`, `unit` (UCUM, must equal definition's canonical unit after conversion), `observed_at timestamptz`, `received_at`, `device_id`, `source_id`, `method enum(measured, manual, estimated, derived)`, `provenance enum(real, imported, simulated)`, `quality_score real CHECK 0..1`, `quality_flags text[]`, `client_id`, `client_seq bigint`, `prev_hash bytea`, `hash bytea`, `supersedes_id`. Unique `(client_id, client_seq)`. Partitioned by month on `observed_at`; B-tree `(crew_member_id, metric_code, observed_at DESC)`, BRIN on `observed_at`.
- **Simulation firewall:** `missions.is_simulation boolean`; a trigger rejects `provenance='simulated'` rows in non-simulation missions and real rows in simulation missions.
- `alerts.explanation jsonb` stores the six-question payload (indicator, deviation vs baseline, onset time, contributing measurement ids, rationale, recommended next step + evidence ids) produced by librakia, plus `engine_version` for reproducibility.
- `audit_log`: every insert/update/delete on sensitive tables via trigger, with actor, action, before/after diff, and `hash = sha256(prev_hash || row)`.
- Roles: `rakia_migrator` (DDL), `rakia_api` (DML only, RLS enforced), `rakia_readonly` (research views of de-identified data).
- Backups: nightly `pg_dump -Fc` with retention + monthly restore test script; prod relies on Supabase backups (PITR depends on plan — documented).

## 7. Analytics engine (librakia) — documented as EXPERIMENTAL

1. **Quality gate:** plausibility range per metric, wear-time/completeness, sensor flags → `quality_score`. Below threshold: no health alert, a data-quality notice instead.
2. **Baseline:** robust centre (median) and spread (MAD×1.4826) over a configurable reference window (default: pre-flight + first 14 flight days excluded for adaptation); time-of-day stratified for circadian metrics; minimum n before any alert ("Not enough data").
3. **Point deviation:** robust z-score.
4. **Sustained change + onset:** two-sided CUSUM on standardised residuals; onset = last zero-crossing of the triggered sum.
5. **Trend:** Theil–Sen slope with Mann–Kendall test.
6. **Multivariate:** robust Mahalanobis distance across co-varying metrics (RHR, HRV, sleep, skin temp, respiration) with per-feature contribution decomposition for the explanation.
7. **Prioritisation:** severity = f(magnitude, persistence, number of concordant indicators, data quality) — rules are transparent and listed in docs; no opaque ML in v1.
Validation: synthetic scenarios with known ground truth (sensitivity, false alarms per 30 days, onset error) — reported as engineering metrics, **not** clinical validation.

## 8. Security

TLS everywhere; secrets only in env/secret manager (`.env.example` documents names only); parameterised SQL only; input validation at API boundary (schema + unit + range); rate limiting; CORS allow-list; security headers on web host; encryption at rest via Postgres host/disk (Supabase encrypts at rest) and on-device SQLite encryption (SQLite3 Multiple Ciphers, key in the system keystore) for native targets — on web, browser storage cannot be strongly encrypted at rest, which is documented as a limitation; dependency scanning (Dependabot), CodeQL (C/C++, JS), secret scanning + push protection.

## 9. Deployment

| Piece | Host | Why |
|---|---|---|
| Flutter web | **Cloudflare Pages** (alt: Vercel) | Static assets, global CDN, HTTPS, preview deploys; same vendor as Turnstile. |
| `rakia-api` (native C++) | **Container on Render, free plan** (alt: Google Cloud Run, which needs a billing account) | Vercel Functions and Cloudflare Workers cannot run arbitrary native long-running C++ servers. Render runs our Docker image with HTTPS, health checks and logs at no cost and without a payment method; the free service sleeps when idle (cold starts of about a minute). The image is unchanged on Cloud Run. |
| Database | Supabase Postgres, free plan (staging, prod), local PG 18 (dev) | Reached through Supabase's session pooler (IPv4, `verify-full`). |
| Auth | Firebase Authentication, Spark (free) plan | Email/password and Google sign-in. Phone OTP needs the paid Blaze plan and is not enabled. |
| Monitoring | Render logs and metrics + `GET /v1/health` (liveness) + `GET /v1/ready` (readiness), uptime check, structured JSON logs; client errors to a self-hosted-capable sink (decided in Phase 8) | |

Environments: **dev** (local PG, Firebase dev project, Turnstile test keys), **staging** (`staging` Pages branch + Render staging service + Supabase staging project + Firebase `rakia-staging`), **prod**. CI/CD: GitHub Actions — format/lint/test on PR; build web, Android, iOS (macOS runner, unsigned), C/C++ on Windows (MSVC) and Linux (GCC/Clang + ASan/UBSan + clang-tidy); deploy on tag.

Implemented for deployment: `server/Dockerfile` (multi-stage; tests run during the build; non-root; production mode by default; Debian base pinned by digest and tracked by Dependabot), `app/web/_headers` (CSP without inline scripts, cross-origin isolation, HSTS and the other security headers, checked in headless Chrome in CI) and a self-contained web build (`--csp --no-web-resources-cdn`). Step-by-step instructions: [DEPLOYMENT.md](../DEPLOYMENT.md).

## 10. Testing strategy

C core: unit + property tests + fuzzing (libFuzzer on Linux CI) + ASan/UBSan. API: integration tests against a disposable Postgres (CI service container). DB: migration up/down, RLS tests per role, simulation-firewall tests. Flutter: unit, widget, golden (per breakpoint), integration (offline → sync), accessibility checks (`meetsGuideline` for tap targets, contrast, labels). Cross-platform golden tests prove engine determinism.
