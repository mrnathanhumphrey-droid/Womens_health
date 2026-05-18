# Women's Health Research

Bayesian methodology applied to fields where women's-health questions
have thin Bayesian literature AND public data — closing the gap between
rigorous uncertainty propagation and accessible-data questions that
actually move the field.

**Motivation:** Help women. Not topic-passion-driven; gap-driven. Each
study under this directory targets a field where (a) the question is
underexplored with proper Bayesian uncertainty, (b) data is publicly
accessible, and (c) the residue-class / decomposable structure suits
hierarchical modeling.

---

## Studies in this corpus

| # | Study | Status | Substrate | Outcomes / question |
|---|---|---|---|---|
| 01 | [Maternal Mortality](Study_01_Maternal_Mortality/) | Active — framing | CDC WONDER + HCUP NIS (public) | Maternal mortality / severe maternal morbidity, decomposed by race × geography × insurance |
| 02 | [PCOS Phenotype Heterogeneity](Study_02_PCOS_Phenotypes/) | Queued | NHANES + All of Us | Latent-class phenotype structure within Rotterdam-criteria PCOS, with uncertainty propagated |

Additional studies will be added as Wilson (the research-scout role)
identifies field gaps and Claude Code drafts pre-registrations.

---

## Convention

Each study lives in `Study_NN_<short_name>/` with the following
structure:

```
Study_NN_<short_name>/
├── README.md                 ← study-specific framing, status, decisions
├── PRE_REGISTRATION.md       ← locked design (post-lock changes go to DEVIATIONS)
├── DEVIATIONS.md             ← deviation log
├── data/                     ← raw + harmonized
├── reference/                ← locked artifacts (cohort list, splits, target covs)
├── scripts/                  ← runners
├── results/                  ← outputs
└── logs/                     ← per-step run logs
```

The same methodological discipline applies across every study:
pre-registration locked at a commit SHA before any compute fires, held-out
validation with frozen split indices, deviations logged with rationale,
no selective reporting, no post-hoc methodology pivots.

---

## Position relative to other research

Methodology lessons accumulated:
- [FkCancer corpus](https://github.com/mrnathanhumphrey-droid/CancerResearch) —
  Lock 2022 structural-prior validation + substrate tests. Paper 5
  surfaced the held-out projection-scale issue that informs how we
  handle out-of-sample evaluation here.
- [Cisplatin Study](https://github.com/mrnathanhumphrey-droid/Cisplatin_Study) —
  Patient-survivor-led predictive flags. Paused awaiting data access
  but pre-reg pattern transfers directly.

What carries: pre-reg-as-SHA, deviation logging, hedged READMEs when
uncertainty is real, no claim publishable without held-out + sensitivity
diagnostics.
