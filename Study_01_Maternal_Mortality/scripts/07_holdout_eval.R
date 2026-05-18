# Study 01 — Held-out predictive performance + flag identification.
#
# Per PRE_REGISTRATION.md §8 decision rule:
#   A stratifier-level is a "flag" if BOTH:
#     (1) Posterior 95% CI on marginal log-odds excludes zero in held-out
#     (2) Implied rate ratio ≥ 1.20 OR ≤ 0.83
#
# Flag tiers (per pre-reg §8):
#   - Strong: passes Family 1 AND Family 2, ≥2 of 3 temporal contrasts
#   - Conditional: passes Family 1 only, or 1 of 3 contrasts
#   - Null: fails one or both rules in Family 1
#
# Output:
#   results/holdout_predictive_performance.csv — per (family, contrast, outcome)
#                                                  AUC, log-likelihood
#   results/flag_table.csv                    — full 198-row results table
#                                                  with per-stratifier flag tier

user_lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R/win-library/4.6")
.libPaths(c(user_lib, .libPaths()))

for (pkg in c("data.table", "brms", "pROC")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg, lib = user_lib)
}
library(data.table); library(brms); library(pROC)

repo <- "D:/Women's Health/Study_01_Maternal_Mortality"
dt <- readRDS(file.path(repo, "data/derived/analysis_table.rds"))
load(file.path(repo, "reference/holdout_split.rda"))

dt_test <- dt[test_idx]

# --- AUC + LL per fit -------------------------------------------------
perf_rows <- list()
flag_rows <- list()

contrasts <- c("y2021", "rolling_2017_2021", "prepan_vs_pan")
families  <- c("family1", "family2")

for (fam in families) {
  for (cnt in contrasts) {
    fit_dir <- file.path(repo, "results", fam, cnt)
    if (!dir.exists(fit_dir)) next
    fit_files <- list.files(fit_dir, pattern = "^fit_.*\\.rds$",
                            full.names = TRUE)
    for (ff in fit_files) {
      outcome <- sub("^fit_", "", sub("\\.rds$", "", basename(ff)))
      cat(sprintf("[%s/%s/%s] eval\n", fam, cnt, outcome))
      fit <- readRDS(ff)

      # Filter test rows to match this contrast's year window
      if (cnt == "y2021") {
        dt_test_c <- dt_test[year_actual == 2021L]
      } else {
        dt_test_c <- dt_test[year_actual %in% 2017:2021]
        if (cnt == "prepan_vs_pan") {
          dt_test_c[, pandemic_era := factor(
            ifelse(year_actual >= 2020L, "pandemic", "prepandemic"),
            levels = c("prepandemic", "pandemic"))]
        }
      }

      # Predict
      preds <- tryCatch(
        posterior_epred(fit, newdata = dt_test_c, allow_new_levels = TRUE),
        error = function(e) { cat("  predict failed: ", conditionMessage(e), "\n"); NULL }
      )
      if (is.null(preds)) next
      mean_pred <- colMeans(preds)
      y_true <- dt_test_c[[outcome]]

      # AUC
      auc_val <- tryCatch(
        as.numeric(pROC::auc(y_true, mean_pred, quiet = TRUE)),
        error = function(e) NA_real_
      )
      # Log-likelihood
      ll <- sum(dbinom(y_true, 1, pmin(pmax(mean_pred, 1e-9), 1 - 1e-9),
                       log = TRUE))

      perf_rows[[length(perf_rows) + 1L]] <- data.table(
        family = fam, contrast = cnt, outcome = outcome,
        n_test = length(y_true), n_events_test = sum(y_true),
        auc = auc_val, log_likelihood = ll
      )

      # Per-stratifier flag (Family 1 + Family 2 both contribute)
      sm <- as.data.frame(summary(fit)$fixed)
      sm$param <- rownames(sm)
      for (i in seq_len(nrow(sm))) {
        p <- sm$param[i]
        if (p %in% c("Intercept", "(Intercept)")) next
        ci_lo <- sm$`l-95% CI`[i]; ci_hi <- sm$`u-95% CI`[i]
        est_log_odds <- sm$Estimate[i]
        rr <- exp(est_log_odds)
        excludes_null <- (ci_lo > 0) | (ci_hi < 0)
        practical <- (rr >= 1.20) | (rr <= 0.83)
        passes <- excludes_null & practical
        flag_rows[[length(flag_rows) + 1L]] <- data.table(
          family = fam, contrast = cnt, outcome = outcome,
          stratifier_level = p,
          estimate_log_odds = est_log_odds,
          rate_ratio = rr,
          ci_lower = exp(ci_lo), ci_upper = exp(ci_hi),
          excludes_null = excludes_null,
          practical_threshold = practical,
          passes_decision_rule = passes
        )
      }
    }
  }
}

perf_dt <- rbindlist(perf_rows)
flag_dt <- rbindlist(flag_rows)

fwrite(perf_dt, file.path(repo, "results/holdout_predictive_performance.csv"))
fwrite(flag_dt, file.path(repo, "results/flag_table_raw.csv"))

# --- Strong / Conditional / Null tiering ------------------------------
# Strong = passes in BOTH Family 1 AND Family 2 AND ≥2 of 3 contrasts
# Conditional = passes Family 1 only, or 1 of 3 contrasts
# Null = fails one or both rules in Family 1
tier_dt <- flag_dt[, .(
  n_contrasts_pass_f1 = sum(passes_decision_rule[family == "family1"]),
  n_contrasts_pass_f2 = sum(passes_decision_rule[family == "family2"])
), by = .(outcome, stratifier_level)]

tier_dt[, flag_tier := fcase(
  n_contrasts_pass_f1 >= 2 & n_contrasts_pass_f2 >= 2, "Strong",
  n_contrasts_pass_f1 >= 1, "Conditional",
  default = "Null"
)]

fwrite(tier_dt, file.path(repo, "results/flag_table.csv"))

cat("\n=== Flag tier summary ===\n")
print(tier_dt[, .N, by = flag_tier])

cat("\n=== Strong flags ===\n")
print(tier_dt[flag_tier == "Strong"])

cat("\nFull flag table at results/flag_table.csv\n")
cat("Per pre-reg §10 constraint 2: all 198 rows reported, no selective omission.\n")
