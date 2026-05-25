# Difference-in-Differences with year-stratified data (the proper IDP-shape
# shock-amplification analysis the pre-reg originally locked).
#
# Post-Dobbs cut: 2022-06-24. We classify years 2018-2021 as PRE, 2022+ as POST.
# (2022 is mixed — partial pre/post; pre-reg-amendment treats whole-year-post for
# simplicity.)

user_lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R/win-library/4.6")
.libPaths(c(user_lib, .libPaths()))
library(data.table); library(MASS)

repo <- "D:/Women's Health/Study_03_Roe_Fall_Shock"
res <- file.path(repo, "results")

parsed <- readRDS(file.path(repo, "data/derived/wonder_mortality_parsed.rds"))
dt <- parsed$raw_rows_repro   # state × year × race × age (already repro-age filtered)
cat(sprintf("Loaded %d rows, years %s, races %d, states %d\n",
            nrow(dt), paste(range(dt$year), collapse = "-"),
            uniqueN(dt$race), uniqueN(dt$state_fips)))

# Aggregate across age groups (we filtered to repro ages already)
syr <- dt[, .(deaths = sum(Deaths, na.rm = TRUE),
              population = sum(Population, na.rm = TRUE)),
          by = .(state_fips, state_name, year, race)]

# Join ban category
ban <- fread(file.path(repo, "data/raw/reference/guttmacher_ban_status_snapshot_2026_04.csv"))
ban[, ban_intensity := fcase(
  ban_category == "No restriction",          0L,
  ban_category == "Gestational limit 19+wk", 1L,
  ban_category == "Gestational limit <=18wk", 2L,
  ban_category == "Total ban",               3L
)]
setnames(ban, "state", "state_name")
ban_for_merge <- ban[, .(state_name, ban_category, ban_intensity)]
syr <- merge(syr, ban_for_merge, by = "state_name", all.x = TRUE)
syr <- syr[!is.na(ban_intensity)]

# Post-Dobbs indicator
syr[, post_dobbs := as.integer(year >= 2022)]

cat(sprintf("Analysis frame: %d state-year-race cells (%d states × %d years × %d races)\n",
            nrow(syr), uniqueN(syr$state_name),
            uniqueN(syr$year), uniqueN(syr$race)))

# Restrict to 3 race groups with adequate signal
big_races <- c("White", "Black or African American", "Hispanic or Latino")
syr_fit <- syr[race %in% big_races & population > 50000]
syr_fit[, race := factor(race, levels = big_races)]
syr_fit[, year_f := factor(year)]

cat(sprintf("After race + population filter: %d rows\n", nrow(syr_fit)))

# --- Pre/post rates per ban category (descriptive first) -------------
cat("\n=== Pre-Dobbs vs post-Dobbs crude rates by race × ban category ===\n")
desc <- syr_fit[, .(deaths = sum(deaths), population = sum(population)),
                by = .(race, ban_category, post_dobbs)]
desc[, rate_per_100k := deaths / population * 1e5]
desc_w <- dcast(desc, race + ban_category ~ post_dobbs,
                value.var = c("rate_per_100k", "deaths"))
setnames(desc_w, c("rate_per_100k_0", "rate_per_100k_1", "deaths_0", "deaths_1"),
                  c("rate_pre", "rate_post", "deaths_pre", "deaths_post"))
desc_w[, change_pp := round(rate_post - rate_pre, 2)]
desc_w[, change_pct := round((rate_post / rate_pre - 1) * 100, 0)]
print(desc_w[order(race, ban_category)])

# --- DiD model with three-way interaction ----------------------------
cat("\n=== DiD: deaths ~ post * ban * race (NegBin GLM, offset log(pop)) ===\n")
syr_fit[, ban_factor := factor(ban_category,
                                levels = c("No restriction",
                                            "Gestational limit 19+wk",
                                            "Gestational limit <=18wk",
                                            "Total ban"))]
fit <- tryCatch(
  glm.nb(deaths ~ post_dobbs * ban_factor * race +
         offset(log(population)),
         data = syr_fit, control = glm.control(maxit = 200)),
  error = function(e) { cat("NegBin failed: ", conditionMessage(e),
                            "\nFalling back to Poisson.\n", sep = ""); NULL }
)
if (is.null(fit)) {
  fit <- glm(deaths ~ post_dobbs * ban_factor * race + offset(log(population)),
             data = syr_fit, family = poisson())
  fam <- "Poisson"
} else {
  fam <- "NegBin"
}
cat(sprintf("Model family: %s\n", fam))

sm <- summary(fit)
coef_dt <- as.data.table(sm$coefficients, keep.rownames = "param")
coef_dt[, rr := exp(Estimate)]
coef_dt[, rr_lower := exp(Estimate - 1.96 * `Std. Error`)]
coef_dt[, rr_upper := exp(Estimate + 1.96 * `Std. Error`)]

# Show interactions only
cat("\n=== Headline interactions (post × ban × race) ===\n")
inter <- coef_dt[grepl(":", param)]
print(inter[, .(param, rr = round(rr, 2),
                rr_ci = sprintf("[%.2f, %.2f]", rr_lower, rr_upper),
                p = round(`Pr(>|z|)`, 4))])

fwrite(coef_dt, file.path(res, "did_year_stratified.csv"))

# Decision rule per amended pre-reg: post × ban_factor interaction CI excludes
# 1 AND practical RR threshold 1.20 or 0.83
cat("\n=== Decision rule on post × ban interactions (race-pooled) ===\n")
post_ban <- coef_dt[grepl("^post_dobbs:ban_factor", param) &
                     !grepl(":race", param)]
for (i in seq_len(nrow(post_ban))) {
  row <- post_ban[i]
  ci_ex <- (row$rr_lower > 1) | (row$rr_upper < 1)
  prac <- (row$rr >= 1.20) | (row$rr <= 0.83)
  cat(sprintf("  %s: RR=%.2f [%.2f, %.2f], CI excludes 1=%s, practical=%s → %s\n",
              row$param, row$rr, row$rr_lower, row$rr_upper, ci_ex, prac,
              ifelse(ci_ex & prac, "FLAG", "null")))
}

# Three-way: post × ban × race
cat("\n=== Decision rule on three-way (post × ban × race) ===\n")
three <- coef_dt[grepl("^post_dobbs:ban_factor.*:race", param)]
for (i in seq_len(nrow(three))) {
  row <- three[i]
  ci_ex <- (row$rr_lower > 1) | (row$rr_upper < 1)
  prac <- (row$rr >= 1.20) | (row$rr <= 0.83)
  cat(sprintf("  %s\n    RR=%.2f [%.2f, %.2f], CI excludes 1=%s, practical=%s → %s\n",
              row$param, row$rr, row$rr_lower, row$rr_upper, ci_ex, prac,
              ifelse(ci_ex & prac, "FLAG", "null")))
}

cat(sprintf("\nSaved coefficient table to %s\n",
            file.path(res, "did_year_stratified.csv")))
