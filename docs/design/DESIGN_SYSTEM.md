# RAKIA Design System — Direction & Token Specification

> Phase 2 deliverable · Status: **DRAFT FOR APPROVAL**

## 1. Inputs studied

| Reference repo (all MIT) | What RAKIA takes from it |
|---|---|
| `VoltAgent/awesome-design-md` | The DESIGN.md format: token + rule + *rationale* in one file. RAKIA ships its own `DESIGN.md` so contributors and agents stay on-system. |
| `VoltAgent/awesome-claude-design` | Same idea applied to scaffolding a full kit from a single spec; informs our "one source of tokens → Flutter `ThemeExtension`" pipeline. |
| `Leonxlnx/taste-skill` | Anti-slop rules: one system, plain copy, show the *real* product UI, equal edges, no decorative captions, one effect at most. (Its website-specific rules — photography counts, one section per screen — don't apply to an app.) |
| `nextlevelbuilder/ui-ux-pro-max-skill` | Priority order (accessibility → touch → performance → style); chart-selection data: line for trend, **line with highlighted anomalies**, **bullet chart** for metric-vs-target grids, confidence band only with a real baseline; 44×44 touch targets; no hover-only affordances. |
| `kylezantos/design-motion-principles` | Frequency gate (frequent actions: no animation; keyboard-initiated: never animate), productivity-tool durations ≤ 180–200 ms, mandatory reduced-motion path, functional vs decorative motion. Context = *SaaS dashboard → Emil (restraint) primary*. |
| `bergside/design-md-chrome` | Quality-gate section structure (Do / Don't / Component rule expectations / testable gates) used for our component contracts. |

Nothing is copied from these repos into the product; they are design knowledge only. They live in `_reference/` (git-ignored).

## 2. Colour — extracted from the four references

All four images independently converge on the same four-colour system. Values were measured (median-cut quantisation + 7×7 averaged pixel samples), not guessed:

| Reference | Measured / labelled values |
|---|---|
| 1 · Activity Planner app | Lilac backdrop `#ADA4BF`; dark surfaces `#1F1F26`, `#252736`, `#0E0E15`; violet `#6D44C7` / screen `#6137BD`; lime card `#B2EF2A`; teal progress `#3A5C65`; violet tint `#9576D1` |
| 2 · "GridsterGP" palette card | Labelled: Black `#000000`, Violet `#7D39EB`, Lime `#C6FF33`, White `#FFFFFF` (measured matches: `#813DED`, `#C6FF34`) |
| 3 · Palette card | Labelled: Blanche White `#FEFFFC`, Banana Yellow `#D0FF00`, Plum Violet `#8116E0` on `#000000` |
| 4 · Cubix smart-home app | Violet-tinted blacks `#08060E`, `#0E0A15`, `#1C1927`, `#241E31`; nav `#383442`; muted `#554A69`; violet `#955ECC` / tile `#9C40DC`; lilac glow `#B997D8` / `#DAB0FD`; lime-cream `#E3F1BF` |

**Synthesis:** a violet-tinted near-black canvas (from ref 4, softer on the eye than pure `#000` for long sessions), electric violet as the brand colour (ref 2), acid lime as the action/"nominal" signal (refs 1–4 use lime for *done / connected / go*), and warm off-white text (ref 3).

### 2.1 Core tokens — dark theme (default: "Mission")

| Token | Value | Source | Use |
|---|---|---|---|
| `bg.canvas` | `#08060E` | ref 4 | App background |
| `bg.surface1` | `#100C18` | between ref 4 `#0E0A15`/`#1C1927` | Panels |
| `bg.surface2` | `#16121F` | ref 4 family | Cards, inputs |
| `bg.surface3` | `#1F1A2B` | ref 4 `#1C1927`/`#241E31` | Raised / hover |
| `border.subtle` | `#2A2438` | ref 4 | Dividers (decorative) |
| `border.control` | `#7A7192` | ref 4 `#554A69` lightened | Input/control outlines (WCAG 1.4.11): 3.7–4.4:1 on every dark surface. The earlier candidate `#6E6585` passed on `surface2` only (3.4:1) with no margin. |
| `text.primary` | `#F5F3FA` | ref 3 `#FEFFFC` tinted | 18.3:1 on canvas |
| `text.secondary` | `#A69FB8` | ref 1 `#ADA4BF` | 7.3:1 on surface2 |
| `brand.violet` | `#7D39EB` | ref 2 | Brand fills, selected nav, chart series 1. **Not for text on dark** (3.5:1); white on violet = 5.7:1 (passes) |
| `brand.violetSoft` | `#B79CFF` | ref 4 `#B997D8`/`#DAB0FD` | Violet *text*/icons on dark (8.1:1) |
| `accent.lime` | `#C6FF33` | ref 2 | Primary CTA fill (text on it `#08060E`, 17:1), focus ring, nominal |
| `accent.limeDeep` | `#D0FF00` | ref 3 | Pressed state |
| `accent.teal` | `#3A5C65` → `#5FB8C6` text | ref 1 | Info / secondary data series |

### 2.2 Health-status tokens (never colour alone)

Status is always **colour + glyph shape + word**, so it survives colour-blindness, greyscale and screen readers.

| Status | Colour | Glyph | Word | Contrast on surface2 |
|---|---|---|---|---|
| Within baseline | `#C6FF33` lime (ref) | ● filled circle | "Within baseline" | 15.6:1 |
| Watch | `#FFB547` amber *(functional, not in refs)* | ▲ triangle | "Watch" | 10.5:1 |
| Act | `#FF6B78` coral *(functional, not in refs)* | ◆ diamond | "Act now" | 6.7:1 |
| Insufficient data | `#A69FB8` | ◌ dashed circle | "Not enough data" | 7.3:1 |
| Data quality | `#5FB8C6` teal (ref 1) | ■ square | "Check data quality" | 8.0:1 |
| Simulated | `#B79CFF` + diagonal hatch | ⧄ | "SIMULATED DATA" | 8.1:1 |

Amber and coral are not present in the references; they are added deliberately because safety semantics require them, and tuned to sit with the violet/lime palette.

### 2.3 Light theme ("Ground")

Canvas `#F4F2F8`, surface `#FFFFFF`, lilac band `#ADA4BF` (ref 1), text `#14101C` (16.9:1), secondary `#6B6480` (5.0:1), violet text `#5B2BC4` (7.3:1), lime becomes a **fill only** with dark text; lime-as-text uses `#4E5F00` (6.4:1); amber text `#8A5A00` (5.3:1), coral text `#C2283A` (5.2:1), teal text `#1F6B78` (5.5:1), control border `#7A7290` (≥ 3.7:1 on every light surface). The light theme's primary action is violet `#5B2BC4` with white text (8.1:1), because a lime fill has no visible edge on white.

### 2.4 Gradients (used sparingly)

Only two, both from ref 4's lighting: `violet-glow` (`#7D39EB` → transparent, radial, ≤ 12 % opacity) behind the mission header, and `lime-progress` (`#B2EF2A` → `#D0FF00`) on progress fills. No gradients on cards, text, or buttons. No glassmorphism.

## 3. Typography

- **Geist** (UI/display) + **Geist Mono** (numerics, timestamps, IDs) — SIL OFL 1.1, **bundled as assets** so the app renders identically offline. The geometric grotesk in refs 2–4 is matched without licensing a commercial face.
- Tabular figures everywhere a number can update.
- Scale (rem-like, base 16, respects OS text scaling): `display 40/44 · h1 28/34 · h2 22/28 · h3 18/24 · body 16/24 · small 14/20 · micro-caps 12/16 (+0.08em)`. Metric hero numbers: Geist Mono 36–56.

## 4. Spacing, radius, elevation

- 4-pt grid: `4 8 12 16 24 32 48 64`.
- Radius: `sm 8` (inputs, chips) · `md 14` (cards) · `lg 24` (sheets) · `pill` (CTA, status chips — refs 1, 3, 4 use pills).
- Elevation by surface step, not shadows (dark UI). One shadow token for overlays only.

## 5. Responsive layout (adaptive, not stretched)

| Class | Width | Navigation | Layout |
|---|---|---|---|
| Compact | < 600 | Bottom bar (5 items) + "More" sheet | Single column; metric cards stack; charts full-width, 7-day default |
| Medium | 600–1023 | Navigation rail | 2-column grid; detail opens as page |
| Expanded | 1024–1439 | Rail + labels | 12-col grid; **list–detail** (alerts list ↔ evidence panel) |
| Large | ≥ 1440 | Persistent sidebar | Mission-control layout: status strip, 3-pane (crew · timeline · inspector), keyboard shortcuts |

## 6. Component inventory (each with Do/Don't + states: default, hover, focus, pressed, disabled, loading, error, empty)

Buttons (primary lime, secondary violet outline, ghost, destructive) · inputs/selects/date-time · status chip · **metric tile** (value, unit, Δ vs baseline, sparkline, provenance badge, quality badge) · **baseline band chart** (line + personal baseline band + onset marker + anomaly highlights) · bullet chart grid · cumulative dose chart vs limit · sleep timeline (hypnogram-style bars + circadian misalignment marker) · mission timeline · **alert card** (six-question layout) · evidence drawer · consent toggle · sync status pill ("Ground has data up to …") · modal / sheet · skeleton loaders · empty states (explain what data is missing and how to add it) · error states (what failed, what still works offline, retry).

### 6.1 Implemented components (`app/lib/components`)

| Component | Notes |
|---|---|
| `SurfaceCard` | The single content surface: `surface2`, `RakiaRadii.md`, subtle border, 24 px padding (16 px for dense tiles). Optional icon, title, subtitle and trailing content. Below 480 px card width the trailing content moves under the title. When tappable: hover border `borderControl`, 2 px focus ring, button semantics. |
| `StatusChip`, `StatusGlyph` | Colour, distinct shape and word for every status. The label wraps at very large text sizes. |
| `StatusCountTile` | Glyph and tabular count on top, status word below, so it stays readable at any column width. |
| `MetricSummaryCard` | Indicator name, status, latest value in Geist Mono with unit, change against baseline and a sparkline. Opens the owning module. |
| `BaselineChart`, `ChartLegend` | Custom painter: expected range band (baseline median ± 2.5 × spread, the WATCH threshold), dashed median, pre-flight reference shaded, mission readings, hollow teal markers for rejected or missing readings, dashed onset marker in the status colour, simulated hatch and `SIMULATED` watermark. Labels never collide: they are dropped or flipped when space is short. Screen readers get a one-sentence summary. |
| `ExplanationList` | The six-question alert layout: what changed, by how much, since when, from which readings, why it matters, what to check next. |
| `SimulationBanner` | Persistent hatched strip above every page while the simulation mission runs, with an "End simulation" action. |
| `RakiaMark` | Brand mark (bold "R" on the violet gradient with a lime point), matching the app icon generated by `app/tool/generate_icons.py` for web, Android, iOS, macOS and Windows. |

Interface rules: no emoji anywhere (enforced in CI by `.github/scripts/check-no-emoji.mjs`); icons come from Material Symbols; numbers use Geist Mono with tabular figures; section labels use the micro-caps `labelSmall` style.

## 7. Data visualisation rules

1. Every chart has a title that states the measurement and unit, an axis with units, and a text summary for screen readers ("Resting HR 7-day mean 64 bpm, 6 above your baseline since 3 Nov").
2. Baseline is drawn as a band, not a line; population ranges, if shown, are visually secondary and labelled.
3. Estimated values use dashed strokes; manual entries use hollow markers; simulated data is hatched + watermarked.
4. Max 4 series per chart; categorical order violet → lime → teal → lilac.
5. Charts are keyboard-navigable (arrow keys step points, announcing value/time).

## 8. Motion

Emil-weighted: route transitions 180 ms, state changes 120 ms, ease-out; no animation on frequent actions or keyboard actions; no looping ambient animation; live data updates without movement (value changes, no number roll). `MediaQuery.disableAnimations` → all durations 0.

## 9. Accessibility (built in)

WCAG 2.2 AA target: automated contrast test over every token pair used; 44×44 dp targets; visible lime focus ring (2 px + 2 px offset); `Semantics` labels on all controls and charts; text scaling to 200 %; focus order follows reading order; status never colour-only; no time-limited interactions; reduced motion honoured.
