# Contributing to RAKIA

Thank you for helping build open astronaut-health tooling. Please read this guide and the [Code of Conduct](CODE_OF_CONDUCT.md) first.

## Ground rules

1. **No fabricated science.** Every health claim, threshold or statistic in code, UI or docs must cite a source that you have checked. Add it to the evidence references with `verified: true` only after you have read the primary source.
2. **No real personal health data** in issues, PRs, fixtures or screenshots. Use the simulator. Simulated data must stay labelled as simulated.
3. **No secrets.** Never commit credentials, service accounts, private keys or `.env` files. Push protection is enabled, but it is not a substitute for care.
4. **No diagnostic language.** RAKIA flags changes relative to a person's baseline. It never names a disease or prescribes treatment.
5. **Accessibility is part of "done".** UI changes must keep WCAG 2.2 AA: contrast, semantic labels, keyboard support and text scaling.

## Workflow

- `main` is protected. All changes go through pull requests, and CI must pass.
- Branch names: `feature/<topic>`, `fix/<topic>`, `docs/<topic>`, `chore/<topic>`.
- Keep each PR to one independently testable change. Fill in the PR template completely, including tests run and known limitations.
- Use [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `chore:`, `test:`, `refactor:`).
- PRs are squash-merged by a maintainer after review.

## Development setup

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Coding standards (summary)

| Area | Standard |
|---|---|
| C (`core/`) | C11, no global mutable state, caller-owned buffers, warnings as errors (`/W4 /WX`, `-Wall -Wextra -Werror`), clang-tidy, ASan/UBSan in CI |
| C++ (`server/`) | C++20, RAII, no raw `new`/`delete`, parameterised SQL only |
| Dart/Flutter (`app/`) | `dart format`, `flutter analyze` with zero issues, design tokens only (no hard-coded colours) |
| SQL (`db/`) | Forward-only numbered migrations, each with tests; RLS on every table holding personal data |

## Reporting issues

- Bugs and features: use the issue templates.
- Scientific corrections: use the **Evidence review** template.
- Security vulnerabilities: **do not open a public issue.** See [SECURITY.md](SECURITY.md).
