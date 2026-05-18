# HCUP NIS Access Scope — Study 01

**Scoped: 2026-05-18**

## Access process (verified from HCUP-US documentation)

1. **Register at HCUP-US** (free): https://hcup-us.ahrq.gov/
2. **Complete the HCUP Data Use Agreement Training Course** (online,
   self-paced; duration not officially published — typical is 1–2 hours).
   Get certification code.
3. **Sign and submit Data Use Agreement (DUA)** to AHRQ via the
   nationwide application kit. Turnaround time not publicly documented;
   anecdotally 1–4 weeks.
4. **Purchase data via CDORS** (Central Distributor Online Reporting
   System): https://cdors.ahrq.gov/databases — pricing only visible
   after login. Participating data organizations set price; reduced
   non-profit/academic/student pricing available.

## What we know about data availability

- **NIS years available:** 1988 through 2023 (per HCUP FAQ).
  Our pre-reg requires 2017–2021 — confirmed available.
- **Data level:** Microdata (patient-discharge level), not aggregated.
- **Delivery formats:** SAS, ASCII, and CSV available.
- **Identifiers:** Patients and hospitals are de-identified. Hospital
  characteristics (bed size, urban-rural, teaching, region, ownership,
  state) are preserved as variables.
- **Privacy:** Small-cell suppression in some derived files; full
  microdata access via the Central Distributor.

## Methodology check: state-level random effect on NIS

**Resolved.** AHRQ's Methods Series Report #2007-01 explicitly supports
hierarchical/multilevel modeling on NIS (Dowell et al. 2004 published
example). The "NIS not for state-level estimates" warning refers to
producing state-specific point estimates and rates as the primary
inference target — which we do NOT do. Our Family 1 model uses state as
a random-intercept to absorb unobserved state-level heterogeneity while
the primary inference targets are race, insurance, parity, hospital-
class, age, comorbidity, and Medicaid-expansion coefficients at the
national level. This is the AHRQ-supported use case.

No pre-reg deviation needed. The model specification in
PRE_REGISTRATION.md §5 stands.

## Costs and timeline (estimated)

| item | range |
|---|---|
| NIS per-year purchase, non-profit pricing | likely $200–$800 per year (anecdotal; verify in CDORS post-registration) |
| Five years (2017–2021) total | likely $1,000–$4,000 |
| DUA training course time | 1–2 hours |
| DUA approval turnaround | 1–4 weeks |
| Data delivery after purchase | days (digital download) |

**Actual numbers verifiable only after HCUP-US registration + DUA
training completion.**

## User action items (Nate)

To unlock data acquisition, Nate needs to:

1. Register at https://hcup-us.ahrq.gov/ (5 min)
2. Complete HCUP DUA training course (1–2 hr)
3. Sign nationwide-data DUA via the application kit
4. Wait for DUA approval (1–4 wk)
5. Log into CDORS and purchase NIS 2017, 2018, 2019, 2020, 2021
6. Receive microdata files; place in `data/raw/nis_YYYY/`

## Claude action items (parallel, no waiting)

While DUA processes, Claude builds the harness so the moment files
land, the pipeline fires:

- `scripts/01_define_population.R` — delivery-hospitalization
  identification (DRG + ICD-10-PCS), reusable per year
- `scripts/02_code_smm_indicators.R` — CDC 21-indicator coding
- `scripts/03_harmonize_stratifiers.R` — parity, age binning,
  comorbidity flags, insurance categories
- `scripts/04_build_holdout_split.R` — 80/20 stratified split
- `scripts/05a/b/c_fit_family*.R` — three model families
- `scripts/06_convergence.R`, `07_holdout_eval.R`

Reference data needed but NOT gated by HCUP DUA:

- CDC SMM 21-indicator ICD-10 code list (public PDF, can vendor today)
- State Medicaid expansion table (KFF, public, can vendor today)
- CDC NCHS urban-rural classification scheme (public)

These get downloaded to `data/raw/reference/` and committed as
audit artifacts.

## Open question for Nate

Whether to scope **State Inpatient Databases (SID)** as an upgrade
path. SID gives state-representative inference (each state file is
representative of THAT state), at much higher cost and per-state DUA
work. v1 pre-reg sticks with NIS; SID is a v2 candidate if Family 1
flags converge on geographic interaction structure that NIS's national-
random-effect can't disentangle.
