# Deployment

How to run RAKIA outside a developer machine: the database, the API on Google Cloud Run, the web app on Cloudflare Pages, and the native apps. Every step needs an account you own; nothing here has been run against hosted services by the project yet, so treat the first deployment as a staging rehearsal.

Secrets never go in the repository, in container images, or in the web bundle. The API takes them from environment variables that the platform fills from its secret manager; the web app holds no secrets at all.

## 1. Database (PostgreSQL 16 or later, with TLS)

Supabase (planned for production) or any managed PostgreSQL works. The API connects only with `RAKIA_DB_SSLMODE=verify-full` outside development.

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
   RAKIA_DB_HOST=<database host>
   RAKIA_DB_PORT=5432
   RAKIA_DB_NAME=postgres
   RAKIA_DB_SSLMODE=verify-full
   RAKIA_DB_SSLROOTCERT=<path to the provider's CA certificate, or "system">
   RAKIA_DB_MIGRATOR_USER=rakia_migrator
   RAKIA_DB_MIGRATOR_PASSWORD=<migrator password>
   ```

   ```bash
   cd db
   dart pub get
   dart run bin/migrate.dart status --env-file ../.env.staging
   dart run bin/migrate.dart up --env-file ../.env.staging
   ```

   The runner applies each migration in a transaction and refuses to run if an applied migration was edited. Never run the database tests (`RAKIA_DB_ALLOW_RESET=1`) against a hosted database: they delete its data.

## 2. API on Google Cloud Run

The image is built from `server/Dockerfile`: the unit and HTTP tests run during the build, the binary runs as a non-root user, and the image defaults to production mode (no `.env` file is read; TLS to the database is required).

```bash
# Once per project (replace REGION and PROJECT)
gcloud artifacts repositories create rakia --repository-format=docker --location=REGION
gcloud auth configure-docker REGION-docker.pkg.dev

# Secrets: the API role's password and, for Supabase, its CA certificate
printf '%s' '<api password>' | gcloud secrets create rakia-db-password --data-file=-
gcloud secrets create rakia-db-ca --data-file=path/to/supabase-ca.crt

# Build, push and deploy (from the repository root)
docker build -f server/Dockerfile -t REGION-docker.pkg.dev/PROJECT/rakia/rakia-api:0.1.0 server
docker push REGION-docker.pkg.dev/PROJECT/rakia/rakia-api:0.1.0
gcloud run deploy rakia-api \
  --image REGION-docker.pkg.dev/PROJECT/rakia/rakia-api:0.1.0 \
  --region REGION --port 8080 --allow-unauthenticated \
  --min-instances 0 --max-instances 3 --concurrency 40 \
  --set-env-vars RAKIA_ENV=production,RAKIA_DB_HOST=<database host>,RAKIA_DB_PORT=5432,RAKIA_DB_NAME=postgres,RAKIA_DB_USER=rakia_api,RAKIA_DB_SSLMODE=verify-full,RAKIA_DB_SSLROOTCERT=/etc/rakia/db-ca.pem,RAKIA_CORS_ORIGINS=https://<web app host>,RAKIA_TRUSTED_PROXY_HOPS=1 \
  --set-secrets RAKIA_DB_PASSWORD=rakia-db-password:latest,/etc/rakia/db-ca.pem=rakia-db-ca:latest
```

- `--allow-unauthenticated` makes the service reachable from the web app; the API authenticates users itself (Firebase ID tokens, in the next release) and enforces row-level security in the database.
- In the service's YAML (or the console), set a **startup probe** on `GET /v1/ready` and a **liveness probe** on `GET /v1/health`. Readiness fails with 503 until the database is reachable and migrated to the version the image expects.
- For a database without a private CA (a provider with publicly trusted certificates), leave `RAKIA_DB_SSLROOTCERT` unset: `verify-full` then checks against the image's system roots.
- Logs are JSON lines on stderr, read by Cloud Logging (`severity`, `message`, `request_id`). They contain no addresses, query strings, headers, bodies or secrets.

Check the deployment:

```bash
curl -s https://<service url>/v1/health
curl -s https://<service url>/v1/ready
curl -sI https://<service url>/v1/health | grep -i -E 'strict-transport|content-security|x-request-id'
```

## 3. Web app on Cloudflare Pages

The web build is self-contained: CanvasKit, fonts, librakia and SQLite are served from the same origin, no inline script runs, and `app/web/_headers` (copied into the build) sets the Content-Security-Policy, cross-origin isolation (which lets the local database use the Origin Private File System) and the other security headers.

Build (Linux, macOS or WSL; needs Flutter, the Dart SDK and Emscripten 6.0.13 as in [DEVELOPMENT.md](DEVELOPMENT.md)):

```bash
cd core/dart && sh tool/build_wasm.sh ../../app/web/rakia/rakia.wasm && cd ../..
cd app
flutter pub get
sh tool/build_web_sqlite.sh
flutter build web --release --csp --no-web-resources-cdn
```

Check it locally under its own headers, in headless Chrome:

```bash
node tool/web/serve_with_headers.mjs build/web 5000 &
node tool/web/check_web_build.mjs http://127.0.0.1:5000/
```

Deploy (after `npx wrangler login`, or with a Cloudflare API token in `CLOUDFLARE_API_TOKEN`):

```bash
npx wrangler pages deploy build/web --project-name rakia --branch main
```

Use a separate branch (for example `--branch staging`) for preview deployments. When the app starts calling the API, add the API's origin to `connect-src` in `app/web/_headers` and the web origin to `RAKIA_CORS_ORIGINS` on the API.

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
- Require the `Database` and `API` checks in the `main` branch ruleset (owner action in the repository settings).
- Configure Firebase Authentication and Cloudflare Turnstile (production keys), which the authenticated endpoints need.
- Decide backup retention and test a restore (Supabase backups; PITR depends on the plan).
