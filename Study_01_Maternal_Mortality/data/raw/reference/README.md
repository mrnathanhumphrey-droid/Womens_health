# Reference Data — Study 01

Public reference data vendored for Study 01 SMM decomposition. None of
these require HCUP DUA. All are committed to git as audit artifacts.

## Files

| File | Source | Vendored | Notes |
|---|---|---|---|
| `cdc_smm_21_indicators.csv` | [CDC SMM ICD page](https://www.cdc.gov/maternal-infant-health/php/severe-maternal-morbidity/icd.html) | 2026-05-18 | 21 indicators with ICD-10-CM and ICD-10-PCS codes; blood transfusion flagged for separate treatment per CDC convention |
| `kff_medicaid_expansion.csv` | [KFF Medicaid Expansion Tracker](https://www.kff.org/affordable-care-act/state-indicator/state-activity-around-expanding-medicaid-under-the-affordable-care-act/) | 2026-05-18 | 51 rows (50 states + DC). 41 adopted, 10 not adopted as of 2026-05 |

## Methodological notes

**Blood transfusion handling (CDC convention):** CDC reports two
composite SMM rates:
- **SMM excluding transfusion-only** (20 indicators) — PRIMARY composite
- **SMM including transfusion** (21 indicators) — SECONDARY composite

The Study 01 pre-reg's "composite" outcome will be operationalized as
SMM-excluding-transfusion (primary) with SMM-including-transfusion
reported as a sensitivity/secondary outcome. Blood transfusion is also
reported as its own indicator outcome (per pre-reg §3 "per-indicator
multivariate"). This is a clarification within the pre-reg, not a
deviation — the pre-reg already specified 21 individual + 1 composite,
and CDC convention specifies the composite construction.

**Medicaid expansion effective date join:** the binary
state_x_year_medicaid_expansion variable will be coded TRUE if a
state's implementation date precedes the delivery hospitalization
date. North Carolina (effective 2023-12-01) and South Dakota
(2023-07-01) implementations are post-2021 — for the 2017–2021 NIS
window, both code as "Not Adopted." Missouri (2021-10-01) provides
a partial-year boundary that should be coded at the discharge-date
level if NIS provides admission month (or treated as Adopted only
for Q4 2021 discharges).

## To be added

- **NCHS Urban-Rural Classification Scheme** for hospital location
  (6-level: Large Central Metro / Large Fringe Metro / Medium Metro /
  Small Metro / Micropolitan / Non-core). NIS provides a derived
  version of this via HOSP_URCAT4 (4-level collapsed) — may need to
  use the 4-level version and document the collapse.
- **HCUP NIS variable codebook** — once DUA is in place and data
  is downloaded.
