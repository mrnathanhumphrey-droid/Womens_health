# Study 03 — Family A: Bayesian Difference-in-Differences with continuous
# treatment intensity. PRIMARY methodology per PRE_REGISTRATION.md §9.
#
# Per (outcome, restriction-measure, geo-unit, temporal-cut) combination =
# one model fit. 2 × 2 × 2 × 2 = 16 fits for maternal mortality;
# 2 × 1 × 2 × 1 = 4 fits for pregnancy-associated death (state-only, sharp
# Dobbs only since PAD doesn't carry the trigger-date variation cleanly).
#
# Usage:
#   Rscript scripts/07a_fit_family_did.R <outcome> <restriction> <geo> <temporal>
#     outcome:     "mortality" | "pad" | "smm_overlay"
#     restriction: "guttmacher" | "myers"
#     geo:         "cz" | "state"
#     temporal:    "sharp_dobbs" | "state_trigger"
#
# Output:
#   results/family_did/<outcome>_<restriction>_<geo>_<temporal>/fit.rds
#   results/family_did/<outcome>_<restriction>_<geo>_<temporal>/summary.csv

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 4) stop("Usage: 07a_fit_family_did.R <outcome> <restriction> <geo> <temporal>")
outcome     <- args[[1]]
restriction <- args[[2]]
geo         <- args[[3]]
temporal    <- args[[4]]

stopifnot(outcome     %in% c("mortality", "pad", "smm_overlay"))
stopifnot(restriction %in% c("guttmacher", "myers"))
stopifnot(geo         %in% c("cz", "state"))
stopifnot(temporal    %in% c("sharp_dobbs", "state_trigger"))

# PAD is state-only per pre-reg
if (outcome == "pad" && geo == "cz") {
  stop("PAD outcome is state-only per pre-reg §3 — skip cz combination")
}

user_lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R/win-library/4.6")
.libPaths(c(user_lib, .libPaths()))
options(repos = c(CRAN = "https://cloud.r-project.org"))

for (pkg in c("data.table", "brms", "posterior")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg, lib = user_lib)
}
library(data.table); library(brms); library(posterior)

repo <- "D:/Women's Health/Study_03_Roe_Fall_Shock"
deriv <- file.path(repo, "data/derived")

# --- Load analysis panel for this geo --------------------------------
if (outcome == "pad") {
  panel <- readRDS(file.path(deriv, "analysis_panel_pad_state.rds"))
} else {
  panel <- readRDS(file.path(deriv, sprintf("analysis_panel_%s.rds", geo)))
}

# Resolve column names per parameter choices
restriction_col <- if (restriction == "guttmacher") "guttmacher_composite_predobbs"
                                                   else "myers_distance_predobbs"
post_col        <- if (temporal == "sharp_dobbs") "post_dobbs_sharp"
                                                  else "post_dobbs_state_trigger"
unit_col        <- if (geo == "cz") "cz_2010" else "state_abbr"

# Drop rows missing the restriction measure (e.g., CZs not in Myers coverage)
panel <- panel[!is.na(get(restriction_col))]

# Standardize restriction intensity to z-scores for interpretable interaction
panel[, restriction_z := scale(get(restriction_col))[, 1]]
panel[, post := as.integer(get(post_col))]

cat(sprintf("[%s/%s/%s/%s] n=%d unit-year-race-age cells\n",
            outcome, restriction, geo, temporal, nrow(panel)))

# --- Formula -----------------------------------------------------------
# deaths ~ NegBin(λ × births), log(λ) = α_c + γ_t + η_r + θ_age +
#          β_post × post + δ × post × restriction_z +
#          ψ_r × post × restriction_z
formula_str <- sprintf(
  "deaths | rate(births) ~ post * restriction_z * race + age_group + factor(year) + (1 | %s)",
  unit_col)

cat("Formula: ", formula_str, "\n", sep = "")

# --- Priors per pre-reg §9 --------------------------------------------
priors_did <- c(
  prior(normal(0, 2.5), class = "b"),
  prior(normal(0, 2.5), class = "Intercept"),
  prior(cauchy(0, 1),   class = "sd")
)

# --- Fit ---------------------------------------------------------------
cat(sprintf("[%s] brms NegBin fit (4 chains × 4k iter)\n", format(Sys.time())))
t0 <- Sys.time()
fit <- brm(
  formula  = as.formula(formula_str),
  data     = panel,
  family   = negbinomial(),
  prior    = priors_did,
  chains   = 4, iter = 4000, warmup = 2000,
  cores    = 4,
  control  = list(adapt_delta = 0.95, max_treedepth = 12),
  refresh  = 200,
  seed     = 20260524L,
  silent   = 1
)
t1 <- Sys.time()
cat(sprintf("[%s] Done in %.1f min\n", format(t1),
            as.numeric(difftime(t1, t0, units = "mins"))))

# --- Save -------------------------------------------------------------
spec_tag <- sprintf("%s_%s_%s_%s", outcome, restriction, geo, temporal)
out_dir <- file.path(repo, "results/family_did", spec_tag)
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
saveRDS(fit, file.path(out_dir, "fit.rds"))

sm <- as.data.frame(summary(fit)$fixed)
sm$param   <- rownames(sm)
sm$outcome <- outcome
sm$restriction <- restriction
sm$geo <- geo
sm$temporal <- temporal
write.csv(sm, file.path(out_dir, "summary.csv"), row.names = FALSE)

cat(sprintf("Saved fit + summary to %s\n", out_dir))
