# Simple aggregate rate ratios with Poisson exact CIs.
# Aggregates state × race → race × ban_category, then computes rate ratios.
# No iterative model fitting; closed-form CIs.

user_lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R/win-library/4.6")
.libPaths(c(user_lib, .libPaths()))
library(data.table)

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

big_races <- c("White", "Black or African American", "Hispanic or Latino",
               "American Indian or Alaska Native", "Asian")
dt[, race := as.character(race)]
dt_use <- dt[race %in% big_races]

# Aggregate to race × ban_category
agg <- dt_use[, .(deaths = sum(deaths), population = sum(population),
                  n_states = uniqueN(state_name)),
              by = .(race, ban_category, ban_intensity)]
agg[, rate_per_100k := deaths / population * 1e5]

# Poisson exact CI on rate
agg[, rate_ci_lower := qchisq(0.025, 2*deaths) / 2 / population * 1e5]
agg[deaths == 0, rate_ci_lower := 0]
agg[, rate_ci_upper := qchisq(0.975, 2*(deaths+1)) / 2 / population * 1e5]

agg <- agg[order(race, ban_intensity)]
cat("\n=== Aggregate rate per 100k by race × ban_category ===\n")
print(agg[, .(race, ban_category, n_states, deaths, pop = population,
              rate = round(rate_per_100k, 2),
              ci_lower = round(rate_ci_lower, 2),
              ci_upper = round(rate_ci_upper, 2))])

# Rate ratios: Total-ban vs No-restriction within each race
cat("\n=== Rate ratio: Total ban vs No restriction (within race) ===\n")
cat("Includes 95% CI via delta method on log scale.\n\n")
rr_rows <- list()
for (r in unique(agg$race)) {
  tb <- agg[race == r & ban_category == "Total ban"]
  nr <- agg[race == r & ban_category == "No restriction"]
  if (nrow(tb) == 0 || nrow(nr) == 0 || tb$deaths == 0 || nr$deaths == 0) {
    rr_rows[[length(rr_rows) + 1L]] <- data.table(
      race = r, rate_total_ban = ifelse(nrow(tb)>0, round(tb$rate_per_100k, 2), NA),
      rate_no_restr = ifelse(nrow(nr)>0, round(nr$rate_per_100k, 2), NA),
      rr = NA_real_, rr_ci_lower = NA_real_, rr_ci_upper = NA_real_,
      note = "zero counts in one or both cells; ratio undefined"
    )
    next
  }
  rr <- tb$rate_per_100k / nr$rate_per_100k
  se_log_rr <- sqrt(1/tb$deaths + 1/nr$deaths)
  log_rr <- log(rr)
  rr_lo <- exp(log_rr - 1.96 * se_log_rr)
  rr_hi <- exp(log_rr + 1.96 * se_log_rr)
  rr_rows[[length(rr_rows) + 1L]] <- data.table(
    race = r,
    rate_no_restr = round(nr$rate_per_100k, 2),
    rate_total_ban = round(tb$rate_per_100k, 2),
    rr = round(rr, 2),
    rr_ci_lower = round(rr_lo, 2),
    rr_ci_upper = round(rr_hi, 2),
    note = ifelse(rr_lo > 1, "CI excludes 1 (UP)",
                  ifelse(rr_hi < 1, "CI excludes 1 (DOWN)", "CI includes 1"))
  )
}
rr_dt <- rbindlist(rr_rows, fill = TRUE)
print(rr_dt)

# Black:White disparity ratio in each ban_category
cat("\n=== Black:White disparity within each ban category ===\n")
for (b in unique(agg$ban_category)) {
  w  <- agg[race == "White" & ban_category == b]
  bl <- agg[race == "Black or African American" & ban_category == b]
  if (nrow(w) > 0 && nrow(bl) > 0 && w$deaths > 0 && bl$deaths > 0) {
    rr <- bl$rate_per_100k / w$rate_per_100k
    se <- sqrt(1/bl$deaths + 1/w$deaths)
    lo <- exp(log(rr) - 1.96 * se); hi <- exp(log(rr) + 1.96 * se)
    cat(sprintf("  %s: Black=%.2f, White=%.2f, RR=%.2f [%.2f, %.2f]\n",
                b, bl$rate_per_100k, w$rate_per_100k, rr, lo, hi))
  }
}

fwrite(agg, file.path(res, "race_ban_aggregates.csv"))
fwrite(rr_dt, file.path(res, "rate_ratios_total_ban_vs_no_restriction.csv"))

cat("\nSaved aggregate + rate-ratio tables to results/\n")
