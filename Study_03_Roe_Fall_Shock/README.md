# Study 03 — Dobbs/Roe-fall Shock: Differential Maternal Mortality Response by Historical Restriction Geography

**Status (2026-05-24):** Active — framing. No pre-reg locked yet.
Methodology shape ported from IDP project's shock-amplification design.

## Question

**Do populations with pre-existing exposure to abortion-restriction
infrastructure (TRAP laws, clinic scarcity, Medicaid restrictions)
show differential maternal mortality response to the Dobbs decision
shock?**

The Dobbs v. Jackson Women's Health Organization decision (June 24,
2022) overturned Roe v. Wade. Multiple states immediately implemented
abortion bans or severe restrictions via trigger laws; many others
already had pre-existing restriction infrastructure (TRAP laws,
gestational limits, clinic distance requirements, Medicaid funding
restrictions).

The hypothesis: states/counties with **higher pre-existing restriction
density** show **larger post-Dobbs maternal mortality increases** than
states/counties with lower pre-existing restriction. The Dobbs shock is
amplified where the infrastructure to amplify it was already in place.

## Methodology shape (IDP-port)

This is a difference-in-differences / interrupted time series with
continuous treatment-intensity, where:

- **Outcome:** maternal mortality rate (or SMM rate) at the county-year
  level
- **Shock:** Dobbs decision, June 2022 (sharp temporal cut)
- **Treatment intensity:** pre-Dobbs (2017–2022 Q1) abortion-restriction
  exposure, continuous (e.g., Guttmacher restriction-score, distance to
  nearest clinic, TRAP law density)
- **Effect modifier of interest:** post-Dobbs change × pre-Dobbs
  restriction intensity → interaction coefficient
- **Comparison:** within-county pre-Dobbs trajectory vs post-Dobbs
  level shift, modeled hierarchically

Aligns with the IDP project's shock-amplification methodology shape:
"do populations with historical exposure show differential response to
contemporary shocks?"

## Why this study

- **Politically charged but methodologically clean.** The data exist,
  the temporal cut is sharp (June 2022), the policy variation is
  externally imposed, the outcome is hard (death registration). This is
  a well-identified natural experiment.
- **Bayesian methodology lets us propagate uncertainty about the
  treatment effect as a function of pre-existing exposure** — which
  conventional DiD with point-estimate interactions doesn't.
- **Pro-women framing aligns with the corpus.** If pre-existing
  restriction amplifies the Dobbs maternal-mortality effect, the
  finding directly informs which policy regimes endanger women most.
  The result speaks for itself; methodology stays neutral.

## Data substrate

| Source | What it provides | Access |
|---|---|---|
| **CDC WONDER Multiple-Cause-of-Death** | County-level maternal mortality counts by year, race, age; ICD-10 O00–O99, A34, possibly J wider definitions | Public, no DUA |
| **CDC WONDER Natality** | Live births per county-year (denominator for mortality rates) | Public, no DUA |
| **PRAMS / PRAMStat** | State-level pregnancy-risk monitoring survey aggregates (preconception care, maternal health behaviors, postpartum outcomes) | Public via CDC PRAMStat (aggregate only); microdata requires application |
| **Guttmacher Institute Policy Database** | State-by-month abortion-policy variables 2017–present (gestational limits, TRAP laws, Medicaid funding, clinic distance estimates) | Public aggregates; quarterly state policy data downloadable |
| **KFF Abortion Policy Tracker** | Post-Dobbs state-by-state ban/restriction status with effective dates | Public |
| **Caitlin Myers' Abortion Access Distance Dataset** | County-level distance-to-nearest-clinic 2009–present, peer-reviewed | Public, supplemental tables |

All primary sources are public. No DUA wait. **This study can fire
immediately** once design is locked.

## Open framing decisions (NOT locked)

1. **Outcome:** maternal mortality (rare, ~700-1300/yr nationally) vs
   SMM (richer signal but requires NIS or state hospital data) vs
   pregnancy-associated death (broader CDC definition including
   accidents/overdose/suicide in pregnancy period)
2. **Temporal cut precision:** sharp Dobbs date (June 2022) vs state-
   specific ban-effective-dates (trigger-law states differ in timing
   from June 2022 through 2023)
3. **Pre-existing restriction measure:** Guttmacher composite score vs
   clinic-distance vs TRAP-law-count vs latent index from multiple
   measures
4. **Geographic unit:** county (cell counts often suppressed by CDC
   WONDER for small counties) vs commuting zone vs state
5. **Time window:** how many pre-Dobbs years for baseline trajectory
   (3? 5? all post-ICD-10-2015?), how many post-Dobbs years for
   response (rolling as data lands)
6. **Race/ethnicity stratification:** pre-Dobbs racial disparities in
   maternal mortality are large; post-Dobbs amplification may be
   racially differential. Build in as interaction or stratify analyses?
7. **Methodology:** Bayesian DiD with continuous treatment intensity
   (most natural for the question), or hierarchical interrupted time
   series, or synthetic-control panel approach

## Constraints from pre-reg discipline (will carry forward)

- Pre-reg locked at SHA before any analysis
- Decision rule pre-committed
- 80/20 held-out (or temporal holdout — likely the latter for ITS)
- Deviations logged
- Pro-women editorial framing
- No selective reporting

## Position

Third study in the [women's health corpus](../). Methodologically
distinct from Study 01 (which decomposes SMM stratifiers without a
shock); Study 03 leverages an external shock as the identification
strategy. Could potentially share data infrastructure with Study 01
(CDC WONDER + state policy joins) once both are running.
