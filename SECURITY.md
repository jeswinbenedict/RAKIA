# Security Policy

RAKIA handles data that, in real use, would be highly sensitive health information. We take security reports seriously.

## Supported versions

RAKIA is pre-release. Only the latest commit on `main` receives security fixes.

## Reporting a vulnerability

**Please do not report security vulnerabilities in public issues, discussions or pull requests.**

Report privately through GitHub: go to the repository's **Security** tab and choose **Report a vulnerability** (private vulnerability reporting).

Please include:

- the affected component (app, API, analytics core, database migrations, CI) and version or commit;
- steps to reproduce, or a proof of concept;
- the impact you expect (for example: data exposure, authentication bypass, integrity of health records).

We aim to acknowledge reports within 72 hours and to agree a disclosure timeline with you. We will credit reporters who wish to be credited.

## Scope highlights

In scope: authentication and authorisation bypass, Row-Level Security gaps, ledger or hash-chain integrity bypass, Turnstile verification bypass, secret exposure, injection, memory-safety bugs in `librakia` or the C++ API, and any way to mix simulated data with real data.

Out of scope: findings that require a compromised device or OS, and denial-of-service through volumetric traffic.

## Handling secrets

- Secrets live only in environment variables or a secret manager. [`.env.example`](.env.example) lists variable names, never values.
- The backend verifies Firebase ID tokens using Google's public keys. No Firebase Admin service account is required, and none may ever be shipped to clients.
- Secret scanning and push protection are enabled on this repository.
