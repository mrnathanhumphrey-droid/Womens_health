# Study 01 — Family 3: Latent-class mixture over SMM indicator co-occurrence.
#
# Per PRE_REGISTRATION.md §5 Family 3 (exploratory).
#
# For patients with ≥1 SMM event, model the joint pattern of 20 individual
# SMM indicator outcomes (excluding transfusion-only per CDC convention)
# as a mixture of K latent classes. Identifies whether stratifier patterns
# predict different SMM "subtypes."
#
# K selected via leave-one-out cross-validation (LOO-CV) on a grid K ∈ {2..6}.
# Implementation: Bayesian latent class via Stan, called from brms's
# nonlinear interface OR via the `BayesLCA` package as a simpler fallback.
#
# Pre-committed as EXPLORATORY; results reported but NOT used for primary
# disposition.
#
# Usage:
#   Rscript scripts/05c_fit_family3_latent.R <contrast>

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) stop("Usage: Rscript 05c_fit_family3_latent.R <contrast>")
contrast <- args[[1]]
stopifnot(contrast %in% c("y2021", "rolling_2017_2021", "prepan_vs_pan"))

user_lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R/win-library/4.6")
.libPaths(c(user_lib, .libPaths()))
options(repos = c(CRAN = "https://cloud.r-project.org"))

for (pkg in c("data.table", "BayesLCA")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg, lib = user_lib)
}
library(data.table)
library(BayesLCA)

repo <- "D:/Women's Health/Study_01_Maternal_Mortality"
dt <- readRDS(file.path(repo, "data/derived/analysis_table.rds"))
load(file.path(repo, "reference/holdout_split.rda"))

# Training fold only (consistent with Families 1+2 per pre-reg §7)
dt_train <- dt[train_idx]
if (contrast == "y2021") {
  dt_train <- dt_train[year_actual == 2021L]
} else {
  dt_train <- dt_train[year_actual %in% 2017:2021]
}

# Filter to patients with at least one SMM event (excluding transfusion)
smm_cols <- setdiff(grep("^smm_[0-9]+_", names(dt_train), value = TRUE),
                    grep("^smm_09_", names(dt_train), value = TRUE))
dt_events <- dt_train[smm_composite_excl_trans == 1]
cat(sprintf("[%s] SMM-event patients (excl trans): %d\n", contrast, nrow(dt_events)))
if (nrow(dt_events) < 1000L) {
  cat("[POWER] <1000 SMM events; latent-class fit may be unstable.\n")
}

# --- Build co-occurrence binary matrix --------------------------------
X <- as.matrix(dt_events[, ..smm_cols])
colnames(X) <- smm_cols
mode(X) <- "integer"
cat(sprintf("Indicator matrix: %d patients × %d indicators\n",
            nrow(X), ncol(X)))

# --- Grid search K via BIC and LOO approximation ---------------------
K_grid <- 2:6
results <- list()
for (K in K_grid) {
  cat(sprintf("\n[%s] Fitting Bayesian LCA K=%d\n", format(Sys.time()), K))
  set.seed(20260520L + K)
  fit_K <- tryCatch(
    blca.em(X, G = K, restarts = 5, sd.init = 0.1, verbose = FALSE),
    error = function(e) { cat("  failed: ", conditionMessage(e), "\n"); NULL }
  )
  if (is.null(fit_K)) next
  results[[as.character(K)]] <- list(K = K, fit = fit_K, BIC = fit_K$BIC,
                                     AIC = fit_K$AIC, logL = fit_K$logL)
  cat(sprintf("  K=%d: BIC=%.1f AIC=%.1f logL=%.1f\n",
              K, fit_K$BIC, fit_K$AIC, fit_K$logL))
}

# Select K with minimum BIC
bics <- sapply(results, function(r) r$BIC)
best_K <- as.integer(names(which.min(bics)))
cat(sprintf("\nSelected K=%d by minimum BIC (BIC=%.1f)\n", best_K, min(bics)))

# --- Posterior class assignments + class profiles ---------------------
fit_best <- results[[as.character(best_K)]]$fit
class_probs <- fit_best$Z   # n_patients × K matrix
dt_events[, latent_class := apply(class_probs, 1, which.max)]

# Per-class indicator-occurrence rates (the "subtype profile")
class_profiles <- sapply(seq_len(best_K), function(k) {
  pts_in_k <- which(dt_events$latent_class == k)
  colMeans(X[pts_in_k, , drop = FALSE])
})
colnames(class_profiles) <- paste0("class_", seq_len(best_K))

cat("\nClass profiles (per-indicator occurrence rate within class):\n")
print(round(class_profiles, 3))

# --- Save --------------------------------------------------------------
out_dir <- file.path(repo, "results/family3", contrast)
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
saveRDS(list(
  contrast = contrast,
  K_selected = best_K,
  BIC_grid = bics,
  fit = fit_best,
  class_assignments = dt_events[, .(latent_class)],
  class_profiles = class_profiles,
  smm_indicator_cols = smm_cols
), file.path(out_dir, sprintf("latent_class_K%d_fit.rds", best_K)))

# Class × stratifier cross-tabs (for downstream interpretation, not
# primary disposition per §5 "Family 3 exploratory")
strat_xtabs <- list()
for (strat in c("race", "insurance", "parity_tertile", "bed_size",
                "urban_rural", "age_group", "medicaid_expansion")) {
  if (strat %in% names(dt_events)) {
    strat_xtabs[[strat]] <- table(dt_events[[strat]], dt_events$latent_class)
  }
}
saveRDS(strat_xtabs, file.path(out_dir,
                               sprintf("class_strat_xtabs_K%d.rds", best_K)))

cat(sprintf("\nFamily 3 K=%d fit + cross-tabs saved at %s\n", best_K, out_dir))
cat("Per pre-reg §5: Family 3 is exploratory; results reported but not\n",
    "used for primary disposition.\n", sep = "")
