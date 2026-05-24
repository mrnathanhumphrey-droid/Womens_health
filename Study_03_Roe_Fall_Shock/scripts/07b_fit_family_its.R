# Study 03 — Family B: Bayesian Hierarchical Interrupted Time Series.
# SENSITIVITY methodology per PRE_REGISTRATION.md §9.
#
# Identical to Family A (07a) except: year fixed-effect is replaced with a
# flexible time function (B-spline with knots at year boundaries) to test
# whether the headline interaction δ is robust to time-trend specification.
#
# Usage:
#   Rscript scripts/07b_fit_family_its.R <outcome> <restriction> <geo> <temporal>
#
# Output:
#   results/family_its/<outcome>_<restriction>_<geo>_<temporal>/fit.rds
#   results/family_its/<outcome>_<restriction>_<geo>_<temporal>/summary.csv

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 4) stop("Usage: 07b_fit_family_its.R <outcome> <restriction> <geo> <temporal>")
outcome     <- args[[1]]
restriction <- args[[2]]
geo         <- args[[3]]
temporal    <- args[[4]]

stopifnot(outcome     %in% c("mortality", "pad", "smm_overlay"))
stopifnot(restriction %in% c("guttmacher", "myers"))
stopifnot(geo         %in% c("cz", "state"))
stopifnot(temporal    %in% c("sharp_dobbs", "state_trigger"))

if (outcome == "pad" && geo == "cz") {
  stop("PAD outcome is state-only per pre-reg §3 — skip cz")
}

user_lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R/win-library/4.6")
.libPaths(c(user_lib, .libPaths()))

library(data.table); library(brms); library(posterior); library(splines)

repo <- "D:/Women's Health/Study_03_Roe_Fall_Shock"
deriv <- file.path(repo, "data/derived")

if (outcome == "pad") {
  panel <- readRDS(file.path(deriv, "analysis_panel_pad_state.rds"))
} else {
  panel <- readRDS(file.path(deriv, sprintf("analysis_panel_%s.rds", geo)))
}

restriction_col <- if (restriction == "guttmacher") "guttmacher_composite_predobbs"
                                                   else "myers_distance_predobbs"
post_col <- if (temporal == "sharp_dobbs") "post_dobbs_sharp"
                                          else "post_dobbs_state_trigger"
unit_col <- if (geo == "cz") "cz_2010" else "state_abbr"

panel <- panel[!is.na(get(restriction_col))]
panel[, restriction_z := scale(get(restriction_col))[, 1]]
panel[, post := as.integer(get(post_col))]
# Continuous time variable for spline
panel[, year_continuous := year - min(year)]

cat(sprintf("[ITS %s/%s/%s/%s] n=%d cells\n",
            outcome, restriction, geo, temporal, nrow(panel)))

# Replace year FE with B-spline trend (4-knot spline)
formula_str <- sprintf(
  "deaths | rate(births) ~ post * restriction_z * race + age_group + bs(year_continuous, df = 4) + (1 | %s)",
  unit_col)
cat("Formula: ", formula_str, "\n", sep = "")

priors_its <- c(
  prior(normal(0, 2.5), class = "b"),
  prior(normal(0, 2.5), class = "Intercept"),
  prior(cauchy(0, 1),   class = "sd")
)

cat(sprintf("[%s] brms ITS NegBin fit\n", format(Sys.time())))
t0 <- Sys.time()
fit <- brm(
  formula = as.formula(formula_str),
  data    = panel,
  family  = negbinomial(),
  prior   = priors_its,
  chains  = 4, iter = 4000, warmup = 2000,
  cores   = 4,
  control = list(adapt_delta = 0.95, max_treedepth = 12),
  refresh = 200,
  seed    = 20260525L,
  silent  = 1
)
t1 <- Sys.time()
cat(sprintf("[%s] Done in %.1f min\n", format(t1),
            as.numeric(difftime(t1, t0, units = "mins"))))

spec_tag <- sprintf("%s_%s_%s_%s", outcome, restriction, geo, temporal)
out_dir <- file.path(repo, "results/family_its", spec_tag)
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
saveRDS(fit, file.path(out_dir, "fit.rds"))

sm <- as.data.frame(summary(fit)$fixed)
sm$param <- rownames(sm)
sm$outcome <- outcome
sm$restriction <- restriction
sm$geo <- geo
sm$temporal <- temporal
write.csv(sm, file.path(out_dir, "summary.csv"), row.names = FALSE)
cat(sprintf("Saved ITS fit + summary to %s\n", out_dir))
