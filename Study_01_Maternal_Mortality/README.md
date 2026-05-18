# Study 01 — Maternal Mortality & Severe Maternal Morbidity Decomposition

**Status (2026-05-18):** **PRE-REGISTRATION LOCKED.** Design fully specified in
[PRE_REGISTRATION.md](PRE_REGISTRATION.md). HCUP NIS data acquisition is
the next gating step. No compute fired.

**Headline locks:**
- **Substrate:** HCUP National Inpatient Sample 2017–2021, ~18M delivery
  hospitalizations, ~325k composite SMM events expected
- **Outcomes:** All 21 CDC SMM indicators modeled individually +
  composite (22 outcomes total)
- **Stratifiers:** race / insurance / parity / hospital bed size / hospital
  urban-rural / maternal age / comorbidities (chronic HTN, pre-existing
  diabetes, prior cesarean) / state Medicaid expansion
- **BMI explicitly EXCLUDED** — false measure per editorial policy
- **Methodology:** 3 model families in parallel — hierarchical logistic
  (Family 1, primary) + causal-Bayes priors on hospital selection
  (Family 2) + latent-class SMM-subtype mixture (Family 3, exploratory)
- **Temporal contrasts:** single-year 2021 / rolling 5-year 2017–2021 /
  pre-pandemic-vs-pandemic split — all three reported
- **Decision rule:** posterior 95% CI excludes null AND rate ratio ≥ 1.20
- **Reporting:** 198 result rows (22 outcomes × 3 families × 3 contracts).
  All reported regardless of direction. No selective reporting.
- **Editorial:** Pro-women framing, direct disparity language, no
  "complex factors" hedging.

## Question

Decompose US maternal mortality and severe maternal morbidity (SMM)
incidence across race × geography × insurance, with proper uncertainty
propagation. Identify which strata carry disproportionate risk that
standard logistic regression and descriptive analyses under-quantify.

## Why this study

- **US maternal mortality is the worst among developed countries** and
  the gap is growing, not shrinking. Black women die at 2.6× the rate of
  white women; rural counties exceed urban; Medicaid-covered births show
  excess SMM relative to private insurance.
- **Bayesian literature on the decomposition is thin** — most published
  work uses logistic regression and descriptive tables. Hierarchical
  modeling with proper credible intervals across the race × geography ×
  insurance interactions is largely absent.
- **Public data is downloadable today** with no DUA or registration
  delay. CDC WONDER (mortality) and HCUP NIS (SMM diagnoses in
  hospitalizations) are immediate-access.
- **The decomposable structure suits hierarchical models natively** —
  geography nests within states, race interacts with insurance,
  insurance interacts with geography (Medicaid expansion variation).

## Substrate

- **CDC WONDER** — multiple-cause-of-death + natality, county-level
  aggregation (privacy floor at low counts), free public access
- **HCUP National Inpatient Sample (NIS)** — hospitalization-level SMM
  via CDC SMM 21-indicator definition, available via HCUP-US
  (free for non-profit research, simple registration)
- Possible auxiliary: **state Maternal Mortality Review Committee
  reports**, **CDC PMSS** (Pregnancy Mortality Surveillance System)
  aggregate counts

## Open framing decisions

To be locked before pre-registration:

1. **Outcome:** mortality only, SMM only, or both as separate models?
2. **Geographic granularity:** county / commuting zone / metro vs
   non-metro / state? Tradeoff between resolution and small-count
   privacy suppression in CDC WONDER.
3. **Time window:** rolling 5-year (smooths small counts) vs single
   year (responsiveness to policy changes).
4. **Insurance categories:** Medicaid / private / uninsured / other —
   how to handle "other" (self-pay, military, IHS).
5. **Race / ethnicity categories:** CDC standard (Hispanic ethnicity
   crossed with race) or collapsed multi-race?
6. **Methodology framework:** Hierarchical Poisson / negative binomial
   for mortality counts? Logistic for SMM? Bayesian model averaging
   over geographic specifications?
7. **Decision rule:** what counts as a strong decomposition flag?
   Effect size threshold + credible-interval-excludes-null criteria
   to be pre-committed.

## Execution sequence (planned, NOT locked)

1. Scope CDC WONDER + HCUP NIS data dictionaries, identify the
   maternal death codes (ICD-10 O00–O99, A34) and SMM 21-indicator
   ICD codes
2. Pull aggregated data (CDC WONDER) + microdata (HCUP NIS)
3. Lock pre-registration with all framing decisions
4. Build harmonized analysis table
5. Pre-registered held-out split (or temporal validation)
6. Fit hierarchical models
7. Convergence + sensitivity diagnostics
8. Disposition writeup

## Position

This is the first active study in the [women's health corpus](../).
The cisplatin-study pre-registration template at
[mrnathanhumphrey-droid/Cisplatin_Study](https://github.com/mrnathanhumphrey-droid/Cisplatin_Study)
is the structural reference for how this study's pre-reg will read.
