# Study 02 — PCOS Phenotype Heterogeneity

**Status (2026-05-18):** Queued. Will activate after Study 01 (Maternal
Mortality) lands a verdict or hits a stable pause point.

## Question

Polycystic Ovary Syndrome (PCOS) is diagnosed by the Rotterdam criteria,
which define four explicit phenotypes based on three diagnostic axes
(hyperandrogenism, ovulatory dysfunction, polycystic ovarian morphology).
Existing latent-class work suggests substructure within these four
phenotypes — meaningfully different biological profiles share a single
diagnostic label.

This study asks: **using Bayesian latent-class / mixture modeling with
proper uncertainty propagation, what substructure exists within the
Rotterdam-criteria PCOS phenotypes? Do the latent classes correspond
to distinguishable hormonal / metabolic / inflammatory profiles that
predict differential clinical course?**

## Why this study

- **Rotterdam phenotypes A–D are clinical conveniences, not
  biological clusters.** Within each phenotype, patients differ
  substantially in insulin resistance, lipid profile, androgen
  trajectory.
- **Bayesian latent-class work exists but uncertainty propagation
  is weak.** Most published latent-class PCOS studies report point
  estimates without proper credible intervals on class membership.
- **NHANES has the relevant biomarker panel** — free testosterone,
  SHBG, insulin, glucose, lipids, BMI — for women of reproductive age,
  public access, no DUA.
- **Methodology fits Bayesian mixture / Dirichlet-process clustering
  directly.** Uncertainty in class assignment propagates to clinical
  interpretation.

## Substrate

- **NHANES (NCHS / CDC)** — public, immediate access. Reproductive-age
  women cycles with relevant hormones (limited by which cycles
  measured what).
- **All of Us (NIH)** — registration required, broader biomarker +
  EHR coverage if NHANES is insufficient for the panel.

## Open framing decisions (NOT locked; activation pending Study 01)

1. NHANES cycles to pool (depends on biomarker availability per cycle)
2. PCOS case definition without explicit ICD coding — biomarker-based
   surrogate vs self-report
3. Latent-class model class number selection — fixed K vs DP-style
   nonparametric
4. Uncertainty propagation target — class membership posterior?
   Per-cluster characteristic posterior?
5. Decision rule for "clinically meaningful substructure" — beyond
   model selection criteria, what threshold for actionable
   subgroup difference?

Will activate when Study 01 reaches a stable point.

## Position

Second in the [women's health corpus](../). Lower clinical-impact scale
than Study 01 (maternal mortality) but higher methodological novelty;
the field gap on proper Bayesian latent-class with full uncertainty
propagation is genuine.
