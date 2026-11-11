# RAKIA Design System — Direction & Token Specification

> Status: **in use**. Neumorphic ("soft UI") system, implemented in `app/lib/design/`.

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

## 2. Neumorphism: references and principles

The visual direction follows four Figma Community kits chosen by the owner, studied for their principles rather than copied:

1. Neomorphic UI Kit (Zvonimir Juranko): light cool-grey kit, basic raised and pressed states, buttons, toggles, inputs.
2. Neumorphism UI Kit (Lichin): pill controls, pagination, switches and progress on one soft surface.
3. Neomorphism UI Kit for Figma, free soft UI elements: normal and pressed buttons, search fields, sliders and toggles.
4. Neomorphism style, visual: tinted soft cards with icon wells.

What they share, and what RAKIA takes:

| Principle | In RAKIA |
|---|---|
| One soft surface per theme; elements are made of the background, separated by light and shadow, not by fills or borders | `canvas`, `surface1` and `surface2` are one colour; cards and controls have no border |
| Paired shadows: a dark one down-right, a light one up-left | `raisedShadows()` in `app/lib/design/neumorphism.dart`, depth `RakiaDepth.panel` (8) for cards and `RakiaDepth.control` (4) for controls; blur is twice the offset |
| Pressed and recessed elements carry the same pair inside | `NeuStyle.inset`: inputs, progress tracks, icon wells, note callouts, the selected navigation item, the alert response area |
| Generous, consistent rounding | `RakiaRadii`: 12 small (wells, nav items), 20 panels, 28 dialogs, pills for buttons, inputs and chips |
| Restrained colour: muted slate text and one accent | One indigo-violet accent per theme for actions, focus and selection; status colours only where status is shown |
| Press feedback | Interactive cards sink in (`AnimatedNeuSurface`, 120 ms, none under reduced motion); buttons rest raised and lie flat while pressed |

Deliberately not taken: reference 3's magenta-to-violet gradient on active controls (the brief asks for no excessive gradients), and tinted card backgrounds (colour is reserved for meaning).

**Accessibility comes first.** Neumorphism's known weakness is low contrast, because elements barely differ from the background. RAKIA keeps every text colour at WCAG AA (4.5:1) on both the surface and the inset well. Controls keep a visible edge where shadow alone would be too faint: a faint outline on secondary buttons, a 3:1 border on inputs, and a 2 px accent focus ring everywhere. Status is never shown by colour alone. `test/design_tokens_test.dart` checks all of this in both themes, and the accessibility tests check tap targets and text contrast on every page.

### 2.0 The RAKIA crew

The sign-in page and the Mission overview show a 3D group of cartoon astronauts (`app/web/crew/crew.js`, mounted by `app/lib/components/crew/`). They are original characters built from three.js primitives, in the clay style of the Spline Community scene "100 followers" by heyvlad (CC BY 4.0). That scene is not embedded. Each character has its own skin tone and expression and wears a NASA-inspired spacesuit with RAKIA's own mission patches, not NASA insignia, whose use is restricted.

- **Interaction:** heads turn part of the way toward the pointer (mouse, pen or the last touch, anywhere on the page) and the eyes do the rest, within natural limits: head yaw up to 0.3 rad and pitch up to 0.18 rad; eyes up to 0.5 and 0.35 more. Motion is exponentially smoothed.
- **Life:** breathing and blinking on separate clocks. Under reduced motion the eyes follow without easing, and there is no breathing or blinking.
- **Performance:** device-pixel ratio capped at 2; one 1024 px soft shadow map; rendering pauses off screen and in hidden tabs; everything is disposed on unmount.
- **Hosting and fallback:** three.js is served from the app's own origin. A still deep-space panel appears while loading, without WebGL, and on native builds.

### 2.1 Tokens

| Role | Light ("Ground") | Dark ("Mission") |
|---|---|---|
| Surface (`canvas`, `surface1`, `surface2`) | `#E6EAF0` | `#1F232B` |
| Inset well (`surface3`) | `#DAE0E8` | `#171A20` |
| Highlight (light side) | `#FFFFFF` | `#2B303A` |
| Shadow (dark side) | `#A9B6C8` | `#0F1115` |
| Divider (decorative) | `#CFD6E0` | `#2E333D` |
| Control edge (3:1) | `#687284` | `#7D8697` |
| Text primary | `#1C2430` (12.9:1) | `#E8EBF1` (13.2:1) |
| Text secondary | `#4A5465` (6.3:1) | `#A9B2C1` (7.4:1) |
| Accent: actions, focus, selection | `#4334B0`, white text 8.9:1 | `#A594FF` fill with `#14121C` text 7.3:1; `#B5A8FF` as text |

Contrast figures are against the surface; all also pass on the inset well. The RAKIA logo keeps its violet and lime.

### 2.2 Health-status tokens (never colour alone)

Status is always **colour + glyph shape + word**, so it survives colour-blindness, greyscale and screen readers.

| Status | Light | Dark | Glyph | Word |
|---|---|---|---|---|
| Within baseline | `#2A6439` | `#B9EC6B` | filled circle | "Within baseline" |
| Watch | `#7E4F00` | `#FFB547` | triangle | "Watch" |
| Act | `#A8231C` | `#FF7A84` | diamond | "Act now" |
| Insufficient data | text secondary | text secondary | dashed circle | "Not enough data" |
| Data quality | `#1C6370` | `#6FC4D1` | square | "Check data quality" |
| Simulated | accent + diagonal hatch | accent + diagonal hatch | hatch | "SIMULATED DATA" |

Every status colour is at least 5.1:1 on both the surface and the well.

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

Buttons (primary: raised accent pill; secondary: raised surface pill; text; destructive) · inputs/selects/date-time · status chip · **metric tile** (value, unit, Δ vs baseline, sparkline, provenance badge, quality badge) · **baseline band chart** (line + personal baseline band + onset marker + anomaly highlights) · bullet chart grid · cumulative dose chart vs limit · sleep timeline (hypnogram-style bars + circadian misalignment marker) · mission timeline · **alert card** (six-question layout) · evidence drawer · consent toggle · sync status pill ("Ground has data up to …") · modal / sheet · skeleton loaders · empty states (explain what data is missing and how to add it) · error states (what failed, what still works offline, retry).

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
4. Max 4 series per chart; categorical order accent → within-baseline → data-quality → secondary text.
5. Charts are keyboard-navigable (arrow keys step points, announcing value/time).

## 8. Motion

Emil-weighted: route transitions 180 ms, state changes 120 ms, ease-out; no animation on frequent actions or keyboard actions; no looping ambient animation; live data updates without movement (value changes, no number roll). `MediaQuery.disableAnimations` → all durations 0.

## 9. Accessibility (built in)

WCAG 2.2 AA target: automated contrast test over every token pair used; 44×44 dp targets; visible accent focus ring (2 px); `Semantics` labels on all controls and charts; text scaling to 200 %; focus order follows reading order; status never colour-only; no time-limited interactions; reduced motion honoured.
