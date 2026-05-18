# Study 01 — Convergence diagnostics across all Family 1 + Family 2 fits.
#
# Per PRE_REGISTRATION.md §5: all reported parameters must have
# R-hat < 1.01 AND bulk-ESS > 1000.
#
# Output:
#   results/convergence_summary.csv  — one row per (family, contrast, outcome,
#                                       max_rhat, min_ess_bulk, min_ess_tail,
#                                       n_params_above_halt, verdict)

user_lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R/win-library/4.6")
.libPaths(c(user_lib, .libPaths()))

for (pkg in c("data.table", "brms", "posterior")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg, lib = user_lib)
}
library(data.table)
library(brms)
library(posterior)

repo <- "D:/Women's Health/Study_01_Maternal_Mortality"
RHAT_HALT <- 1.01
ESS_FLOOR <- 1000

rows <- list()
for (family in c("family1", "family2")) {
  for (contrast in c("y2021", "rolling_2017_2021", "prepan_vs_pan")) {
    fit_dir <- file.path(repo, "results", family, contrast)
    if (!dir.exists(fit_dir)) next
    fit_files <- list.files(fit_dir, pattern = "^fit_.*\\.rds$",
                            full.names = TRUE)
    for (ff in fit_files) {
      outcome <- sub("^fit_", "", sub("\\.rds$", "", basename(ff)))
      cat(sprintf("[%s/%s/%s] loading\n", family, contrast, outcome))
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
        family = family,
        contrast = contrast,
        outcome = outcome,
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
}

summary_dt <- rbindlist(rows)
out_path <- file.path(repo, "results/convergence_summary.csv")
fwrite(summary_dt, out_path)

cat("\n=== Convergence summary ===\n")
print(summary_dt)

n_pass <- sum(summary_dt$verdict == "PASS")
n_halt <- sum(summary_dt$verdict != "PASS")
cat(sprintf("\nPASS: %d / %d (%.0f%%); HALT: %d\n",
            n_pass, nrow(summary_dt), 100 * n_pass / nrow(summary_dt), n_halt))

if (n_halt > 0) {
  cat("\nHALT fits (require retune before reporting):\n")
  print(summary_dt[verdict != "PASS"])
}
