# Deployment

How to run RAKIA outside a developer machine: the database on Supabase, the API on Render, the web app on Cloudflare Pages, sign-in with Firebase Authentication, and the native apps. Every step needs an account you own. The API has not yet been deployed to a hosted service, so treat the first deployment as a staging rehearsal.

## Zero-cost hosting

Every hosted service below has a free plan that needs no payment method:

| Part | Service and plan | Free-plan limits that matter |
|---|---|---|
| Database | Supabase Free | 500 MB database; 2 active projects per account; projects pause after 7 days without activity and are restored from the dashboard; daily backups are not included |
| API | Render Free web service (Docker) | 512 MB RAM, shared CPU; the service sleeps after 15 minutes without requests and the next request waits about a minute while it starts; 750 instance hours per workspace each month |
| Web app | Cloudflare Pages Free | 500 builds a month; unlimited static requests and bandwidth |
| Sign-in | Firebase Authentication, Spark plan | Email/password and Google sign-in; phone (SMS) sign-in needs the paid Blaze plan and is not used |
| Bot protection | Cloudflare Turnstile Free | Up to 20 widgets |
| CI and code scanning | GitHub Actions and CodeQL on a public repository | Free for public repositories |

Google Cloud Run is a drop-in alternative for the API (section 2) but needs a billing account, so it is not the default.

Secrets never go in the repository, in container images, or in the web bundle. The API takes them from environment variables that the platform fills from its secret manager; the web app holds no secrets at all.

## 1. Database (PostgreSQL 16 or later, with TLS)

Supabase or any managed PostgreSQL works. The API connects only with `RAKIA_DB_SSLMODE=verify-full` outside development.

On Supabase's free plan the direct database host is reachable over IPv6 only, and Render connects over IPv4. Use the **session pooler** instead (Supabase dashboard, **Connect**, **Session pooler**): its host looks like `aws-0-ap-south-1.pooler.supabase.com`, the port is 5432, and each role signs in as `<role>.<project ref>`, for example `rakia_api.ytadamlepphfckkbvmjq`. Session mode gives each client its own server connection, which the API needs for its per-request settings. Download the CA certificate from **Project Settings**, **Database**, **SSL Configuration**; the API and the migration runner check the server against it (`verify-full`).

1. **Create the two roles and the schema**, connected as the provider's administrative user (on Supabase: the `postgres` user, from the SQL editor or `psql`). Generate both passwords locally, for example with `openssl rand -base64 30`, and store them in your password manager and the secret manager below. Run, replacing the two placeholders:

   ```sql
   SET password_encryption = 'scram-sha-256';
   CREATE ROLE rakia_migrator LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS PASSWORD '<migrator password>';
   CREATE ROLE rakia_api LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS NOINHERIT PASSWORD '<api password>';
   GRANT CONNECT ON DATABASE postgres TO rakia_migrator, rakia_api;
   -- Needed where the administrative user is not a superuser (PostgreSQL 16+):
   GRANT rakia_migrator TO CURRENT_USER;
   CREATE SCHEMA rakia AUTHORIZATION rakia_migrator;
   REVOKE ALL ON SCHEMA rakia FROM PUBLIC;
   GRANT USAGE ON SCHEMA rakia TO rakia_api;
   ALTER ROLE rakia_migrator IN DATABASE postgres SET search_path = rakia;
   ALTER ROLE rakia_api IN DATABASE postgres SET search_path = rakia;
   ```

   This is the hosted equivalent of `db/bootstrap/bootstrap.sql`, which also creates a dedicated database; hosted providers usually give you one database (`postgres`), so the schema lives there.

2. **Apply the migrations** from a trusted machine with a file that is never committed (the `.env.*` pattern is git-ignored), for example `.env.staging`:

   ```text
   RAKIA_DB_HOST=<session pooler host>
   RAKIA_DB_PORT=5432
   RAKIA_DB_NAME=postgres
   RAKIA_DB_SSLMODE=verify-full
   RAKIA_DB_SSLROOTCERT=<path to the downloaded Supabase CA certificate>
   RAKIA_DB_MIGRATOR_USER=rakia_migrator.<project ref>
   RAKIA_DB_MIGRATOR_PASSWORD=<migrator password>
   ```

   ```bash
   cd db
   dart pub get
   dart run bin/migrate.dart status --env-file ../.env.staging
   dart run bin/migrate.dart up --env-file ../.env.staging
   ```

   The runner applies each migration in a transaction and refuses to run if an applied migration was edited. Never run the database tests (`RAKIA_DB_ALLOW_RESET=1`) against a hosted database: they delete its data.

## 2. API on Render

The image is built from `server/Dockerfile`: the unit and HTTP tests run during the build, the binary runs as a non-root user, and the image defaults to production mode (no `.env` file is read; TLS to the database is required). [`render.yaml`](../render.yaml) describes two free services, `rakia-api-staging` (deploys on every push to `main`) and `rakia-api` (production, deployed by hand).

1. In the Render dashboard, **New**, **Blueprint**, connect the GitHub repository and select `render.yaml`. Render asks for the values the file leaves out:

   | Variable | Value |
   |---|---|
   | `RAKIA_DB_HOST` | the Supabase session pooler host |
   | `RAKIA_DB_USER` | `rakia_api.<project ref>` |
   | `RAKIA_DB_PASSWORD` | the `rakia_api` password from section 1 |
   | `RAKIA_CORS_ORIGINS` | the web app's origin, for example `https://staging.rakia-app.pages.dev` |

   Render stores them encrypted; they never appear in the repository or the image.
2. In each service, **Environment**, **Secret Files**, add `supabase-ca.crt` with the certificate's contents. Render mounts it at `/etc/secrets/supabase-ca.crt`, which `RAKIA_DB_SSLROOTCERT` names.
3. Deploy. The API refuses to start with a configuration that is unsafe for the environment (for example without `verify-full`, as the database owner role, or without `RAKIA_FIREBASE_PROJECT_ID`), and the deploy log says why.

Notes:

- Render's health check calls `GET /v1/health`. `GET /v1/ready` answers 503 until the database is reachable and migrated to the schema version the image expects; check it after each deploy.
- The service is public; the API authenticates users itself by verifying Firebase ID tokens against Google's published keys (no Firebase service account or admin secret is needed, or used) and enforces row-level security in the database. It needs outbound HTTPS to `www.googleapis.com` for those keys, which Render allows.
- Render's front end adds one `X-Forwarded-For` entry, so `RAKIA_TRUSTED_PROXY_HOPS=1`. Confirm after the first deploy that the logs show distinct client addresses for distinct clients; a wrong value would let clients choose their own rate-limit key.
- A free service sleeps after 15 minutes without requests. The first request after that waits while the container starts; clients should allow about a minute and retry.
- Logs are JSON lines on stderr, shown in the Render dashboard (`severity`, `message`, `request_id`). They contain no addresses, query strings, headers, bodies or secrets.

**Alternative: Google Cloud Run** (needs a billing account). The same image runs unchanged; Cloud Run sets `PORT`, which the API reads. Build and push it to Artifact Registry, put `RAKIA_DB_PASSWORD` and the CA certificate in Secret Manager, and deploy with the variables above (`--port 8080 --allow-unauthenticated --set-secrets RAKIA_DB_PASSWORD=...,/etc/rakia/db-ca.pem=...`), with a startup probe on `/v1/ready` and a liveness probe on `/v1/health`.

Check the deployment:

```bash
curl -s https://<service>.onrender.com/v1/health
curl -s https://<service>.onrender.com/v1/ready
curl -sI https://<service>.onrender.com/v1/health | grep -i -E 'strict-transport|content-security|x-request-id'
```

## 3. Web app on Cloudflare Pages

The web build is self-contained: CanvasKit, fonts, librakia and SQLite are served from the same origin, no inline script runs, and `app/web/_headers` (copied into the build) sets the Content-Security-Policy, cross-origin isolation (which lets the local database use the Origin Private File System) and the other security headers.

Build (Linux, macOS or WSL; needs Flutter, the Dart SDK and Emscripten 6.0.13 as in [DEVELOPMENT.md](DEVELOPMENT.md)):

```bash
cd core/dart && sh tool/build_wasm.sh ../../app/web/rakia/rakia.wasm && cd ../..
cd app
flutter pub get
sh tool/build_web_sqlite.sh
flutter build web --release --csp --no-web-resources-cdn   --dart-define=RAKIA_API_URL=https://rakia-api-staging.onrender.com
```

`RAKIA_API_URL` names the API the build calls for live data (space weather today); use `https://rakia-api.onrender.com` for production. Without it the app says it is not connected and shows no live values. The API must list the site's origin in `RAKIA_CORS_ORIGINS`, and the API origins are allowed in `connect-src` in `app/web/_headers`.

Check it locally under its own headers, in headless Chrome (with the same `RAKIA_API_URL`, requests to the API are not reported as external):

```bash
node tool/web/serve_with_headers.mjs build/web 5000 &
RAKIA_API_URL=https://rakia-api-staging.onrender.com node tool/web/check_web_build.mjs http://127.0.0.1:5000/
```

The staging API only answers CORS for the staging site, so from `127.0.0.1` the app reports the server as unreachable. To see live data locally, run the API in development mode with `RAKIA_CORS_ORIGINS=http://127.0.0.1:5000`, build with `--dart-define=RAKIA_API_URL=http://127.0.0.1:8080`, and add that origin to `connect-src` in the build's copy of `_headers` (never in `app/web/_headers`).

Deploy (after `npx wrangler login`, or with a Cloudflare API token in `CLOUDFLARE_API_TOKEN`):

```bash
npx wrangler pages deploy build/web --project-name rakia-app --branch main
```

Production is served at `https://rakia-app.pages.dev`. Deploy staging with `--branch staging`, served at `https://staging.rakia-app.pages.dev`; the Turnstile widgets are registered for exactly these hostnames (staging also allows `localhost`). When the app starts calling the API, add the API's origin to `connect-src` in `app/web/_headers` and the web origin to `RAKIA_CORS_ORIGINS` on the API.

## 4. Native apps

| Target | Command (from `app/`) | Before distributing |
|---|---|---|
| Android | `flutter build appbundle --release` | Create an upload keystore and configure signing in `android/key.properties` (git-ignored); never commit the keystore. |
| iOS | `flutter build ipa --release` (macOS) | Apple Developer account, signing certificate and provisioning profile. |
| Windows | `flutter build windows --release` | Optionally sign the executable. |
| macOS | `flutter build macos --release` | Signing and notarisation for distribution outside the App Store. |
| Linux | `flutter build linux --release` | Needs `libsecret-1-dev` to build. |

Native builds encrypt the on-device database with a key from the system keystore (see [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md) for what that does and does not protect).

## 5. Before the first production release

- Run a staging deployment end to end with these steps.
- Firebase projects `rakia-staging` and `rakia-production` exist with email/password and Google sign-in; add the web app's hostnames to **Authentication**, **Settings**, **Authorized domains** in each.
- Turnstile widgets exist for staging and production; their secret keys go into the API's environment only when the API starts verifying Turnstile tokens.
- Backups: Supabase's free plan has no automatic backups. Take a logical dump before each migration (`pg_dump --schema=rakia` through the session pooler, as `rakia_migrator`) and keep it encrypted off the platform, and test restoring one.
