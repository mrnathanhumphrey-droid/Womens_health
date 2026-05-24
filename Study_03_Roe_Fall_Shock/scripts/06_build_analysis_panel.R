# Study 03 — Build final analysis panel (unit × year × race × age).
#
# Joins:
#   - Restriction panel (CZ or state, post-Dobbs indicators + pre-Dobbs intensity)
#   - WONDER mortality counts (numerator)
#   - WONDER natality counts (denominator / offset)
#   - Demographics: race, age group
#
# Output:
#   data/derived/analysis_panel_cz.rds      (CZ × year × race × age × outcome)
#   data/derived/analysis_panel_state.rds   (state × year × race × age × outcome)
#
# Run: Rscript scripts/06_build_analysis_panel.R [geo]
#       geo: "cz" | "state" | "both" (default)

user_lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R/win-library/4.6")
.libPaths(c(user_lib, .libPaths()))

library(data.table)

args <- commandArgs(trailingOnly = TRUE)
geo <- if (length(args) >= 1) args[[1]] else "both"
stopifnot(geo %in% c("cz", "state", "both"))

repo <- "D:/Women's Health/Study_03_Roe_Fall_Shock"
deriv <- file.path(repo, "data/derived")

build_for <- function(geo_unit) {
  panel_file <- file.path(deriv, sprintf("restriction_panel_%s.rds", geo_unit))
  mort_file  <- file.path(deriv, sprintf("wonder_mortality_%s.rds", geo_unit))
  nat_file   <- file.path(deriv, sprintf("wonder_natality_%s.rds", geo_unit))
  out_file   <- file.path(deriv, sprintf("analysis_panel_%s.rds", geo_unit))

  if (!file.exists(panel_file)) stop("Missing restriction panel: ", panel_file)
  if (!file.exists(mort_file))  stop("Missing WONDER mortality: ", mort_file)
  if (!file.exists(nat_file))   stop("Missing WONDER natality: ", nat_file)

  restriction <- readRDS(panel_file)
  mort <- readRDS(mort_file)
  nat <- readRDS(nat_file)

  cat(sprintf("[%s] restriction=%d rows, mort=%d rows, nat=%d rows\n",
              geo_unit, nrow(restriction), nrow(mort), nrow(nat)))

  # Collapse restriction to unit-year level (annualize from monthly)
  unit_col <- if (geo_unit == "cz") "cz_2010" else "state_abbr"
  restriction_yr <- restriction[, .(
    guttmacher_composite_predobbs = first(guttmacher_composite_predobbs),
    myers_distance_predobbs = first(myers_distance_predobbs),
    post_dobbs_sharp_share = mean(post_dobbs_sharp, na.rm = TRUE),
    post_dobbs_state_trigger_share = mean(post_dobbs_state_trigger, na.rm = TRUE)
  ), by = c(unit_col, "year")]

  # Discrete post-Dobbs binary: TRUE if any portion of the year is post
  restriction_yr[, post_dobbs_sharp := as.integer(post_dobbs_sharp_share > 0.5)]
  restriction_yr[, post_dobbs_state_trigger := as.integer(post_dobbs_state_trigger_share > 0.5)]

  # Rename mortality / natality outcome columns to canonical names
  setnames(mort, "deaths_births_count", "deaths")
  setnames(nat,  "deaths_births_count", "births")

  # Join mortality + natality on unit × year × race × age_group
  by_keys <- c(unit_col, "year", "race", "age_group")
  panel <- merge(mort, nat, by = by_keys, all = TRUE)

  # Join restriction
  panel <- merge(panel, restriction_yr, by = c(unit_col, "year"), all.x = TRUE)

  # Sanity: drop unit-years with no births (denominator zero)
  panel <- panel[!is.na(births) & births > 0]

  # Compute crude rate
  panel[, mortality_rate_per_100k := deaths / births * 1e5]

  cat(sprintf("[%s] analysis panel: %d rows × %d cols\n",
              geo_unit, nrow(panel), ncol(panel)))
  cat(sprintf("  Mean mortality rate (per 100k live births): %.2f\n",
              mean(panel$mortality_rate_per_100k, na.rm = TRUE)))

  saveRDS(panel, out_file)
  cat(sprintf("Saved %s\n\n", out_file))
}

if (geo %in% c("cz", "both"))    build_for("cz")
if (geo %in% c("state", "both")) build_for("state")
