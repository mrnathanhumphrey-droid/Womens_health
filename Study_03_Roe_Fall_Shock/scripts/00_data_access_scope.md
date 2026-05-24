# Study 03 — Data Access Scope

**Scoped: 2026-05-24**

All six data sources are public. Most can be pulled via API or direct
download. Two require manual download from public portals (no fees,
no DUA, but no programmatic API).

## Source-by-source

### 1. CDC WONDER Multiple-Cause-of-Death + Natality

- **URL:** https://wonder.cdc.gov/
- **Access:** Public, no registration
- **Programmatic:** R package `wondR` (community) or POST XML requests
  to the WONDER API directly (https://wonder.cdc.gov/wonder/help/WONDER-API.html)
- **Suppression:** Cell counts < 10 are suppressed
- **Maternal mortality query parameters:**
  - Multiple-Cause-of-Death: ICD-10 O00–O99 + A34
  - Female, age 10–55
  - Year 2017–latest available
  - Group by: County (or State), Year, Race/Ethnicity, Age group
- **Natality query parameters:**
  - Live births
  - Same grouping for denominator
- **Note:** Linked Birth/Infant Death files needed for pregnancy-
  associated death (broader def) — separate WONDER subsystem

**Script:** `scripts/01_pull_wonder.R` will issue API queries per
(year × stratifier-cross) and reshape into long panel.

### 2. CDC PMSS aggregate SMM rates

- **URL:** https://www.cdc.gov/reproductive-health/maternal-infant-health/severe-maternal-morbidity.html
- **Access:** Public PDF tables + HTML; national rates by year
- **Granularity:** National-year only (sub-state SMM requires NIS or
  state SID — paywalled, deferred)
- **Use:** Sanity overlay; not used for shock-amplification headline

**Script:** Hand-transcribe from CDC publications into a small CSV
when we get there. Tiny effort.

### 3. Guttmacher Institute Policy Database

- **URL:** https://data.guttmacher.org/ + https://states.guttmacher.org/policies/
- **Access:** Public Data Center; CSV export requires building a query
  in the web UI (no API)
- **Historical coverage:** state-by-month abortion policy variables
  2017–2022 available
- **Policy components for the composite (per pre-reg §4):**
  - Gestational limit (weeks)
  - Medicaid funding restriction (Y/N)
  - TRAP law presence (Y/N)
  - Mandatory counseling (Y/N)
  - Waiting period (hours)
  - Parental notification (Y/N)
- **Cross-source verification:** LawAtlas dataset (Temple Law)
  covers Dec 2018 – Nov 2022 with similar policy variables — use
  for triangulation

**User action:** Nate (or me when ready) builds the Guttmacher Data
Center query, exports CSV, saves to
`data/raw/reference/guttmacher_state_policy_2017_2022.csv`.

**Triangulation script:** `scripts/03_build_restriction_panel.R` will
compute the composite + cross-validate against LawAtlas.

### 4. KFF Abortion Policy Tracker

- **URL:** https://www.kff.org/womens-health-policy/dashboard/abortion-in-the-united-states-dashboard/
- **Access:** Public dashboard, downloadable as CSV from KFF
- **What we need:** state-by-state status post-Dobbs (Banned / Severely
  Restricted / Restricted Pre-Viability / Restricted Post-Viability /
  No Restriction) with effective dates
- **Use:** Determines state-specific trigger-law dates for sensitivity
  temporal cut per pre-reg §6

**User action:** Download KFF state-by-state CSV → save to
`data/raw/reference/kff_post_dobbs_status.csv`. Already have
KFF Medicaid expansion file from Study 01 — same vendor.

### 5. Caitlin Myers Abortion Access Distance Dataset

- **URLs:**
  - Author data page: https://cmyers.middcreate.net/data/
  - OSF repository: https://osf.io/8dg7r/
  - Published in: Forecasts for a Post-Roe America (PAM 2024)
- **Access:** County-level travel distances (the variable we need)
  are in the public replication package — no DUA. Facility-level
  data requires DUA for safety reasons; we don't need facility level.
- **Coverage:** 2009 through 2020 in the original paper; check OSF
  for updates through 2021
- **Variable of interest:** `min_distance_miles` (or similar) at the
  county-year level

**User or Claude action:** Download CSV from OSF
`osf.io/8dg7r/files/` → save to
`data/raw/reference/myers_county_distance.csv`.

### 6. USDA ERS Commuting Zone Partition

- **URL:** https://www.ers.usda.gov/data-products/commuting-zones-and-labor-market-areas/
- **Access:** Public CSV download, 2010 vintage (709 commuting zones)
- **What we need:** county FIPS → commuting zone ID crosswalk

**User or Claude action:** Download from USDA ERS → save to
`data/raw/reference/usda_cz_2010_county_crosswalk.csv`. One-time.

---

## Aggregate access table

| Source | Programmatic? | DUA? | Effort to acquire |
|---|---|---|---|
| CDC WONDER MCD + Natality | Yes (API) | No | Script + run |
| CDC WONDER Linked Birth-Death | Yes (API) | No | Script + run |
| CDC PMSS | No | No | Manual transcribe (~10 numbers) |
| Guttmacher Policy DB | Partial (web export) | No | Manual download via web query |
| KFF Post-Dobbs Tracker | Partial (CSV link) | No | Manual download |
| Myers Distance | Yes (OSF download) | No | Direct download |
| USDA ERS CZ Crosswalk | Yes (CSV link) | No | Direct download |

**Net:** No DUA-gated source. Manual download for Guttmacher + KFF +
Myers + USDA (4 files). API pulls for WONDER (programmable, automatable).

## Claude action items (parallel, doable now)

1. Build the WONDER API query harness — `scripts/01_pull_wonder.R`
2. Build the restriction-panel construction script (depends on
   Guttmacher + KFF + Myers files landing) — `scripts/03_build_restriction_panel.R`
3. Build the CZ aggregation script — `scripts/04_aggregate_to_cz_state.R`
4. Build the correlation pre-analysis — `scripts/05_restriction_correlation.R`
5. Build the analysis panel assembler — `scripts/06_build_analysis_panel.R`
6. Build the DiD + ITS fitting scripts — `scripts/07a/b_fit_*.R`
7. Build convergence + flag extraction — `scripts/08, 09_*.R`

## Nate action items

Four manual downloads (all public, no fees, no DUA):

1. Guttmacher state-monthly policy timeline 2017–2022 → CSV
2. KFF post-Dobbs status with effective dates → CSV
3. Myers county-year clinic distance → CSV from OSF
4. USDA ERS 2010 commuting zone partition → CSV

Place all four in `data/raw/reference/`. Once they're there, the
restriction-panel build + analysis panel + model fits fire on
sequential script runs.

CDC WONDER pulls are programmatic and will happen automatically once
the harness script lands. Estimated WONDER pull time: minutes (well
within rate limits — CDC WONDER queries are typically <30 seconds per
unique grouping).
