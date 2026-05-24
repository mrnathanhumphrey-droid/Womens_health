# Study 03 — Pre-analysis: correlation between Guttmacher composite
# and Caitlin Myers clinic-distance.
#
# Per PRE_REGISTRATION.md §4, run BEFORE primary model fits.
# Report Pearson + Spearman correlation between the two restriction
# measures at the unit-year level. Interpretation:
#   ρ > 0.85 → measures substantively redundant; treat Myers as
#              robustness-only flag
#   ρ < 0.85 → measures genuinely complementary; report both as
#              parallel primary results
#
# Output:
#   results/restriction_correlation_summary.csv
#   results/restriction_correlation_scatter_state.png
#   results/restriction_correlation_scatter_cz.png

user_lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R/win-library/4.6")
.libPaths(c(user_lib, .libPaths()))

for (pkg in c("data.table", "ggplot2")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg, lib = user_lib)
}
library(data.table); library(ggplot2)

repo <- "D:/Women's Health/Study_03_Roe_Fall_Shock"
deriv <- file.path(repo, "data/derived")
res <- file.path(repo, "results")
dir.create(res, showWarnings = FALSE, recursive = TRUE)

panel_cz    <- readRDS(file.path(deriv, "restriction_panel_cz.rds"))
panel_state <- readRDS(file.path(deriv, "restriction_panel_state.rds"))

# Deduplicate to one row per unit (pre-Dobbs measures are time-invariant)
cz_unit <- unique(panel_cz[, .(cz_2010, guttmacher_composite_predobbs,
                                myers_distance_predobbs)])
state_unit <- unique(panel_state[, .(state_abbr, guttmacher_composite_predobbs,
                                      myers_distance_predobbs)])

cz_unit <- cz_unit[!is.na(guttmacher_composite_predobbs) &
                   !is.na(myers_distance_predobbs)]
state_unit <- state_unit[!is.na(guttmacher_composite_predobbs) &
                         !is.na(myers_distance_predobbs)]

correlation_summary <- list()

run_corr <- function(dt, unit_name) {
  n <- nrow(dt)
  pearson <- cor(dt$guttmacher_composite_predobbs,
                 dt$myers_distance_predobbs, method = "pearson")
  spearman <- cor(dt$guttmacher_composite_predobbs,
                  dt$myers_distance_predobbs, method = "spearman")
  cat(sprintf("[%s] n=%d, Pearson=%.3f, Spearman=%.3f\n",
              unit_name, n, pearson, spearman))
  verdict <- ifelse(abs(pearson) > 0.85, "redundant", "complementary")
  cat(sprintf("  Verdict: %s (threshold |r|>0.85)\n", verdict))
  data.table(unit = unit_name, n = n, pearson = pearson,
             spearman = spearman, verdict = verdict)
}

correlation_summary[[1]] <- run_corr(state_unit, "state")
correlation_summary[[2]] <- run_corr(cz_unit, "commuting_zone")

summary_dt <- rbindlist(correlation_summary)
fwrite(summary_dt, file.path(res, "restriction_correlation_summary.csv"))
cat(sprintf("\nSaved correlation summary to %s\n",
            file.path(res, "restriction_correlation_summary.csv")))

# --- Plots ----------------------------------------------------------
p_state <- ggplot(state_unit, aes(x = guttmacher_composite_predobbs,
                                  y = myers_distance_predobbs)) +
  geom_point(alpha = 0.7, size = 2) +
  geom_smooth(method = "lm", se = TRUE) +
  labs(x = "Guttmacher restriction composite (pre-Dobbs mean)",
       y = "Myers clinic distance (miles, pre-Dobbs)",
       title = "Pre-Dobbs restriction measures: state-level scatter") +
  theme_minimal()
ggsave(file.path(res, "restriction_correlation_scatter_state.png"),
       p_state, width = 7, height = 5, dpi = 120)

p_cz <- ggplot(cz_unit, aes(x = guttmacher_composite_predobbs,
                            y = myers_distance_predobbs)) +
  geom_point(alpha = 0.4, size = 1) +
  geom_smooth(method = "lm", se = TRUE) +
  labs(x = "Guttmacher restriction composite (pre-Dobbs mean)",
       y = "Myers clinic distance (miles, pre-Dobbs)",
       title = "Pre-Dobbs restriction measures: commuting-zone scatter") +
  theme_minimal()
ggsave(file.path(res, "restriction_correlation_scatter_cz.png"),
       p_cz, width = 7, height = 5, dpi = 120)

cat("Saved scatter plots.\n")
cat("\nPer pre-reg §4: if Pearson > 0.85, treat Myers as sensitivity-only;\n",
    "otherwise report both Guttmacher and Myers as parallel primary results.\n",
    sep = "")
