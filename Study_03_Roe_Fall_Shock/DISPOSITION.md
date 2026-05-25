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

## Next steps (if revisiting)

- Re-export WONDER with Year as a 4th group-by → unlock DiD/ITS
  analysis via existing `scripts/07a*` and `07b*` harness
- Pursue Myers county-distance OSF file → adds clinic-access dimension
- Hand-code state time-to-ban-days → enables continuous-intensity
  sensitivity beyond the 4-level ordinal
- All three above are upgrades; none are required for the
  cross-sectional finding above which stands on its own.
