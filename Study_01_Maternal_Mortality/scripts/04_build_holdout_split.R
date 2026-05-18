# Study 01 — Build 80/20 held-out split.
#
# Per PRE_REGISTRATION.md §7: 80/20 random split at patient (discharge)
# level, stratified by state × composite SMM event status. Seed 20260518.
# Frozen as reference/holdout_split.rda BEFORE any model fits.
#
# Output:
#   reference/holdout_split.rda — train_idx, test_idx (integer vectors
#                                  indexing into analysis_table.rds rows)

user_lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R/win-library/4.6")
.libPaths(c(user_lib, .libPaths()))

for (pkg in c("data.table")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg, lib = user_lib)
}
library(data.table)

repo <- "D:/Women's Health/Study_01_Maternal_Mortality"
analysis_file <- file.path(repo, "data/derived/analysis_table.rds")
out_file <- file.path(repo, "reference/holdout_split.rda")

if (file.exists(out_file)) {
  stop("Split already locked at ", out_file,
       ". Per pre-reg §10 constraint 1, do not regenerate. ",
       "To rebuild, log a deviation in DEVIATIONS.md and remove the file manually.")
}

dt <- readRDS(analysis_file)
n <- nrow(dt)
cat(sprintf("Analysis table: %d rows\n", n))

# Stratify by state × composite SMM (excl transfusion = CDC primary)
state_col <- intersect(c("HOSP_STATE", "HOSPST", "hosp_state_clean"), names(dt))[1]
stopifnot(!is.na(state_col))

dt[, .strat_key := paste(get(state_col), smm_composite_excl_trans, sep = "_")]

set.seed(20260518L)
test_idx <- integer(0)
for (key in unique(dt$.strat_key)) {
  rows <- which(dt$.strat_key == key)
  n_test <- max(1L, floor(0.20 * length(rows)))
  test_idx <- c(test_idx, sample(rows, n_test))
}
train_idx <- setdiff(seq_len(n), test_idx)
test_idx <- sort(test_idx); train_idx <- sort(train_idx)

cat(sprintf("Train: %d (%.1f%%) ; Test: %d (%.1f%%)\n",
            length(train_idx), 100 * length(train_idx) / n,
            length(test_idx),  100 * length(test_idx)  / n))

# Verify stratification preserves composite SMM rate
train_rate <- mean(dt$smm_composite_excl_trans[train_idx])
test_rate  <- mean(dt$smm_composite_excl_trans[test_idx])
cat(sprintf("Composite SMM rate — train: %.4f, test: %.4f\n",
            train_rate, test_rate))

dt[, .strat_key := NULL]

save(train_idx, test_idx, file = out_file)
cat(sprintf("Holdout split locked at %s\n", out_file))
cat("PER PRE-REG §10 CONSTRAINT 1: this split is now frozen. Do not\n",
    "rebuild without a documented deviation.\n", sep = "")
