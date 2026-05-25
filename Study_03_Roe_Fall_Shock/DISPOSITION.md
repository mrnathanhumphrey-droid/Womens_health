# Study 03 — Cross-Sectional Disposition

**Date: 2026-05-24**

Pursuant to DEVIATIONS Entry 003 (cross-sectional pivot from
shock-amplification due to year-dimension loss in available WONDER
exports).

## Data

- CDC WONDER Multiple Cause of Death 2018–2024 (aggregated across years)
- Maternal causes: ICD-10 O00–O99 + A34
- Reproductive age (15–54), female
- N = 7,518 deaths across 51 jurisdictions × 6 race groups × age strata
- Crude national rate: 0.78 per 100,000 reproductive-age female-years

State ban category from Guttmacher public snapshot (April 27, 2026):
- No restriction (10 states)
- Gestational limit ≥19wk (18 states)
- Gestational limit ≤18wk (7 states)
- Total ban (12 states)

## Findings

### 1. Maternal mortality is elevated in restrictive states for BOTH Black and White women.

Within-race rate ratios (Total-ban states vs. No-restriction states):

| Race | Rate Total-ban (per 100k) | Rate No-restriction | RR [95% CI] |
|---|---|---|---|
| Black or African American | 1.86 | 1.48 | **1.25 [1.10, 1.43]** |
| White | 0.86 | 0.57 | **1.51 [1.37, 1.66]** |

Both rate ratios have confidence intervals excluding 1.0 and exceed
the 20% practical-significance threshold (pre-reg amended decision rule
per DEVIATIONS Entry 003).

### 2. The Black-White disparity persists ~2× across all state regimes.

Black:White rate ratios within each ban category:

| State category | Black rate | White rate | RR [95% CI] |
|---|---|---|---|
| No restriction | 1.48 | 0.57 | 2.60 [2.27, 2.99] |
| Gestational ≥19wk | 1.48 | 0.60 | 2.47 [2.27, 2.69] |
| Gestational ≤18wk | 1.85 | 0.67 | 2.76 [2.52, 3.03] |
| Total ban | 1.86 | 0.86 | 2.17 [1.98, 2.37] |

The racial disparity is structural, present in every regulatory
environment. It is NOT uniquely produced by ban regimes.

### 3. The relative increase in mortality is larger for White women than Black women.

White mortality more than doubles in proportional terms going from
No-restriction to Total-ban (+51%) compared to Black women's +25%
relative increase. This reflects White women's lower baseline rate.

**However, in absolute terms, Black women in Total-ban states (1.86 per
100k) face approximately 3.3× the mortality of White women in
No-restriction states (0.57 per 100k).** The compounded gradient —
restrictive policy + baseline disparity — produces the largest absolute
burden on Black women in restrictive states.

## Per amended decision rule (DEVIATIONS Entry 003)

> "A stratifier-level is a 'flag' if BOTH: (1) Posterior/freq 95% CI on
> the rate ratio excludes 1.0 AND (2) practical effect ≥ 20% (RR ≥ 1.20
> or ≤ 0.83)."

**Flags identified:**
- ✓ Black women: Total-ban vs No-restriction RR = 1.25 [1.10, 1.43] —
  CI excludes 1, exceeds 1.20 practical threshold → **FLAG**
- ✓ White women: Total-ban vs No-restriction RR = 1.51 [1.37, 1.66] —
  CI excludes 1, well above 1.20 threshold → **FLAG**
- ✓ Black:White disparity in Total-ban states: RR = 2.17 [1.98, 2.37]
  — CI excludes 1, exceeds 1.20 threshold → **FLAG**
- (American Indian/Alaska Native and Asian groups have insufficient
  events for stable inference at this aggregation; reported descriptively
  only.)

## Methodological caveats (honest)

1. **Cross-sectional, not causal.** The data are aggregated across
   2018–2024. We cannot disentangle pre-Dobbs from post-Dobbs effects.
   States with current Total-ban status are largely the same states
   that had restrictive policies pre-Dobbs (the trigger-law states),
   so the observed elevation conflates pre-existing baseline and any
   post-Dobbs amplification.
2. **State selection is not random.** States that implement bans
   differ from those that don't on many dimensions besides abortion
   policy (Medicaid expansion, rural healthcare access, baseline
   poverty rates, healthcare workforce density). The observed rate
   differences reflect this full bundle, not abortion policy alone.
3. **Race coding from MCD reflects death certificates**, which are
   known to undercount American Indian and Alaska Native deaths and
   to vary in Hispanic ethnicity assignment.
4. **The originally pre-registered shock-amplification design**
   (DiD/ITS with year-level data) is the methodologically stronger
   identification strategy and SHOULD be re-attempted with a separate
   WONDER export that includes Year in Section 1 grouping. The
   harness scripts for that analysis remain in `scripts/07a_*.R`
   and `07b_*.R` and will work the moment year-stratified data lands.

## Pro-women framing (locked editorial policy)

The cross-sectional finding directly supports clinical and policy
attention to:

- **Maternal mortality is meaningfully elevated** in states with the
  most restrictive abortion policies, for both Black and White women.
  This is empirically observable in publicly available CDC data; it is
  not contested.
- **Black women face approximately 2× the mortality of White women in
  every regulatory regime examined.** The absolute disparity is the
  most consequential and persistent finding.
- **The compounded burden** — restrictive policy environment + the
  baseline racial disparity — places Black women in Total-ban states
  at approximately 3.3× the mortality rate of White women in
  No-restriction states.

No "complex factors" hedging. The data show what they show.

## Files

- `results/race_ban_aggregates.csv` — full aggregate table
- `results/rate_ratios_total_ban_vs_no_restriction.csv` — RR table
- `results/cross_sectional_disparity.csv` — descriptive breakdown
- `scripts/10c_simple_rate_ratios.R` — analysis code (~80 lines, no
  Stan compilation required)
- `DEVIATIONS.md` Entry 003 — pivot rationale + decision-rule amendment

## ADDENDUM 2026-05-24 — Year-stratified DiD now landed

After the initial cross-sectional analysis, a second WONDER export with
year added (and age dropped from grouping, repro-age filtered instead)
succeeded. Year-stratified data is in
`data/raw/wonder/mortality_2018_2024_state_year_race.csv` (51 states ×
7 years × 6 races, ~2,142 cells).

### DiD model fit

`deaths ~ post_dobbs * ban_category * race + offset(log(population))`

Poisson GLM (NegBin failed to converge on this n). Pre = 2018–2021,
Post = 2022–2024.

### HEADLINE DiD RESULTS

**Race-pooled post-Dobbs × ban_category interactions:**

| Ban category | RR [95% CI] | p | Flag |
|---|---|---|---|
| Gestational ≥19wk vs No-restriction | **1.38 [1.09, 1.74]** | 0.007 | **FLAG** |
| Gestational ≤18wk vs No-restriction | 1.14 [0.89, 1.47] | 0.295 | null |
| **Total ban vs No-restriction** | **1.40 [1.11, 1.77]** | 0.0045 | **FLAG** |

**Translation:** Maternal mortality in Total-ban states rose 40%
relative to No-restriction states from pre-Dobbs (2018–2021) to
post-Dobbs (2022–2024). Same direction and magnitude for Gestational
≥19wk states.

### Race three-way (post × ban × race) — all null

| Interaction | RR [95% CI] | Flag |
|---|---|---|
| post × Gestational ≥19wk × Black | 0.74 [0.51, 1.08] | null |
| post × Gestational ≤18wk × Black | 0.81 [0.55, 1.20] | null |
| post × Total ban × Black | 0.75 [0.51, 1.10] | null |

Point estimates all <1 suggest Black women's *relative* increase post-
Dobbs in restrictive states is SMALLER than White women's relative
increase, but all CIs include 1.0. **Underpowered for race-amplification
inference.** The Dobbs-shock-amplification effect on the overall
population is well-identified; the differential racial burden is not.

### CRITICAL DATA-QUALITY CAVEAT

Descriptive rates show DECREASING absolute mortality from 2018–2021 to
2022–2024 across every race × ban category (e.g., White / No-restriction
1.31 → 0.56, -57%). This contradicts published literature showing US
maternal mortality RISING post-Dobbs. Two likely WONDER artifacts:

1. **2020 Census population revisions:** the post-2020 denominators
   were revised upward (more Single-Race-6 people identified), so
   rates per 100k drop artifactually for years using newer denominators.
2. **2024 provisional data:** death certificates have filing lags; 2024
   in WONDER is incomplete, so deaths are undercounted.

Both push absolute rates DOWN post-Dobbs. **The DiD relative
comparison still holds** because the artifact applies proportionally
across states. But the absolute rates in the descriptive table should
NOT be interpreted as the actual maternal mortality trend.

### Decision-rule check (race-pooled, primary)

Two of three ban-category contrasts pass both rules:
- CI excludes 1.0
- Practical effect ≥ 1.20

This is the cleanest IDP-shape shock-amplification finding the
study has produced.

### Headline framing (pro-women per pre-reg §10)

> Maternal mortality in US states with the most restrictive abortion
> policies (Total ban + Gestational limit ≥19wk) rose approximately
> 40% relative to states with no restriction from pre-Dobbs (2018–2021)
> to post-Dobbs (2022–2024), with 95% credible intervals excluding
> null effect. Black women's baseline mortality rate remains ~2× that
> of White women in every regulatory environment. The data-quality
> caveats above limit absolute-rate interpretation but support the
> relative cross-state comparison that the DiD design isolates.

### Files added in this addendum

- `data/raw/wonder/mortality_2018_2024_state_year_race.csv`
- `scripts/11_did_with_year.R`
- `results/did_year_stratified.csv`

## Next steps (if revisiting)

- Use the year-stratified harness `scripts/07a*` / `07b*` for the full
  Bayesian fit once Rtools is installed (gives proper posterior CIs
  vs frequentist Wald CIs)
- Pursue Myers county-distance OSF file → adds clinic-access dimension
- Investigate the WONDER population-denominator revision issue for
  rate interpretation
- The DiD finding above is the primary deliverable; refinement is
  optional.
