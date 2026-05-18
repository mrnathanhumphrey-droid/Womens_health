# Study 01 — Family 2: Hierarchical logistic + causal-Bayes prior on
# hospital bed-size selection bias.
#
# Per PRE_REGISTRATION.md §5 Family 2.
# Identical to Family 1 except: tight near-zero prior on bed_size
# coefficients, expressing the prior belief that bed size per se does not
# cause SMM — observed bed-size effects reflect case-mix selection.
# Tests whether observed bed-size effects survive the informative shrinkage.
#
# Usage:
#   Rscript scripts/05b_fit_family2_causal.R <outcome_col> <contrast>

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) stop("Usage: Rscript 05b_fit_family2_causal.R <outcome_col> <contrast>")
outcome_col <- args[[1]]; contrast <- args[[2]]
stopifnot(contrast %in% c("y2021", "rolling_2017_2021", "prepan_vs_pan"))

user_lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R/win-library/4.6")
.libPaths(c(user_lib, .libPaths()))

library(data.table); library(brms); library(posterior)

repo <- "D:/Women's Health/Study_01_Maternal_Mortality"
dt <- readRDS(file.path(repo, "data/derived/analysis_table.rds"))
load(file.path(repo, "reference/holdout_split.rda"))

dt_train <- dt[train_idx]
if (contrast == "y2021") {
  dt_train <- dt_train[year_actual == 2021L]; year_term <- NULL
} else if (contrast == "rolling_2017_2021") {
  dt_train <- dt_train[year_actual %in% 2017:2021]
  year_term <- "+ factor(year_actual)"
} else {
  dt_train <- dt_train[year_actual %in% 2017:2021]
  dt_train[, pandemic_era := factor(
    ifelse(year_actual >= 2020L, "pandemic", "prepandemic"),
    levels = c("prepandemic", "pandemic"))]
  year_term <- "+ pandemic_era"
}

n_events <- sum(dt_train[[outcome_col]], na.rm = TRUE)
n_total  <- sum(!is.na(dt_train[[outcome_col]]))
cat(sprintf("[%s/%s] n=%d, events=%d\n", contrast, outcome_col, n_total, n_events))
if (n_events < 200L) {
  cat("[POWER FLOOR] descriptive only.\n")
  out_dir <- file.path(repo, "results/family2", contrast)
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  saveRDS(list(outcome = outcome_col, contrast = contrast,
               n = n_total, events = n_events,
               note = "Below pre-reg power floor"),
          file.path(out_dir, sprintf("descriptive_%s.rds", outcome_col)))
  quit(save = "no", status = 0)
}

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

# --- Family 2 priors: TIGHT on bed_size (informative), wider on others -
priors_fam2 <- c(
  prior(normal(0, 2.5), class = "b"),
  prior(normal(0, 0.5), class = "b", coef = "bed_sizeMedium"),
  prior(normal(0, 0.5), class = "b", coef = "bed_sizeLarge"),
  prior(normal(0, 2.5), class = "Intercept"),
  prior(cauchy(0, 2.5), class = "sd")
)

cat(sprintf("[%s] Family 2 brms fit (tight bed_size prior N(0, 0.5))\n",
            format(Sys.time())))
t0 <- Sys.time()
fit <- brm(
  formula  = as.formula(formula_str),
  data     = dt_train,
  family   = bernoulli(),
  prior    = priors_fam2,
  chains   = 4, iter = 4000, warmup = 2000,
  cores    = 4,
  control  = list(adapt_delta = 0.95, max_treedepth = 12),
  refresh  = 200,
  seed     = 20260519L,
  silent   = 1
)
t1 <- Sys.time()
cat(sprintf("[%s] Done in %.1f min\n", format(t1),
            as.numeric(difftime(t1, t0, units = "mins"))))

out_dir <- file.path(repo, "results/family2", contrast)
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
saveRDS(fit, file.path(out_dir, sprintf("fit_%s.rds", outcome_col)))

sm <- as.data.frame(summary(fit)$fixed)
sm$param <- rownames(sm); sm$outcome <- outcome_col; sm$contrast <- contrast
write.csv(sm, file.path(out_dir, sprintf("summary_%s.csv", outcome_col)),
          row.names = FALSE)
cat(sprintf("Saved Family 2 fit + summary for %s / %s\n", outcome_col, contrast))
