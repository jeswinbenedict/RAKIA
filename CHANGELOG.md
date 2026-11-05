# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `librakia` 0.1.0 (`core/`): portable C11 analytics core. Includes a data-quality gate, robust personal baselines (median/MAD), two-sided CUSUM with onset estimation, Theil–Sen/Mann–Kendall trend, shrunk correlation and Mahalanobis distance with per-feature contributions, SHA-256 and a hash-chained measurement ledger, and a quality-gated assessment (`INSUFFICIENT_DATA`, `DATA_QUALITY`, `WITHIN_BASELINE`, `WATCH`, `ACT`). Experimental; not clinically validated.
- 8 test suites, including NIST SHA-256 vectors, independent golden ledger hashes, synthetic validation scenarios and a cross-platform determinism digest.
- CI: MSVC, MSVC+ASan, GCC, Clang ASan+UBSan, macOS ARM64, clang-tidy, a 60-second libFuzzer run, and CodeQL (C/C++).
- `docs/algorithms/LIBRAKIA.md`: algorithms, assumptions, validation results and limitations.
- Repository foundation: README, Apache-2.0 licence, contributing guide, Code of Conduct (Contributor Covenant 2.1), security policy, issue and PR templates, CODEOWNERS, Dependabot for GitHub Actions, and a repository-hygiene CI workflow (secret scan, Markdown lint, YAML validation).
- Phase 1–3 documents: research and innovation report, design system specification, and architecture and database design.
- Development, roadmap and known-limitations documentation; `.env.example`.
