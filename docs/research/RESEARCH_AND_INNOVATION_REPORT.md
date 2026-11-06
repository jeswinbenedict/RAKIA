# RAKIA — Research, Originality & Innovation Report

> Phase 1 deliverable · Status: **DRAFT FOR APPROVAL** · Prepared 2026-11-06
> RAKIA is research software. It is not a medical device, does not diagnose, and is not affiliated with or endorsed by NASA.

## 0. Method and honesty notes

- **Research tooling.** The Perplexity integration attached to this environment exposes only a *dashboard-import* tool (Perplexity Computer), not a search/research API. Research was therefore done with web search against NASA NTRS, nasa.gov, PubMed Central, Nature, Frontiers and agency pages. If you want Perplexity used for research, it needs a search-capable connector.
- **Verification level.** Each finding below is tagged:
  - **[V]** stated in a primary source (NASA document / peer-reviewed abstract) seen in search results;
  - **[S]** seen only via secondary coverage or abstract snippets — must be checked against the full paper before it is quoted in the product UI.
- Nothing in RAKIA's UI will cite a statistic tagged [S] until it is upgraded to [V]. The evidence table in the database carries a `verified` flag for exactly this reason.

## 1. The problem, restated

The challenge asks for software that **gathers health indicators and lets astronauts evaluate and act on their own health status** on long missions. The operative words are *evaluate* and *act*, by the crew, with limited or delayed ground support.

NASA's own framing matches this: the **Earth-Independent Medical Operations (EIMO)** effort describes a gradual transfer of medical decision-making from ground to onboard systems, because Mars communication delays (up to ~22–24 min one way) and no evacuation option demand crew autonomy. A Feb 2024 HRP presentation lays out a preliminary EIMO ConOps; NASA is also building the Crew Health and Performance Integrated Data Architecture (CHP-IDA) and, with Google, a Crew Medical Officer Digital Assistant (early-stage). **[V]** for EIMO/ConOps existence; delay figures vary by source.

## 2. Scientific findings by domain

| Domain | What the evidence says | Tag | Implication for RAKIA |
|---|---|---|---|
| Risk framework | HRP groups risks by hazard (altered gravity, radiation, isolation/confinement, hostile closed environment, distance). JSC 2024 overview lists bone loss, muscle atrophy, sensorimotor, SANS, sleep among human risks. Human System Risk Board tracks them. | V | Organise modules by HRP hazard → indicator, not by device. |
| Bone | Gabel et al. 2022 (*Sci Rep*, 17 astronauts, HR-pQCT): tibial strength/BMD still 0.9–2.1 % below pre-flight 12 months after return; recovery worse after >6-month missions; 9/17 did not fully recover tibial BMD. Radius (non-weight-bearing) barely changed. | V (abstract) | Bone is **not** measurable by wearables in flight. RAKIA must show bone as *estimated risk context* (mission duration, exercise adherence, pre/post-flight scans if imported), clearly marked "not directly measured". |
| Cardiovascular | Fluid shift enlarges jugular/femoral veins; venous compliance changes in flight (24 cosmonauts); 2024 *Sci Rep* (7 astronauts, ~146 d) found post-flight ↑ peripheral resistance, ↓ stroke volume. | V/S | HR, resting HR, HRV, BP (where device supports) vs **personal** baseline; post-flight orthostatic context. |
| Immune | Herpes-virus shedding (EBV, VZV, HSV-1) rises in flight and does not abate on longer ISS missions (≈61 % of 23 ISS astronauts shed ≥1 virus in older studies); 2023 Antarctic analog trial of valacyclovir cut EBV shedding >24×. | S | No wearable measures immunity. RAKIA records **lab results when available** (saliva/urine assays imported) + symptom self-reports; never infers immune status from vitals. |
| Sleep / circadian | ISS actigraphy (21 astronauts, 3,248 days): circadian misalignment on 19 % of in-flight sleep episodes vs 13 % pre-flight; misaligned sleep ~5.4 h vs 6.4 h. 2023 *Sleep Med X* review: LEO missions consistently show sleep loss and circadian disruption. | S / V | Sleep duration, timing consistency, and a *misalignment* indicator are high-value, measurable signals. |
| Behavioural / cognitive | NASA's **Cognition** battery (10 brief validated tests, Basner/Dinges/Gur) is part of the ISS Behavioral Health and Performance Standard Measures. | V | Use short self-administered check-ins + reaction-time task; store privately; never "profile" the astronaut. |
| Neuro-ocular (SANS) | Incidence uncertain; pooled analysis (19 studies, 294 participants) found optic disc oedema ~75 %, choroidal folds ~71 %; longer missions → higher incidence. | S | Out of scope for measurement; included only as imported clinical exam records. |
| Radiation | NASA-STD-3001: career effective-dose limit **600 mSv** for all ages/sexes (≤3 % mean risk of cancer mortality); 250 mSv per solar particle event. Daily GCR design figures differ between NASA documents and standard revisions. | V | Cumulative dose vs career limit is a clear, honest visualisation. ISS daily dose not yet sourced — **must come from real dosimetry import or be labelled simulated**. |
| Omics / recovery | SOMA (Nature 2024) >10× increase in public human space-omics data; Inspiration4 crew returned to baseline on ~95 % of measured biological changes within months; telomere direction differed between short and 1-year missions. | V/S | Supports the core premise: **change relative to the individual's own baseline** is the right frame; group norms are weak with n ≈ 10s. |
| Wearables in flight | CSA **Bio-Monitor / Astroskin** (ISS, Expedition 58+): HR, ECG, breathing rate, SpO₂, activity, skin temperature, continuous systolic-BP estimate; sensors described as consistent; NASA analog (HERA) testing found good 24-h data. Peer-reviewed accuracy figures not found. | S | RAKIA's ingest model should match this signal set and record *estimated* vs *measured* (e.g., BP from Astroskin is an estimate). |
| Personal baselines (terrestrial) | Stanford (Snyder lab, 2017 *PLOS Biol*): deviations from each person's baseline linked to illness; later work flagged elevated resting HR relative to baseline at or before symptom onset. Dunn et al. 2021 *Nat Med*: wearable resting HR more consistent than clinic values. | V/S | Validates baseline-relative anomaly detection as a design principle — **not** as a validated diagnostic. |

### Key sources

- NASA HRP risks — <https://www.nasa.gov/hrp/risks>
- JSC SK3 overview (Feb 2024) — <https://ntrs.nasa.gov/api/citations/20240001874/downloads/NASA_JSC_SK3_Ovrvw_Slides_02082024.pdf>
- EIMO ConOps (2024) — <https://ntrs.nasa.gov/api/citations/20240001402/downloads/2024_IWS_EIMO_ConOps_FINAL.pdf>
- NASA radiation protection technical brief — <https://www.nasa.gov/wp-content/uploads/2023/03/radiation-protection-technical-brief-ochmo.pdf>
- Gabel et al. 2022, *Sci Rep*, doi:10.1038/s41598-022-13461-1 — <https://doaj.org/article/66f343f830484db896f2ef767ece0c1a>
- Overbey et al. 2024 (SOMA), *Nature*, doi:10.1038/s41586-024-07639-y — <https://soma.weill.cornell.edu>
- Venous function in 24 cosmonauts (2017) — <https://www.frontiersin.org/articles/10.3389/fphys.2017.00694/full>
- Post-flight haemodynamics (2024) — <https://www.nature.com/articles/s41598-024-51643-1.pdf>
- Valacyclovir in Antarctic expeditioners (2023) — <https://doaj.org/article/45d160da91e14ec3ba429264225547e4>
- Sleep loss/circadian review (2023) — PMC10391686
- SANS review (2024) — <https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10907968/>
- Cognition battery validation (2015) — <https://pmc.ncbi.nlm.nih.gov/articles/PMC4691281>
- CSA Bio-Monitor — <https://www.asc-csa.gc.ca/eng/sciences/astroskin.asp>
- Dunn et al. 2021, *Nat Med* — <https://www.nature.com/articles/s41591-021-01339-0.pdf>

Research gaps still open (to close in Phase 6 before any number reaches the UI): per-month bone-loss rate (Gabel *BJSM* 2021), ISS daily dose from dosimetry reports, 2022–24 in-flight HRV studies, ISS actigraphy paper citation.

## 3. Originality assessment — existing work

### 3.1 GitHub (searched 2026-11-06, `gh search repos`, 11 queries)

The landscape is **crowded with 2026 Space Apps entries for this exact challenge**, almost all 0–4 stars and weeks old:

| Project | What it does | Gap |
|---|---|---|
| VITA (`Nav33dCodes/vita-astronaut-health-monitor`, C#) | Most complete: SignalR live vitals, NEWS2-adapted early-warning score, 60-min linear trend, escalation, PDF/Excel reports, offline-tolerant client cache | Population/clinical ranges (NEWS2), ground-ops "bedside monitor" framing — not crew self-evaluation; no provenance integrity |
| AstroMind (`Mahdi-hasan-shuvo/...`) | Docs-only: personal baselines, 4-layer hybrid anomaly detection, 72-h prediction, XAI | **No code**; prediction claims without data |
| Astronaut Health Monitor (`ZainulAbideen647425/...`, Python) | Rules, personal baselines, offline queue, body map, plain-language status with symbol+word | Single-page, local only; no multi-device sync, no auth/RBAC yet |
| ASTRA Sandbox | Docs-only baseline/explanation concept | No implementation |
| ORBITCARE / ORBIT / astronaut_space_health | Front-end mock dashboards; one uses InfluxDB + TimeGAN synthetic data + ML risk | Mock values; ML trained on synthetic data presented as risk prediction |
| Others (chatbots, wellbeing assistants, spacecraft-telemetry FDIR) | LLM Q&A or spacecraft (not crew) health | Different problem |

No established, maintained open-source astronaut-health platform was found. Mature adjacent ecosystems exist (Open mHealth schemas, HL7 FHIR, NASA OSDR/GeneLab data) and should be **reused for interoperability**, not reinvented.

### 3.2 Conclusion

"Personal baselines", "explainable alerts", "offline mode" and "AI assistant" are **already table stakes** among competitors. RAKIA cannot claim them as its differentiation. We do **not** claim RAKIA is the first of anything.

## 4. RAKIA's differentiated contribution — the *Self-Referenced, Light-Time-Resilient* framework

Six pillars. Each is individually built from known techniques; the contribution is their combination, engineering rigour, and honesty for crew-side self-assessment.

1. **Dual-reference interpretation — "Am I changing more than spaceflight explains?"**
   Every indicator is read against (a) the astronaut's own pre-flight/early-flight baseline **and** (b) the mission context (phase, day-of-mission, exercise, workload, EVA, sleep shift). Where — and only where — a verified literature source exists, an *expected-adaptation envelope* is overlaid and labelled as population-derived and approximate. Competitors compare to either clinical ranges or personal baseline, not both with context.

2. **One deterministic analytics core, everywhere.**
   `librakia` (portable C11) computes baselines, anomalies, trends and explanations. The same code runs **onboard** (Flutter via `dart:ffi` on Android/iOS/desktop, WebAssembly on web) and **on the ground** (C++ service). Given the same ledger, ground and crew get bit-identical results (trend p-values excepted; see [LIBRAKIA.md](../algorithms/LIBRAKIA.md)) — critical when they are 20 minutes apart and must reason about the same alert. This is also the principled reason for C/C++ in the stack.

3. **Light-time-aware, tamper-evident data ledger.**
   Measurements are append-only and hash-chained per device; sync is delay-tolerant (store-and-forward, idempotent batches, deterministic conflict rules). The UI shows *data age* and "ground has received up to T" so the crew knows what the ground can and cannot see. Provenance (source, device, unit, method, real/imported/simulated) is mandatory on every record.

4. **Quality-gated, onset-dated, evidence-linked alerts.**
   No alert fires from data that fails quality gates (wear-time, plausibility, sensor flags, completeness); low-quality data is surfaced as a *data* problem, not a *health* problem. Change-point detection (CUSUM) estimates **when** a change began. Every alert answers the six required questions (what changed, by how much vs baseline, since when, which measurements, why it matters, what to do next) with linked, verified evidence.

5. **Closed-loop self-assessment (astronaut as operator).**
   An alert proposes a *confirmatory check* (e.g., repeat resting HR under standard conditions, orthostatic self-test protocol, short reaction-time task). The result re-enters the engine; the alert resolves, persists or escalates; the outcome is logged. This operationalises the "evaluate and act" wording of the challenge and the EIMO direction.

6. **Crew-controlled privacy for behavioural data.**
   Mood, isolation and cognitive self-reports are **local-only by default**; the astronaut chooses consent scopes (share trend only / share values / share with flight surgeon). Consent changes are audited. This avoids the psychological-profiling failure mode.

Plus a hard **simulation firewall**: simulated data may exist only inside missions flagged as simulations (enforced by database constraints) and is watermarked "SIMULATED DATA" in every view, export and chart.

## 5. Feasibility triage (for the hackathon + open-source foundation)

| Capability | Feasible now | Notes |
|---|---|---|
| Cardio (HR, RHR, HRV, SpO₂, BP when supplied), sleep, activity, environment, radiation dose ingest | Yes | Via simulator, CSV/JSON import, Open mHealth/FHIR mapping. Real astronaut data is not publicly available at this granularity; public datasets (NASA OSDR, analog studies) will be evaluated per licence. |
| Personal baselines, robust z, EWMA/CUSUM onset, Theil–Sen trend, multivariate robust distance with per-feature contribution | Yes | Implemented in C, unit-tested with synthetic ground truth. **Experimental, not clinically validated.** |
| Offline-first app + delay-tolerant sync | Yes | Local SQLite (Drift) + ledger sync protocol. |
| Bone / immune / SANS | Context only | Imported clinical/lab records + mission-duration context; never inferred from wearables. |
| 72-h health "prediction" | Not proposed | No validated data to support it; would be misleading. |
| LLM medical assistant | Not proposed for v1 | Hallucination risk in a health context; may be revisited as a retrieval-only explainer over verified evidence. |
| iOS build | Partly | No macOS here; build verified in GitHub Actions macOS runner (unsigned). |

## 6. Measurable project objectives

1. Every measurement record carries source, timestamp (UTC), UCUM unit, method and provenance — 100 % enforced by DB constraints and tests.
2. Analytics core: ≥ 90 % line coverage; detection accuracy reported on published synthetic scenarios (injected step, drift, artefact) with documented false-alarm rate.
3. Identical engine output on Windows, Linux, Android and Web (golden-file tests in CI).
4. App fully usable offline for ≥ 7 simulated days, then syncs with zero data loss and deterministic conflict resolution (integration test).
5. WCAG 2.2 AA: automated contrast tests on all tokens; semantic labels on every interactive widget; text scaling to 200 % without loss.
6. Zero secrets in repository (secret scanning + push protection on).
