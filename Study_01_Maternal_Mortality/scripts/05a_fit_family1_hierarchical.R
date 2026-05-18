# Study 01 — Family 1: Hierarchical Bayesian logistic regression.
#
# Per PRE_REGISTRATION.md §5 Family 1 (primary).
# Fits one model per (outcome × temporal contrast).
# 22 outcomes × 3 contrasts = 66 fits.
#
# Usage:
#   Rscript scripts/05a_fit_family1_hierarchical.R <outcome_col> <contrast>
#     outcome_col: smm_NN_<name> or smm_composite_excl_trans / smm_composite_incl_trans
#     contrast: "y2021" | "rolling_2017_2021" | "prepan_vs_pan"
#
# Output:
#   results/family1/<contrast>/fit_<outcome>.rds   (brms fit object)
#   results/family1/<contrast>/summary_<outcome>.csv (coefficient table)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript 05a_fit_family1_hierarchical.R <outcome_col> <contrast>")
}
outcome_col <- args[[1]]
contrast    <- args[[2]]
stopifnot(contrast %in% c("y2021", "rolling_2017_2021", "prepan_vs_pan"))

user_lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R/win-library/4.6")
.libPaths(c(user_lib, .libPaths()))
options(repos = c(CRAN = "https://cloud.r-project.org"))

for (pkg in c("data.table", "brms", "posterior")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg, lib = user_lib)
}
library(data.table)
library(brms)
library(posterior)

repo <- "D:/Women's Health/Study_01_Maternal_Mortality"
dt <- readRDS(file.path(repo, "data/derived/analysis_table.rds"))
load(file.path(repo, "reference/holdout_split.rda"))

stopifnot(outcome_col %in% names(dt))

# --- Subset to training fold per pre-reg §7 ---------------------------
dt_train <- dt[train_idx]

# --- Apply temporal contrast filter -----------------------------------
if (contrast == "y2021") {
  dt_train <- dt_train[year_actual == 2021L]
  year_term <- NULL   # single year, no year FE
} else if (contrast == "rolling_2017_2021") {
  dt_train <- dt_train[year_actual %in% 2017:2021]
  year_term <- "+ factor(year_actual)"
} else if (contrast == "prepan_vs_pan") {
  # Fit on full 2017-2021 with a pandemic-era indicator
  dt_train <- dt_train[year_actual %in% 2017:2021]
  dt_train[, pandemic_era := factor(
    ifelse(year_actual >= 2020L, "pandemic", "prepandemic"),
    levels = c("prepandemic", "pandemic"))]
  year_term <- "+ pandemic_era"
}

# Power check
n_events <- sum(dt_train[[outcome_col]], na.rm = TRUE)
n_total  <- sum(!is.na(dt_train[[outcome_col]]))
cat(sprintf("[%s/%s] n=%d, events=%d (%.3f%%)\n",
            contrast, outcome_col, n_total, n_events, 100 * n_events / n_total))
if (n_events < 200L) {
  cat("[POWER FLOOR] <200 events. Per pre-reg §3, report descriptive only.\n")
  out_descr <- list(outcome = outcome_col, contrast = contrast,
                    n = n_total, events = n_events,
                    rate = n_events / n_total,
                    note = "Below pre-reg power floor (<200 events). No inference.")
  out_dir <- file.path(repo, "results/family1", contrast)
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  saveRDS(out_descr, file.path(out_dir, sprintf("descriptive_%s.rds", outcome_col)))
  quit(save = "no", status = 0)
}

# --- Build formula ----------------------------------------------------
state_col <- intersect(c("HOSP_STATE", "HOSPST", "hosp_state_clean"), names(dt))[1]
fixed_effects <- c("race", "insurance", "parity_tertile",
                   "bed_size", "urban_rural", "age_group",
                   "chronic_htn", "preexisting_dm", "prior_cesarean",
                   "medicaid_expansion")
formula_str <- sprintf("%s ~ %s %s + (1 | %s)",
  outcome_col,
  paste(fixed_effects, collapse = " + "),
  if (is.null(year_term)) "" else year_term,
  state_col)
cat(sprintf("Formula: %s\n", formula_str))

# --- Priors per pre-reg §5 --------------------------------------------
priors_fam1 <- c(
  prior(normal(0, 2.5), class = "b"),
  prior(normal(0, 2.5), class = "Intercept"),
  prior(cauchy(0, 2.5), class = "sd")
)

# --- Fit --------------------------------------------------------------
cat(sprintf("[%s] Starting brms fit (4 chains x 4k iter)\n", format(Sys.time())))
t0 <- Sys.time()
fit <- brm(
  formula  = as.formula(formula_str),
  data     = dt_train,
  family   = bernoulli(),
  prior    = priors_fam1,
  chains   = 4, iter = 4000, warmup = 2000,
  cores    = 4,
  control  = list(adapt_delta = 0.95, max_treedepth = 12),
  refresh  = 200,
  seed     = 20260518L,
  silent   = 1
)
t1 <- Sys.time()
cat(sprintf("[%s] Done in %.1f min\n", format(t1),
            as.numeric(difftime(t1, t0, units = "mins"))))

# --- Save -------------------------------------------------------------
out_dir <- file.path(repo, "results/family1", contrast)
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
saveRDS(fit, file.path(out_dir, sprintf("fit_%s.rds", outcome_col)))

# Coefficient summary
sm <- as.data.frame(summary(fit)$fixed)
sm$param <- rownames(sm)
sm$outcome <- outcome_col
sm$contrast <- contrast
write.csv(sm, file.path(out_dir, sprintf("summary_%s.csv", outcome_col)),
          row.names = FALSE)
cat(sprintf("Saved fit + summary for %s / %s\n", outcome_col, contrast))
