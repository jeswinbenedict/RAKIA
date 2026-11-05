# RAKIA app

Flutter client for RAKIA (Web, Android, iOS, Windows, macOS, Linux).

> Research software. Not a medical device.

This is the **app shell**. It contains the design system, adaptive navigation and every module's route. Modules show honest empty states until data ingestion, authentication and the analytics bindings land; see [PROJECT_STATUS.md](../PROJECT_STATUS.md).

## Run and test

```bash
flutter pub get
flutter run -d chrome
flutter test
```

## Structure

| Path | Contents |
|---|---|
| `lib/design/` | Tokens, semantic colours, typography, theme, WCAG contrast utility |
| `lib/components/` | Status chip and glyphs, simulated-data badge, empty state |
| `lib/navigation/` | Module registry, adaptive shell, router |
| `lib/features/` | Page frame, module page, About page |
| `test/` | Token contrast, navigation per breakpoint, accessibility guidelines, components |

Design rules live in [docs/design/DESIGN_SYSTEM.md](../docs/design/DESIGN_SYSTEM.md). Never hard-code colours, sizes or durations in widgets; use the tokens.

Fonts: Geist and Geist Mono v1.9.1 by Vercel, SIL Open Font License 1.1 (`assets/fonts/OFL.txt`).
