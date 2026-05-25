# Frequentist NegBin fallback (no Stan compilation required).
# Same race × ban_category interaction as 10_cross_sectional_disparity.R.

user_lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R/win-library/4.6")
.libPaths(c(user_lib, .libPaths()))
options(repos = c(CRAN = "https://cloud.r-project.org"))

for (pkg in c("data.table", "MASS")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg, lib = user_lib)
}
library(data.table); library(MASS)

repo <- "D:/Women's Health/Study_03_Roe_Fall_Shock"
res <- file.path(repo, "results")

parsed <- readRDS(file.path(repo, "data/derived/wonder_mortality_parsed.rds"))
state_race <- parsed$per_state_race

ban <- fread(file.path(repo, "data/raw/reference/guttmacher_ban_status_snapshot_2026_04.csv"))
ban[, ban_intensity := fcase(
  ban_category == "No restriction",          0L,
  ban_category == "Gestational limit 19+wk", 1L,
  ban_category == "Gestational limit <=18wk", 2L,
  ban_category == "Total ban",               3L
)]
setnames(ban, "state", "state_name")
ban_for_merge <- ban[, .(state_name, ban_category, ban_intensity)]
dt <- merge(state_race, ban_for_merge, by = "state_name", all.x = TRUE)
dt <- dt[!is.na(ban_intensity)]

# Keep only race groups with adequate signal
dt[, race := as.character(race)]
big_races <- c("White", "Black or African American", "Hispanic or Latino")
dt_fit <- dt[race %in% big_races & population > 50000]

dt_fit[, race := factor(race, levels = big_races)]
dt_fit[, ban_factor := factor(ban_category,
                              levels = c("No restriction",
                                          "Gestational limit 19+wk",
                                          "Gestational limit <=18wk",
                                          "Total ban"))]

cat(sprintf("Fit rows: %d (filtered to 3 large race groups, pop > 50k)\n",
            nrow(dt_fit)))

# Fit NegBin with race × ban_category interaction + offset
fit <- glm.nb(deaths ~ race * ban_factor + offset(log(population)),
              data = dt_fit, control = glm.control(maxit = 100))
cat("\n=== Frequentist NegBin fit ===\n")
print(summary(fit))

# Confidence intervals on rate-ratio scale
ci <- confint(fit)
exp_coef <- exp(coef(fit))
exp_ci <- exp(ci)
rr_table <- data.frame(
  param = names(exp_coef),
  rate_ratio = round(exp_coef, 3),
  rr_lower = round(exp_ci[, 1], 3),
  rr_upper = round(exp_ci[, 2], 3)
)
fwrite(rr_table, file.path(res, "race_x_ban_freq.csv"))

cat("\n=== Rate ratios with 95% CI ===\n")
print(rr_table)

# Interaction tests
cat("\n=== Race × ban interaction interpretations ===\n")
cat("Each 'raceX:ban_factorY' row tells you the EXCESS rate ratio for that race\n")
cat("in that ban category, RELATIVE to the White-in-No-restriction baseline.\n")
cat("Values <1 = smaller disparity than baseline; >1 = larger disparity.\n\n")
interactions <- rr_table[grepl(":", rr_table$param), ]
print(interactions)

# Decision rule per amended pre-reg
cat("\n=== Decision rule check ===\n")
for (i in seq_len(nrow(interactions))) {
  row <- interactions[i, ]
  ci_ex <- (row$rr_lower > 1) | (row$rr_upper < 1)
  practical <- (row$rate_ratio >= 1.20) | (row$rate_ratio <= 0.83)
  pass <- ci_ex & practical
  cat(sprintf("  %s: RR=%.2f [%.2f, %.2f] — CI excludes 1: %s, practical: %s → %s\n",
              row$param, row$rate_ratio, row$rr_lower, row$rr_upper,
              ci_ex, practical, ifelse(pass, "FLAG", "null")))
}
