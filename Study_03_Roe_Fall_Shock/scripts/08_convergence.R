# Study 03 — Convergence diagnostics across all Family A + B fits.
#
# Per PRE_REGISTRATION.md §9: R-hat < 1.01, bulk-ESS > 1000.
# Halt verdicts surfaced; fits exceeding thresholds require retune
# before reporting.
#
# Output:
#   results/convergence_summary.csv

user_lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R/win-library/4.6")
.libPaths(c(user_lib, .libPaths()))

library(data.table); library(brms); library(posterior)

repo <- "D:/Women's Health/Study_03_Roe_Fall_Shock"
RHAT_HALT <- 1.01
ESS_FLOOR <- 1000

rows <- list()
for (family in c("family_did", "family_its")) {
  fit_root <- file.path(repo, "results", family)
  if (!dir.exists(fit_root)) next
  spec_dirs <- list.dirs(fit_root, recursive = FALSE)
  for (sd in spec_dirs) {
    spec_tag <- basename(sd)
    ff <- file.path(sd, "fit.rds")
    if (!file.exists(ff)) next
    cat(sprintf("[%s/%s] loading\n", family, spec_tag))
    fit <- readRDS(ff)
    drws <- as_draws_array(fit)
    sm <- summarise_draws(drws, "rhat", "ess_bulk", "ess_tail")
    max_rhat <- max(sm$rhat, na.rm = TRUE)
    min_ess_bulk <- min(sm$ess_bulk, na.rm = TRUE)
    min_ess_tail <- min(sm$ess_tail, na.rm = TRUE)
    n_above_halt <- sum(sm$rhat > RHAT_HALT, na.rm = TRUE)
    verdict <- if (max_rhat <= RHAT_HALT && min_ess_bulk >= ESS_FLOOR) {
      "PASS"
    } else if (max_rhat > RHAT_HALT) {
      "HALT_RHAT"
    } else {
      "HALT_ESS"
    }
    rows[[length(rows) + 1L]] <- data.table(
      family = family, spec_tag = spec_tag,
      max_rhat = max_rhat,
      min_ess_bulk = min_ess_bulk,
      min_ess_tail = min_ess_tail,
      n_params_above_halt = n_above_halt,
      verdict = verdict
    )
    cat(sprintf("  R-hat: %.4f, bulk-ESS: %.0f, tail-ESS: %.0f → %s\n",
                max_rhat, min_ess_bulk, min_ess_tail, verdict))
  }
}

summary_dt <- rbindlist(rows)
fwrite(summary_dt, file.path(repo, "results/convergence_summary.csv"))

cat("\n=== Convergence summary ===\n")
print(summary_dt)
n_pass <- sum(summary_dt$verdict == "PASS")
cat(sprintf("\nPASS %d / %d (%.0f%%)\n",
            n_pass, nrow(summary_dt), 100 * n_pass / nrow(summary_dt)))
if (n_pass < nrow(summary_dt)) {
  cat("\nHALT fits (retune required before reporting):\n")
  print(summary_dt[verdict != "PASS"])
}
