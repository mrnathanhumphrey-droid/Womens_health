# Study 03 — Cross-sectional disparity analysis (per DEVIATIONS Entry 003).
#
# WHAT: state × race maternal mortality rates joined with state ban category,
# tested for race × ban-category interaction.
#
# Inputs:
#   data/derived/wonder_mortality_parsed.rds (from 02_parse_wonder_mortality.R)
#   data/raw/reference/guttmacher_ban_status_snapshot_2026_04.csv
#
# Output:
#   results/cross_sectional_disparity.csv  (state × race table with rates)
#   results/race_x_ban_interaction.csv     (Bayesian model summary)
#   results/disparity_summary.md           (human-readable disposition)

user_lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R/win-library/4.6")
.libPaths(c(user_lib, .libPaths()))
options(repos = c(CRAN = "https://cloud.r-project.org"))

for (pkg in c("data.table", "brms", "posterior")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg, lib = user_lib)
}
library(data.table); library(brms); library(posterior)

repo <- "D:/Women's Health/Study_03_Roe_Fall_Shock"
res <- file.path(repo, "results")
dir.create(res, showWarnings = FALSE, recursive = TRUE)

# --- Load parsed mortality + ban category ----------------------------
parsed <- readRDS(file.path(repo, "data/derived/wonder_mortality_parsed.rds"))
state_race <- parsed$per_state_race
cat(sprintf("Loaded %d state × race cells\n", nrow(state_race)))

ban <- fread(file.path(repo, "data/raw/reference/guttmacher_ban_status_snapshot_2026_04.csv"))
ban[, ban_intensity := fcase(
  ban_category == "No restriction",          0L,
  ban_category == "Gestational limit 19+wk", 1L,
  ban_category == "Gestational limit <=18wk", 2L,
  ban_category == "Total ban",               3L
)]
# Use state_name to merge with WONDER (WONDER state_name = "Alabama" etc.)
setnames(ban, "state", "state_name")
ban_for_merge <- ban[, .(state_name, ban_category, ban_intensity)]

dt <- merge(state_race, ban_for_merge, by = "state_name", all.x = TRUE)
cat(sprintf("After merge: %d cells, %d missing ban category\n",
            nrow(dt), sum(is.na(dt$ban_intensity))))

# Drop missing
dt <- dt[!is.na(ban_intensity)]

# --- Descriptive: rate per race × ban category -----------------------
cat("\n=== Crude rates per 100k by race × ban-category ===\n")
descriptive <- dt[, .(
  deaths_total = sum(deaths),
  pop_total = sum(population),
  rate_per_100k = sum(deaths) / sum(population) * 1e5,
  n_states = uniqueN(state_name)
), by = .(race, ban_category)]
descriptive <- descriptive[order(race, ban_category)]
print(descriptive[, .(race, ban_category, n_states, deaths_total, rate_per_100k = round(rate_per_100k, 2))])

# Race-specific rate ratios (Total ban vs No restriction)
cat("\n=== Rate ratios: Total ban vs No restriction, by race ===\n")
rr_table <- list()
for (r in unique(descriptive$race)) {
  total_ban <- descriptive[race == r & ban_category == "Total ban"]
  no_restr  <- descriptive[race == r & ban_category == "No restriction"]
  if (nrow(total_ban) == 0 || nrow(no_restr) == 0) next
  rr <- total_ban$rate_per_100k / no_restr$rate_per_100k
  rr_table[[length(rr_table) + 1L]] <- data.table(
    race = r,
    rate_no_restr = round(no_restr$rate_per_100k, 2),
    rate_total_ban = round(total_ban$rate_per_100k, 2),
    rate_ratio = round(rr, 2)
  )
}
print(rbindlist(rr_table))

# Save descriptive
fwrite(descriptive, file.path(res, "cross_sectional_disparity.csv"))
cat(sprintf("\nSaved descriptive table to %s\n",
            file.path(res, "cross_sectional_disparity.csv")))

# --- Bayesian model: race × ban interaction --------------------------
cat("\n=== Fitting Bayesian NegBin (race × ban_intensity interaction) ===\n")
cat(sprintf("[%s] starting brm()\n", format(Sys.time())))

# Drop tiny race × state cells (zero deaths AND tiny population artifact)
dt_fit <- dt[population > 10000]
dt_fit[, race := factor(race, levels = c("White",
                                          "Black or African American",
                                          "Hispanic or Latino",
                                          "American Indian or Alaska Native",
                                          "Asian",
                                          "Native Hawaiian or Other Pacific Islander"))]
dt_fit <- dt_fit[!is.na(race)]
dt_fit[, ban_factor := factor(ban_category,
                              levels = c("No restriction",
                                          "Gestational limit 19+wk",
                                          "Gestational limit <=18wk",
                                          "Total ban"))]

cat(sprintf("Fit rows: %d (state × race cells after pop filter)\n", nrow(dt_fit)))

priors <- c(
  prior(normal(0, 2.5), class = "b"),
  prior(normal(0, 2.5), class = "Intercept"),
  prior(cauchy(0, 1),   class = "sd")
)

t0 <- Sys.time()
fit <- brm(
  deaths ~ race * ban_factor + offset(log(population)) + (1 | state_name),
  data    = dt_fit,
  family  = negbinomial(),
  prior   = priors,
  chains  = 4, iter = 2000, warmup = 1000,
  cores   = 4,
  control = list(adapt_delta = 0.95, max_treedepth = 12),
  refresh = 200,
  seed    = 20260524L,
  silent  = 1
)
t1 <- Sys.time()
cat(sprintf("[%s] done in %.1f min\n", format(t1),
            as.numeric(difftime(t1, t0, units = "mins"))))

# --- Extract race × ban interactions ---------------------------------
saveRDS(fit, file.path(res, "fit_race_x_ban.rds"))

sm <- as.data.frame(summary(fit)$fixed)
sm$param <- rownames(sm)
fwrite(sm, file.path(res, "race_x_ban_interaction.csv"))

cat("\n=== Race × ban interactions (log-odds scale) ===\n")
print(sm[grepl(":", sm$param), c("param", "Estimate", "l-95% CI", "u-95% CI")])

# Posterior rate-ratio: Black women in Total-ban vs No-restriction
# (baseline race = White, baseline ban = No restriction)
drws <- as_draws_df(fit)
# Black main effect + Black × Total-ban interaction = race-specific shift
# in Total-ban states relative to baseline (White, No restriction)

# Compute Black-White rate ratio in No-restriction and in Total-ban states
black_main <- "b_raceBlackorAfricanAmerican"
total_ban_main <- "b_ban_factorTotalban"
black_x_totalban <- "b_raceBlackorAfricanAmerican:ban_factorTotalban"

if (all(c(black_main, total_ban_main, black_x_totalban) %in% names(drws))) {
  rr_black_white_norestr <- exp(drws[[black_main]])
  rr_black_white_totalban <- exp(drws[[black_main]] + drws[[black_x_totalban]])
  diff_in_rr <- rr_black_white_totalban / rr_black_white_norestr

  cat("\n=== HEADLINE: Black-White rate ratio across ban categories ===\n")
  cat(sprintf("  Black:White in No-restriction states: median %.2f, 95%% CI [%.2f, %.2f]\n",
              median(rr_black_white_norestr),
              quantile(rr_black_white_norestr, 0.025),
              quantile(rr_black_white_norestr, 0.975)))
  cat(sprintf("  Black:White in Total-ban states:      median %.2f, 95%% CI [%.2f, %.2f]\n",
              median(rr_black_white_totalban),
              quantile(rr_black_white_totalban, 0.025),
              quantile(rr_black_white_totalban, 0.975)))
  cat(sprintf("  Ratio of ratios (Total-ban / No-restr): median %.2f, 95%% CI [%.2f, %.2f]\n",
              median(diff_in_rr),
              quantile(diff_in_rr, 0.025),
              quantile(diff_in_rr, 0.975)))
  excludes_one <- (quantile(diff_in_rr, 0.025) > 1) |
                  (quantile(diff_in_rr, 0.975) < 1)
  cat(sprintf("  CI excludes 1.0: %s\n", excludes_one))
}

cat(sprintf("\nAll outputs in %s\n", res))
