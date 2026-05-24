# Study 03 — Extract headline shock-amplification flags from all fits.
#
# Per PRE_REGISTRATION.md §10 decision rule:
#   Shock-amplification flag fires if BOTH:
#     (1) Posterior 95% CI on δ (post × restriction_z interaction)
#         excludes zero
#     (2) Implied rate-ratio effect at 75th vs 25th percentile of
#         restriction intensity is ≥ 1.10 or ≤ 0.91
#
# Flag tiers (§10):
#   Strong: passes in DiD AND ITS, both restriction measures, both
#           geographic units (where applicable)
#   Conditional: passes in some subset
#   Null: fails one or both rules in primary spec
#
# Also extracts per-race three-way interaction ψ_r per the same rule,
# reported separately per race.
#
# Output:
#   results/headline_flag_table.csv
#   results/race_interaction_flag_table.csv
#   results/disposition_summary.md

user_lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R/win-library/4.6")
.libPaths(c(user_lib, .libPaths()))

library(data.table); library(brms); library(posterior)

repo <- "D:/Women's Health/Study_03_Roe_Fall_Shock"
res <- file.path(repo, "results")

# Distribute restriction-intensity z-scores so the "75th vs 25th
# percentile" comparison is on the original scale. For z-scores, 75th
# percentile ≈ 0.674, 25th ≈ -0.674; difference ≈ 1.35.
Z75_MINUS_Z25 <- 1.35

extract_delta <- function(fit_file, spec_tag, family) {
  fit <- readRDS(fit_file)
  drws <- as_draws_df(fit)

  # The headline coefficient is the post:restriction_z interaction
  delta_col <- grep("^b_post:restriction_z$", names(drws), value = TRUE)
  if (length(delta_col) == 0) {
    cat(sprintf("[WARN] No δ column in %s\n", fit_file))
    return(NULL)
  }
  delta <- drws[[delta_col]]
  delta_summary <- list(
    family = family, spec_tag = spec_tag,
    parameter = "post:restriction_z (headline)",
    mean = mean(delta),
    q025 = quantile(delta, 0.025),
    q975 = quantile(delta, 0.975),
    excludes_null = (quantile(delta, 0.025) > 0) | (quantile(delta, 0.975) < 0),
    # RR at 75th vs 25th percentile = exp(δ × 1.35)
    rr_75_vs_25 = exp(mean(delta) * Z75_MINUS_Z25),
    rr_lower = exp(quantile(delta, 0.025) * Z75_MINUS_Z25),
    rr_upper = exp(quantile(delta, 0.975) * Z75_MINUS_Z25)
  )
  delta_summary$practical_threshold <- (delta_summary$rr_75_vs_25 >= 1.10) |
                                        (delta_summary$rr_75_vs_25 <= 0.91)
  delta_summary$passes_decision_rule <- delta_summary$excludes_null &
                                         delta_summary$practical_threshold
  delta_summary
}

extract_race_interactions <- function(fit_file, spec_tag, family) {
  fit <- readRDS(fit_file)
  drws <- as_draws_df(fit)

  # Race × post × restriction three-way interactions:
  # Look for columns matching pattern b_post:restriction_z:race*
  three_way_cols <- grep("^b_post:restriction_z:race", names(drws), value = TRUE)
  if (length(three_way_cols) == 0) return(NULL)
  rows <- list()
  for (col in three_way_cols) {
    race_level <- sub("^b_post:restriction_z:race", "", col)
    psi <- drws[[col]]
    rows[[length(rows) + 1L]] <- data.table(
      family = family, spec_tag = spec_tag,
      race_level = race_level,
      mean = mean(psi),
      q025 = quantile(psi, 0.025),
      q975 = quantile(psi, 0.975),
      excludes_null = (quantile(psi, 0.025) > 0) | (quantile(psi, 0.975) < 0),
      rr_75_vs_25 = exp(mean(psi) * Z75_MINUS_Z25),
      rr_lower = exp(quantile(psi, 0.025) * Z75_MINUS_Z25),
      rr_upper = exp(quantile(psi, 0.975) * Z75_MINUS_Z25)
    )
  }
  rbindlist(rows)
}

# --- Iterate over all fits ------------------------------------------
delta_rows <- list()
race_rows <- list()

for (family in c("family_did", "family_its")) {
  fit_root <- file.path(repo, "results", family)
  if (!dir.exists(fit_root)) next
  spec_dirs <- list.dirs(fit_root, recursive = FALSE)
  for (sd in spec_dirs) {
    spec_tag <- basename(sd)
    ff <- file.path(sd, "fit.rds")
    if (!file.exists(ff)) next
    cat(sprintf("[%s/%s] extracting flags\n", family, spec_tag))
    d <- extract_delta(ff, spec_tag, family)
    if (!is.null(d)) delta_rows[[length(delta_rows) + 1L]] <- as.data.table(d)
    r <- extract_race_interactions(ff, spec_tag, family)
    if (!is.null(r)) race_rows[[length(race_rows) + 1L]] <- r
    r$practical_threshold <- (r$rr_75_vs_25 >= 1.10) | (r$rr_75_vs_25 <= 0.91)
    r$passes_decision_rule <- r$excludes_null & r$practical_threshold
  }
}

delta_dt <- rbindlist(delta_rows, fill = TRUE)
race_dt <- rbindlist(race_rows, fill = TRUE)

fwrite(delta_dt, file.path(res, "headline_flag_table.csv"))
fwrite(race_dt,  file.path(res, "race_interaction_flag_table.csv"))

# --- Tier the headline flags ----------------------------------------
# Strong = passes DiD AND ITS for both restrictions and both geos (where applicable)
# Conditional = passes in some subset
# Null = primary spec (family_did, guttmacher, cz, sharp_dobbs for mortality)
#        fails

if (nrow(delta_dt) > 0) {
  delta_dt[, c("outcome", "restriction", "geo", "temporal") := tstrsplit(spec_tag, "_")]
  by_outcome <- delta_dt[, .(
    n_pass = sum(passes_decision_rule, na.rm = TRUE),
    n_total = .N
  ), by = outcome]
  by_outcome[, tier := fcase(
    n_pass == n_total, "Strong",
    n_pass >= 1, "Conditional",
    default = "Null"
  )]
  cat("\n=== Headline flag tier per outcome ===\n")
  print(by_outcome)
  fwrite(by_outcome, file.path(res, "headline_flag_tiers.csv"))
}

cat("\n=== Race-interaction flags ===\n")
if (nrow(race_dt) > 0) {
  print(race_dt[passes_decision_rule == TRUE,
                .(family, spec_tag, race_level, rr_75_vs_25, rr_lower, rr_upper)])
} else {
  cat("(no race-interaction terms extracted yet)\n")
}

cat("\nAll flag tables saved to results/. Per pre-reg §13: reported regardless\n",
    "of direction; no selective omission.\n", sep = "")
