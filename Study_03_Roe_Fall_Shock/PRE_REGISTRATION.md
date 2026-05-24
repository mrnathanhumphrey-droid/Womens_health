# Pre-Registration — Dobbs/Roe-fall Shock-Amplification Test in US Maternal Mortality

**Locked: 2026-05-24**

## §1 Motivation and goal

The Dobbs v. Jackson Women's Health Organization decision (June 24,
2022) overturned Roe v. Wade. Multiple states implemented immediate
abortion bans via trigger laws; many had pre-existing restriction
infrastructure (TRAP laws, clinic distance, Medicaid funding
restrictions, gestational limits).

This study applies the **shock-amplification methodology shape**
(see [[reference-idp-shock-amplification-shape]]): **do populations
with pre-existing exposure to abortion-restriction infrastructure
show differential maternal mortality response to the Dobbs shock?**

**Headline coefficient:** `post-Dobbs indicator × pre-existing
restriction intensity` interaction. If positive with credible interval
excluding null and direction-coherent: "the Dobbs shock amplified
maternal mortality more in places that had built the infrastructure
to amplify it."

**Deliverable:** quantified, hierarchically-modeled differential
response with proper posterior uncertainty, reported across the
full grid of reasonable specifications.

## §2 Substrate (all public, no DUA wait)

| Source | Role | Granularity |
|---|---|---|
| **CDC WONDER Multiple-Cause-of-Death** | Maternal mortality numerator (ICD-10 O00–O99 + A34) | County-year (suppressed at <10) |
| **CDC WONDER Natality** | Live-birth denominator | County-year |
| **CDC WONDER Linked Birth–Death** | Pregnancy-associated death (broader, includes overdose/suicide/accident during pregnancy + 1yr postpartum) | State-year primarily; partial county coverage |
| **CDC PMSS aggregate reports** | National SMM rate sanity overlay | National-year |
| **Guttmacher Institute Policy Database** | Pre-existing restriction composite (state × month) | State-month |
| **KFF Abortion Policy Tracker** | Post-Dobbs ban/restriction effective dates per state | State |
| **Caitlin Myers Abortion Access Distance Dataset** | County-level distance to nearest open clinic (2009–present, peer-reviewed publication-supplementary) | County-year |
| **USDA Economic Research Service Commuting Zones (2010)** | County → CZ partition | 709 zones |

All accessible immediately. **Study can fire on data acquisition this
session.**

## §3 Outcomes (multiple — "get what you can")

Per Nate 2026-05-24 decision: pull every outcome available at each
geographic granularity; report all.

| Outcome | Definition | Geographic resolution |
|---|---|---|
| **Maternal mortality (primary)** | ICD-10 O00–O99 + A34, female age 10–55, during pregnancy or within 42 days postpartum | County-year (CZ + state aggregation) |
| **Pregnancy-associated death** | All-cause death during pregnancy or within 365 days postpartum, derived from CDC linked birth–death files | State-year (county not reliably available) |
| **SMM national overlay** | CDC PMSS published national SMM rates | National-year only (sanity overlay) |

Maternal mortality is the primary outcome carrying the headline.
Pregnancy-associated death and SMM-national are reported alongside
without being elevated to headline status, because their
identification is weaker (PAD has data-coverage gaps; SMM-national
can't be decomposed by restriction intensity).

## §4 Treatment intensity measures (TWO, plus correlation analysis)

Per Nate 2026-05-24 decision: BOTH Guttmacher composite AND Caitlin
Myers distance, AND model their relationship.

| Measure | Construction | Variation |
|---|---|---|
| **Guttmacher restriction composite** | Sum of binary policy indicators (gestational limit, Medicaid funding restriction, TRAP-law presence, mandatory counseling, waiting period, parental notification) measured pre-Dobbs (2017 baseline) | State-level; ranges roughly 0–8 |
| **Myers clinic-distance** | County-level mean distance (km) to nearest open abortion-providing clinic, pre-Dobbs (2021 vintage as the freshest pre-Dobbs measure) | County-level continuous |

**Correlation pre-analysis (§11 step 3):** report Pearson and
Spearman correlation between Guttmacher state-composite and county-mean
Myers-distance (within state, between states). If correlation > 0.85,
treat as substantively redundant and pre-register a sensitivity-only
flag. If correlation < 0.85, treat as genuinely complementary —
Guttmacher captures policy regime, Myers captures access-on-the-ground.

**Primary spec uses BOTH simultaneously** in separate models; results
reported side-by-side; differences interpreted per the correlation
finding.

## §5 Geographic units (TWO, parallel)

Per Nate 2026-05-24 decision: BOTH commuting zone AND state, parallel
analyses to see power-vs-coarseness tradeoff directly.

| Unit | Source | n units | Tradeoffs |
|---|---|---|---|
| **Commuting zone (CZ)** | USDA ERS 2010 partition | 709 | Finer resolution; captures within-state policy/access variation; some CZ-year cells suppressed |
| **State** | 50 states + DC | 51 | Coarser; preserves all events (no small-cell suppression); loses within-state Myers-distance variation |

Both reported. The CZ analysis is the primary because it preserves
the Myers-distance variation that state-level loses.

## §6 Temporal cuts (TWO, primary + sensitivity)

Per Nate 2026-05-24 decision: BOTH sharp Dobbs and state-specific
trigger dates.

| Cut | Definition |
|---|---|
| **Sharp Dobbs (primary)** | Pre = ≤ June 23, 2022; Post = ≥ June 24, 2022 |
| **State-specific trigger dates (sensitivity)** | Pre/post boundary varies by state per the actual effective date of the state's first post-Dobbs ban or restriction (KFF tracker), allowing trigger states to differ from non-trigger states |

The sharp-Dobbs cut is the headline (universally interpretable);
state-trigger cut captures the actual policy timing and may be more
identifying for state-by-state heterogeneity.

## §7 Time window

- **Pre-Dobbs baseline:** January 2017 through June 2022 (5.5 years)
- **Post-Dobbs response:** July 2022 through latest available CDC
  WONDER data (typically through end of year 2023 as of mid-2026;
  partial 2024 if released)

Choice rationale: 5.5 years of pre-Dobbs trajectory is sufficient for
unit fixed effects to absorb time-invariant heterogeneity while still
capturing recent policy variation. ICD-10 coding harmonized from 2015
forward; we start in 2017 to avoid early-ICD-10 transition noise.

## §8 Stratifiers and race-interaction structure

Per Nate 2026-05-24 decision: race-as-stratifier AND three-way
interaction.

**Main-effect stratifiers (always included):**
- Race / ethnicity (NH White / NH Black / Hispanic / NH AAPI / NH AIAN
  / Other-Multiracial) — main effect
- Age group (15–24 / 25–34 / 35–44 / 45+) — main effect
- Year — fixed effect for DiD, random or AR(1) for ITS

**Headline interactions:**
- `post-Dobbs × restriction intensity` — main shock-amplification
  coefficient (the headline)
- `post-Dobbs × restriction intensity × race` — three-way: tests
  whether amplification falls differentially on racial groups
- Reported regardless of significance per pre-reg constraint §13

**Excluded (per [[feedback-bmi-is-false-measure]]):** BMI in any form.

**Not included v1 (deferred to v2):**
- Insurance / Medicaid expansion as separate stratifier (covered
  partially by Guttmacher Medicaid-funding component); could add as v2
  to disentangle
- Comorbidities (chronic HTN, pre-existing diabetes) — county-aggregate
  data don't carry these reliably

## §9 Methodology framework (TWO, primary + sensitivity)

Per Nate 2026-05-24 decision: Bayesian DiD primary, hierarchical ITS
sensitivity, synthetic control deferred.

### Family A — Bayesian Difference-in-Differences (primary)

For unit (CZ or state) `c`, year `t`, race `r`:

```
deaths_{c,r,t} ~ NegBin(λ_{c,r,t} × births_{c,r,t}, φ)
log(λ_{c,r,t}) = α_c + γ_t + η_r + θ_age +
                 β_post × Post_{c,t} +
                 δ × Post_{c,t} × Restriction_c +
                 ψ_r × Post_{c,t} × Restriction_c
```

Where:
- `α_c` = unit random intercept (CZ or state); absorbs time-invariant unit heterogeneity
- `γ_t` = year fixed effect (calendar-year shocks)
- `η_r` = race main effect
- `θ_age` = age-group fixed effects
- `Post_{c,t}` = indicator for post-cut period (sharp Dobbs or state-trigger)
- `Restriction_c` = pre-Dobbs restriction intensity (Guttmacher composite OR Myers distance, fit separately)
- `β_post` = average post-Dobbs level shift
- `δ` = **HEADLINE COEFFICIENT** — shock-amplification interaction
- `ψ_r` = race-specific deviation in shock-amplification

NegBin handles the overdispersion in low-count county-year mortality.
Births enters as exposure (offset). Weakly-informative priors per §10.

### Family B — Bayesian Hierarchical Interrupted Time Series (sensitivity)

```
deaths_{c,r,t} ~ NegBin(λ_{c,r,t} × births_{c,r,t}, φ)
log(λ_{c,r,t}) = α_c + η_r + θ_age +
                 f(t) +
                 β_post × Post_{c,t} +
                 δ × Post_{c,t} × Restriction_c +
                 ψ_r × Post_{c,t} × Restriction_c
```

Where `f(t)` is a flexible time function (B-spline with knots at year
boundaries OR Gaussian-process trend) replacing the year FE. Otherwise
identical. Tests whether the headline δ is sensitive to time-trend
specification.

### Priors (both families)

- Coefficients: Normal(0, 2.5) on log-rate-ratio scale
- Random-effect SD: half-Cauchy(0, 1)
- NegBin dispersion `φ`: Gamma(0.01, 0.01)

### Estimation

- brms / Stan, 4 chains × 4000 iterations (2000 warmup)
- `adapt_delta = 0.95`, `max_treedepth = 12`
- Convergence: R-hat < 1.01, bulk-ESS > 1000 per reported parameter

### Specification grid (counted)

Primary specifications: 2 outcomes (mortality + PAD) × 2 restriction
measures (Guttmacher + Myers) × 2 geographic units (CZ + state — but PAD
only state) × 2 temporal cuts (sharp Dobbs + state-trigger) × 2 method
families (DiD + ITS).

Maternal mortality: 2 × 2 × 2 × 2 = 16 fits
Pregnancy-associated death: 2 × 1 × 2 × 2 = 8 fits
SMM-national overlay: 2 × 1 × 1 × 1 × 1 = 2 fits

**Total: ~26 model fits.** All reported regardless of direction (§13).

## §10 Decision rule

**Headline interaction δ is identified as a "Shock-Amplification Flag" if BOTH:**

1. Posterior 95% credible interval on δ excludes zero AND
2. Practical-significance: implied rate-ratio effect at the 75th
   percentile of restriction intensity vs the 25th percentile is
   ≥ 1.10 (10% higher mortality rate) or ≤ 0.91

**Race-interaction ψ_r flagged separately per race group**, same rule.

**Flag tiers:**
- **Strong amplification:** δ passes both rules in DiD AND ITS,
  with BOTH restriction measures, in BOTH geographic units (where
  applicable)
- **Conditional amplification:** δ passes in some subset
- **Null:** δ fails one or both rules in primary spec

## §11 Pro-women framing (editorial, locked)

Same rules as Study 01 [[Study_01_Maternal_Mortality]]:

1. **Direct disparity language.** "Maternal mortality rose X% more in
   counties with pre-Dobbs restriction intensity at the 75th percentile
   compared to the 25th percentile, 95% CI [A.A, B.B]" — not "may have
   risen more."
2. **System-level framing for structural disparities.** When findings
   identify elevated mortality in high-restriction states, framing
   acknowledges the policy environment as the structural driver.
3. **No "complex factors" hedging.** Findings stated with their
   credible intervals.
4. **Methodology is neutral; framing operates on TRUE findings.** No
   prior tuning to produce favored direction.
5. **BMI excluded.** Per [[feedback-bmi-is-false-measure]].

## §12 Execution sequence

1. **Pull CDC WONDER mortality + natality** (`scripts/01_pull_wonder.R`):
   API + scrape, county-year aggregates
2. **Pull pregnancy-associated death from linked birth-death**
   (`scripts/02_pull_linked_pad.R`): state-year aggregates
3. **Build restriction-intensity panel** (`scripts/03_build_restriction_panel.R`):
   Guttmacher state-month → state-year aggregate, Myers county-year
   distance, KFF state trigger dates
4. **Geographic aggregation** (`scripts/04_aggregate_to_cz_state.R`):
   county → CZ partition (USDA ERS 2010)
5. **Restriction correlation pre-analysis**
   (`scripts/05_restriction_correlation.R`): Pearson + Spearman between
   Guttmacher and Myers; report before model fits
6. **Build analysis panel** (`scripts/06_build_analysis_panel.R`):
   unit-year-race outcome counts + denominators + covariates
7. **Family A DiD fits** (`scripts/07a_fit_family_did.R`): per spec
   in §9 grid, brms NegBin hierarchical
8. **Family B ITS fits** (`scripts/07b_fit_family_its.R`)
9. **Convergence diagnostics** (`scripts/08_convergence.R`)
10. **Headline + race-interaction extraction**
    (`scripts/09_extract_flags.R`): per-spec δ + ψ_r with CIs,
    flag-tier assignment per §10
11. **Disposition writeup** (`DISPOSITION.md`)

## §13 Constraints (load-bearing)

1. **No covariate substitution after lock.** Once
   `reference/analysis_panel.rds` is built (Step 6), no unit added or
   removed.
2. **No selective reporting.** All ~26 model fits + per-spec δ + per-race
   ψ_r reported regardless of direction.
3. **No methodology pivot post-lock.** Families A and B are locked.
   Additional families require a pre-reg amendment in DEVIATIONS.md.
4. **No BMI re-introduction.** Per editorial policy.
5. **No prior-tuning mid-analysis.** Priors per §9 are weakly-informative
   and fixed. Adjusting them mid-analysis is a deviation.
6. **Deviations** logged in `DEVIATIONS.md`.

## §14 Power-aware framing

- US maternal mortality: ~700–1300 deaths/year nationally.
- CZ-year cells with race stratification will often be sparse;
  NegBin handles low counts but credibility intervals will widen.
- Power for the headline δ at the national level is adequate. Power
  for race-interaction ψ_r in smaller racial groups (NH AAPI, NH
  AIAN) may be limited; pre-reg pre-commits to reporting wide CIs
  with "underpowered" framing rather than dropping the strata.

## §15 Position relative to corpus

This is the first port outside IDP of the
[[reference-idp-shock-amplification-shape]] methodology. The shape
ports cleanly: continuous pre-existing exposure × sharp temporal cut
× within-unit fixed effects + race-interaction layer + Bayesian
posterior uncertainty propagation.

Distinct from Study 01 (which decomposes SMM stratifiers without a
shock); Study 03 leverages the Dobbs decision as an external shock for
identification. Could potentially share infrastructure with Study 01
if HCUP NIS becomes available (would add CZ-level SMM as a fourth
outcome in v2).

---

**Lock author:** Nathan Humphrey
**Lock date:** 2026-05-24
**Lock SHA:** TBD (will be the commit SHA of this file)
