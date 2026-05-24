# Study 03 — Pre-Registration Deviations

Living log of methodology deviations from the locked PRE_REGISTRATION.md
(committed at SHA `62e1e87`). Each entry documents the deviation, when
it was discovered, why it was necessary, and how it was handled.

---

## Entry 001 — Swap state-policy source from Guttmacher to LawAtlas

**Discovered:** 2026-05-24, during data-acquisition planning (link
hunt for the four manual-download reference files).

**Original pre-reg specification (§2, §4):** Guttmacher Institute Policy
Database as primary state-by-month policy source for the
`guttmacher_composite_predobbs` restriction-intensity variable, with
LawAtlas referenced only as a triangulation cross-check.

**Deviation:** Swap primary and triangulation. **LawAtlas State
Abortion Laws dataset becomes the primary state-policy source.**
Guttmacher Data Center retained as optional cross-check where coverage
overlaps.

**Rationale (access-driven, not result-driven):**

The Guttmacher Data Center (https://data.guttmacher.org/) hosts the
relevant policy variables but only as an interactive query builder
with no clean cross-section CSV export for the 2017–2022 panel we need.
Guttmacher's public-use datasets page lists only the
"Pregnancies, Births and Abortions" incidence dataset — not the
state-by-month policy variables.

LawAtlas (https://lawatlas.org/datasets/abortion-laws), a
Temple University Center for Public Health Law Research collaboration
with Guttmacher, covers the same policy variables (gestational limits,
TRAP laws, Medicaid funding, waiting periods, parental notification,
mandatory counseling), spans December 1, 2018 through November 1, 2022,
and provides a direct CSV download.

**Coverage trade:** LawAtlas window starts Dec 2018 vs Guttmacher
nominally 2017. Loss = ~2 years of pre-Dobbs baseline. Per pre-reg
§7, our pre-Dobbs window was Jan 2017 through June 2022 (5.5 years);
under LawAtlas-primary, it narrows to Dec 2018 through June 2022
(3.5 years). Still adequate for unit fixed effects to absorb
time-invariant heterogeneity; reduces but does not eliminate the
pre-Dobbs trajectory length.

**Pre-reg constraints touched:**
- §2 Substrate table: Guttmacher row demoted to "optional cross-check
  where coverage overlaps"; LawAtlas row promoted to primary
- §4 Treatment intensity: variable name changes from
  `guttmacher_composite_predobbs` to `lawatlas_composite_predobbs`;
  component policy variables stay the same; composite construction
  formula unchanged
- §7 Time window: pre-Dobbs baseline narrows to Dec 2018 – June 2022
  (3.5 years) due to LawAtlas coverage start
- §11 step 3: "build restriction panel" step reads LawAtlas CSV
  instead of Guttmacher

**Decision rule, methodology family choices, geographic units, outcomes,
race interactions, decision tiering — all unchanged.**

**Audit:** This swap is principled (access-driven, not result-driven).
No data has been pulled yet; no model has been fit. The new lock at
this commit supersedes Guttmacher-as-primary. Future analyses cite
both the original pre-reg SHA `62e1e87` AND this deviation entry as
the methodological anchor.

**Code update:**
- `scripts/03_build_restriction_panel.R` updated to read LawAtlas CSV
  with column names per LawAtlas codebook; composite construction
  retained
- `scripts/00_data_access_scope.md` updated to reflect LawAtlas as
  primary download target
- Expected file path:
  `data/raw/reference/lawatlas_abortion_laws_2018_2022.csv`

**⚠️ SUPERSEDED BY ENTRY 002 BELOW (2026-05-24).** LawAtlas dataset
also turned out to be publicly unobtainable in the form required for
the analysis. Entry 002 pivots the treatment-intensity operationalization
entirely.

---

## Entry 002 — Pivot treatment intensity to public-snapshot ban category

**Discovered:** 2026-05-24, during data-acquisition for Entry 001's
LawAtlas swap.

**Context:** Entry 001 swapped the primary state-policy source from
Guttmacher to LawAtlas because Guttmacher's longitudinal panel sat
behind an interactive query builder with no clean CSV export.
On attempted LawAtlas acquisition, we found:
- LawAtlas distributes the *research protocol PDF* publicly but NOT
  the dataset rows themselves in any browse-and-download form
- Guttmacher's longitudinal panel data is similarly behind paywalled
  or institutional access
- Caitlin Myers' OSF facility-level data is DUA-gated; the public
  county-distance derived file wasn't navigable to the surface
- KFF post-Dobbs tracker is dashboard-only, no CSV export

**Net:** the entire field's longitudinal-policy data for the
2017–2022 window is access-gated. No reasonable public substitute
exists for the LawAtlas continuous policy composite.

**Deviation — pivot the operationalization, not pause:**

Original pre-reg §4 specified treatment intensity as a continuous
composite of pre-existing policy variables (gestational limit,
TRAP density, Medicaid funding, waiting period, parental notification,
mandatory counseling) measured pre-Dobbs.

Pivoted operationalization: treatment intensity is now revealed by
**post-Dobbs ban category** + **time-to-ban implementation**, both
of which ARE publicly observable. The argument: states that
implemented bans post-Dobbs are precisely the ones with pre-existing
infrastructure (trigger laws, state-constitutional amendments,
legislative readiness) to implement them. Ban category at t=Dobbs is
observable evidence of pre-existing infrastructure depth.

**New treatment-intensity variables (replacing original §4):**

| Variable | Levels / units | Public source |
|---|---|---|
| `ban_category` | Total ban / Gestational limit ≤18wk / Gestational limit 19+wk / No restriction (4-level ordinal) | Guttmacher public snapshot (https://www.guttmacher.org/node/300496/printable/print) |
| `time_to_ban_days` | Days from Dobbs (2022-06-24) to state's first abortion-restriction effective date; 99999 if no restriction implemented | KFF + Guttmacher news coverage (hand-coded from public records) |
| `myers_distance_predobbs` | County-level clinic distance, pre-Dobbs vintage | OPTIONAL: include if Myers OSF file can be obtained |

**Identification trade:** the pivot weakens identification slightly.
Original design used pre-Dobbs measures (clean temporal separation
between treatment-intensity measurement and outcome window). Pivoted
design uses post-Dobbs revealed-preference indicators that are
arguably correlated with pre-Dobbs infrastructure but conceptually
contemporaneous with the outcome. The argument relies on the claim
that legislative/judicial ban-implementation capacity is a real
feature of state political infrastructure that existed before Dobbs
and revealed itself after. Reasonable but weaker than the original
LawAtlas-based design.

**This is a substantial pre-reg amendment — almost a different paper.**
Reporting transparently per pre-reg discipline.

**Pre-reg constraints touched:**
- §2 Substrate: LawAtlas row demoted to "unavailable"; Guttmacher
  snapshot row promoted to primary
- §4 Treatment intensity: full rewrite per table above
- §11 Execution sequence: data-acquisition step simplified (no
  state-monthly policy panel needed; just snapshot + effective dates)
- §15 Position relative to corpus: weakened identification noted

**Decision rule, methodology families (DiD + ITS), geographic units
(CZ + state), outcomes (mortality + PAD + SMM-overlay), race
interactions, decision tiering, pro-women framing — all unchanged.**

**Code update:**
- `scripts/03_build_restriction_panel.R` rewritten for the simpler
  snapshot-based panel construction
- `data/raw/reference/guttmacher_ban_status_snapshot_2026_04.csv`
  vendored from the public printable page

**Status after Entry 002:** Study 03 can fire. CDC WONDER + Guttmacher
snapshot + USDA CZ are all in hand or acquirable today. Myers distance
remains an optional enhancement.
