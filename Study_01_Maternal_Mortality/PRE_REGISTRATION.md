# Pre-Registration — Severe Maternal Morbidity Decomposition in US Hospitalizations

**Locked: 2026-05-18**

## §1 Motivation and goal

US severe maternal morbidity (SMM) is rising, racially stratified, and
under-quantified with proper uncertainty. Black women experience SMM at
roughly 2–3× the rate of white women, Medicaid-covered births show
excess SMM relative to private insurance, and rural hospitals show
distinct outcome patterns from urban — but the existing literature is
dominated by descriptive epidemiology and logistic regressions with
crude stratifier main effects. **Within-stratum variance is treated as
noise. Across-stratum interactions are largely undermodeled.**

This study applies the corpus's residue-class decomposition thesis
("noise is misclassified structure") to SMM: pull structured variance
out of the conventional residual by modeling the
race × hospital-class × insurance × parity × age × comorbidity ×
geography interaction space with hierarchical Bayesian models with
proper posterior uncertainty.

**Deliverable:** quantified disparities across the joint stratifier
space, with credible intervals, identifying which stratum combinations
carry disproportionate SMM risk that descriptive epi has not properly
quantified.

**Editorial framing:** Pro-women, full stop. The disparities exist, are
well-documented, and quantifying them with proper uncertainty serves
women's health. We do not bury findings in "may reflect" or
"complex factors." If the data shows a disparity at the
1.5× rate ratio with CI excluding null, we report it as such.

## §2 Substrate

**Primary data source:** **HCUP National Inpatient Sample (NIS)**,
years 2017–2021. Patient-discharge-level data with diagnosis codes,
procedures, demographics, payer, hospital characteristics. Free access
for non-profit research via HCUP-US central distributor; requires DUA
signing but no fee or extended approval. Approximate sample size: ~7M
discharges/year, of which ~3.6M are births. Approximate SMM event
count under CDC's 21-indicator definition: ~50,000–70,000 events/year.

**Population definition:**
- Female sex
- Delivery hospitalization, identified by DRG codes (765, 766, 767,
  774, 775) AND/OR ICD-10-PCS delivery procedure codes (10D00Z0,
  10D00Z1, 10D00Z2, 10E0XZZ, 10D07Z3–8, etc.)
- Age 12–55 at admission (excludes administratively-coded outliers)

**Auxiliary data sources:**
- **CDC WONDER** for cross-validation of county-level rates where NIS
  geographic granularity is suppressed
- **State Medicaid expansion status** (KFF dataset, public) for state-
  level binary covariate
- **CDC SMM 21-indicator definition** (NCHS / CDC Maternal Mortality
  Surveillance, public reference)

**No paywalled or registration-gated cohort in v1.** Studies that
require additional access (CCSS, WHI restricted, etc.) are deferred.

## §3 Outcome structure (multivariate)

**Outcome unit:** SMM per delivery hospitalization. CDC's 21 SMM
indicators are individually coded.

**Per-indicator binary outcomes (21 models):**

| Indicator group | ICD-10 codes (illustrative) |
|---|---|
| Acute myocardial infarction | I21.x, I22.x |
| Aneurysm | I71.x |
| Acute renal failure | N17.x |
| Adult respiratory distress syndrome | J80, J95.82 |
| Amniotic fluid embolism | O88.1 |
| Cardiac arrest / V-fib | I46.x, I49.0x |
| Cardioversion / conversion of cardiac rhythm | 5A22.x procedures |
| Disseminated intravascular coagulation | D65, D68.4 |
| Eclampsia | O15.x |
| Heart failure during procedure / surgery | I97.13x |
| Puerperal cerebrovascular disorders | O22.5x, O87.3 |
| Pulmonary edema / acute heart failure | J81, I50.x |
| Severe anesthesia complications | O29.x |
| Sepsis | O85, A40.x, A41.x |
| Shock | R57.x, O75.1 |
| Sickle cell disease with crisis | D57.0x, D57.21x, D57.41x |
| Air and thrombotic embolism | O88.0x, O88.2x, O88.3x |
| Blood products transfusion | 30233M1, 30233N1, 30233P1 |
| Hysterectomy | 0UT9.x |
| Temporary tracheostomy | 0B11.x |
| Ventilation | 5A1935Z, 5A1945Z, 5A1955Z |

**Composite binary outcome:** ANY SMM indicator present (CDC's primary
composite). Reported as 22nd outcome alongside the 21 individual.

**Power caveat (pre-committed):** Several indicators (amniotic fluid
embolism, sickle crisis, acute MI) have <0.01% event rates. Per-indicator
models for low-frequency indicators will be reported with explicit
underpowered framing. Indicators with fewer than 200 events across the
full study window report descriptive proportions only, no inference.

## §4 Stratifiers / covariates (locked)

Eight stratifier dimensions, all included as fixed-effect covariates
AND/OR random-effect levels in the hierarchical structure depending on
model variant (§5):

| dimension | levels / coding | source field |
|---|---|---|
| Race / ethnicity | Non-Hispanic White / Non-Hispanic Black / Hispanic / Non-Hispanic Asian-Pacific Islander / Non-Hispanic American Indian-Alaska Native / Other-Multiracial | RACE (NIS) |
| Insurance (primary payer) | Medicaid / Private / Self-pay-uninsured / Other (military / IHS / no charge) | PAY1 (NIS) |
| Parity | Continuous gravidity-derived count if codeable; tertile fallback (0 / 1–2 / 3+) | Derived from O09.x, Z3A.xx codes; admitted as continuous primary, tertile fallback if coverage <80% |
| Hospital bed size | Small / Medium / Large (HCUP standard) | HOSP_BEDSIZE (NIS) |
| Hospital urban/rural | Large central metro / Large fringe metro / Medium metro / Small metro / Micropolitan / Non-core (HCUP NCHS urban-rural 6-level) | HOSP_LOCTEACH or HOSP_URCAT4 (NIS) |
| Maternal age group | 12–17 / 18–24 / 25–29 / 30–34 / 35–39 / 40+ | AGE (NIS), binned |
| Comorbidities (pre-existing) | Chronic HTN (Y/N), pre-existing diabetes (Y/N), prior cesarean (Y/N) | ICD-10 diagnosis codes, separate binary covariates |
| State Medicaid expansion | Y/N as of delivery year | KFF expansion table, joined on HOSP_STATE × year |

**EXPLICITLY EXCLUDED: BMI / obesity codes.** Per editorial policy, BMI
is a false measure that conflates lean mass, fat mass, and ancestry-
specific composition. Obesity ICD codes (E66.x) are noisy and
selection-biased. If body composition matters mechanistically for a
specific indicator, separate v2 sub-study with proper composition
proxies.

## §5 Methodology framework (three model families, run in parallel)

**Family 1 — Hierarchical Bayesian logistic regression (Wilson flavor #1, primary).**

For each of 22 outcomes (21 indicators + composite):

```
P(SMM_indicator_k | X) = logit^-1(α_state + β_race + β_insurance +
                                   β_parity + β_bed_size + β_urban_rural +
                                   β_age + β_comorbidity_set +
                                   β_medicaid_expansion +
                                   trial-year-fixed-effect)
```

State-level random intercept absorbs unobserved state-level variation
(Medicaid program design heterogeneity, abortion-access regimes, etc.).
Year as fixed effect.

Priors: weakly informative — Normal(0, 2.5) on log-odds coefficients,
half-Cauchy(0, 2.5) on random-effect SD.

**Family 2 — Family 1 + Causal-Bayes priors on hospital-class selection (Wilson flavor #4).**

Higher-acuity hospitals select for higher-risk patients (indication
confounding). Family 2 adds an informative prior on the hospital-bed-
size coefficient anchored at zero (i.e., expressing the prior belief
that bed size per se doesn't cause SMM — observed effects reflect case
mix). Prior: Normal(0, 0.5) on the bed-size log-odds coefficient (tight,
near-zero), wider Normal(0, 2.5) on race, insurance, parity, age, etc.
Tests whether observed bed-size effects survive the informative
shrinkage.

**Family 3 — Latent-class mixture over SMM indicator co-occurrence (Wilson flavor #3, exploratory).**

For patients with ≥1 SMM event, model the joint occurrence pattern of
the 21 indicators as a mixture of K latent classes. K selected by
leave-one-out cross-validation. Per-class indicator-occurrence
probability + per-class stratifier-distribution.

Latent class is the SMM "subtype." Identifies whether stratifier
patterns predict different SMM subtypes (e.g., do Medicaid + rural +
Black combine to predict the hemorrhage-DIC-hysterectomy subtype
distinctly vs the eclampsia-cerebrovascular subtype).

Pre-committed as exploratory. Family 3 results reported but not used
for primary disposition; supports v2 follow-up scoping.

## §6 Temporal contrasts (three windows)

Three temporal cuts of the same NIS data, all reported:

1. **Single year — most recent (2021)**: sharpest single-year resolution,
   smaller power per indicator, captures post-pandemic state.
2. **Rolling 5-year (2017–2021)**: maximum power per indicator,
   averages across pandemic and pre-pandemic dynamics.
3. **Pre-pandemic vs pandemic split (2017–2019 vs 2020–2021)**: tests
   whether the pandemic shifted SMM disparities. Models fit on each
   half; coefficient differences reported with appropriate
   uncertainty propagation.

All three contrasts reported for all 22 outcomes × all 3 model
families. Total reported result count: 22 × 3 × 3 = 198 model fits.

Power-low indicators (events < 200 in any contrast window) report
descriptive proportions only for that window.

## §7 Held-out validation

Pre-registered held-out split: **80/20 patient-level random split,
stratified by state × outcome (composite SMM)**, seed `20260518`.
Frozen at `reference/holdout_split.rda` before model fits.

For each model family × outcome × contrast: report posterior predictive
checks + held-out log-likelihood + AUC (for binary outcomes) + per-
stratifier marginal effect with held-out CI.

## §8 Decision rule

**A stratifier-level is identified as a "flag"** if BOTH:

1. Posterior 95% credible interval on the marginal log-odds excludes
   zero in the held-out validation
2. Practical-significance threshold: implied rate ratio ≥ 1.20 (20%
   higher rate at that stratum vs reference) OR ≤ 0.83 (20% lower rate)

**Flag tiers:**
- **Strong flag**: passes both rules in Family 1 (primary) AND Family 2
  (causal-Bayes), AND in ≥2 of 3 temporal contrasts
- **Conditional flag**: passes both rules in Family 1 only, or in
  only 1 of 3 contrasts. Reported with conditioning.
- **Null**: fails one or both rules in Family 1.

**Reporting commitment:** ALL 198 results reported regardless of
outcome direction. No selective reporting. Public results table
includes the full joint disposition. No flag is hidden because
"it's politically awkward." No flag is amplified because "it's the
headline we wanted." We run the numbers all three ways and just
report the facts.

## §9 Pro-women framing rules (editorial)

These are not negotiable post-lock:

1. **Disparity language is direct.** "Black women experience SMM at
   X.X× the rate of white women, 95% CI [A.A, B.B]" — not "Black
   women may be at higher risk."
2. **System-level framing for structural disparities.** When a
   stratifier flag identifies elevated risk in lower-resource
   contexts (rural, small bed size, Medicaid), framing acknowledges
   the structural conditions producing the disparity — not implying
   provider blame or patient blame.
3. **No "complex factors" hedging.** If the data shows a 1.5×
   disparity at CI excluding null, we name it as such. Mechanistic
   uncertainty is acknowledged in the discussion section, not buried
   in the headline.
4. **"Pro-women" framing applies to the writeup; the methodology is
   neutral.** We don't tune priors or thresholds to produce favored
   findings. We let the data speak with proper uncertainty. The
   editorial framing operates on TRUE findings.
5. **BMI is excluded as a stratifier.** See §4.

## §10 Execution sequence

1. **HCUP DUA + data pull** (`scripts/00_pull_nis.R`): register with
   HCUP-US, sign DUA, pull NIS 2017–2021 core files + hospital
   characteristics files
2. **Population restriction** (`scripts/01_define_population.R`):
   identify delivery hospitalizations per §2; output denominator counts
3. **Outcome coding** (`scripts/02_code_smm_indicators.R`): per
   CDC's 21-indicator ICD-10 code list, build 22 binary outcomes
4. **Stratifier harmonization** (`scripts/03_harmonize_stratifiers.R`):
   parity extraction, age binning, comorbidity flags, Medicaid-
   expansion join
5. **Held-out split** (`scripts/04_build_holdout_split.R`): 80/20
   stratified, seed 20260518, frozen at `reference/holdout_split.rda`
6. **Model fits — Family 1** (`scripts/05a_fit_family1_hierarchical.R`):
   22 outcomes × 3 temporal contrasts = 66 fits, brms/Stan, 4 chains × 4k iter
7. **Model fits — Family 2** (`scripts/05b_fit_family2_causal.R`):
   same structure with informative bed-size prior, 66 fits
8. **Model fits — Family 3** (`scripts/05c_fit_family3_latent.R`):
   K-selection by LOO-CV, then 3 fits (1 per temporal contrast)
9. **Convergence + diagnostics** (`scripts/06_convergence.R`):
   R-hat < 1.01, bulk-ESS > 1000 per parameter
10. **Held-out evaluation** (`scripts/07_holdout_eval.R`):
    per-outcome × per-stratifier × per-family × per-contrast flag
    identification per §8
11. **Disposition writeup** (`DISPOSITION.md`): all 198 results in a
    public results table; strong flags / conditional flags / null
    annotated; editorial framing per §9

## §11 Constraints (load-bearing, no exceptions)

1. **No covariate substitution.** Once `holdout_split.rda` is committed
   (Step 5), the population and split are locked.
2. **No selective reporting.** All 198 result rows go in the public
   table. No hidden models. No "we tried X but didn't report it."
3. **No methodology pivot post-lock.** Families 1, 2, 3 are locked.
   Additional families require a pre-reg amendment in DEVIATIONS.md
   with explicit rationale.
4. **No BMI re-introduction without explicit pre-reg amendment.**
5. **No mid-analysis prior tuning.** Priors are weakly-informative per
   §5. Adjusting priors mid-analysis is a deviation.
6. **Deviations from this pre-reg** logged in `DEVIATIONS.md` with
   date, rationale, and preserved pre-deviation artifacts.

## §12 Sample-size and power-aware framing

NIS 2017–2021: ~18M delivery hospitalizations across 5 years.
CDC SMM aggregate rate ~1.8 per 100 deliveries (CDC reference).
Expected composite SMM events: ~325k across the 5-year window.

Per-indicator event counts (illustrative, may vary with coding):
- Common (hemorrhage transfusion, hysterectomy): >50k events
- Moderate (sepsis, eclampsia, DIC, pulmonary edema): 5k–25k events
- Rare (amniotic fluid embolism, acute MI, sickle crisis): <500 events

Power is adequate for common + moderate indicators on the
stratifier-cross structure. Rare indicators handled descriptively
per §3 caveat.

## §13 Position relative to corpus

Direct port of the Sloan partial-pooling methodology used in
[NBA coaching paper](https://github.com/mrnathanhumphrey-droid) and
the gun-violence v0.2 race-x-inequity decomposition (whose race × CI
excludes null finding is the closest statistical analog). The
hierarchical-state-random-effect structure transfers directly. The
causal-Bayes flavor-2 addition (informative prior on bed-size) is
the new methodological piece relative to those priors.

Editorial framing differs from those papers: pro-women framing is
explicit and unapologetic per §9.

---

**Lock author:** Nathan Humphrey
**Lock date:** 2026-05-18
**Lock SHA:** TBD (will be the commit SHA of this file)
