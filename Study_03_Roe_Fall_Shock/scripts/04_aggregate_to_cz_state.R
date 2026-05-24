# Study 03 — Aggregate county-level data to commuting zone and state.
#
# Per PRE_REGISTRATION.md §5, we run analyses at BOTH commuting zone
# (709 zones) and state (51 units) granularity.
#
# Inputs:
#   data/derived/restriction_panel.rds   (county-month panel)
#   data/raw/reference/usda_cz_2010_county_crosswalk.csv
#   data/raw/wonder/mortality_county_year_race_age.csv  (if available)
#   data/raw/wonder/natality_county_year_race_age.csv   (if available)
#
# Output:
#   data/derived/restriction_panel_cz.rds
#   data/derived/restriction_panel_state.rds
#   data/derived/wonder_aggregated_cz.rds (if county WONDER pulls landed)
#   data/derived/wonder_aggregated_state.rds (if county WONDER pulls landed)

user_lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R/win-library/4.6")
.libPaths(c(user_lib, .libPaths()))

for (pkg in c("data.table")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg, lib = user_lib)
}
library(data.table)

repo <- "D:/Women's Health/Study_03_Roe_Fall_Shock"
ref <- file.path(repo, "data/raw/reference")
deriv <- file.path(repo, "data/derived")

# --- Load CZ crosswalk -----------------------------------------------
cz_file <- file.path(ref, "usda_cz_2010_county_crosswalk.csv")
if (!file.exists(cz_file)) stop("USDA CZ crosswalk missing: ", cz_file)
cz <- fread(cz_file)
# Expected columns: county_fips, cz_2010 (CZ ID)
cat(sprintf("CZ crosswalk: %d counties → %d zones\n",
            nrow(cz), length(unique(cz$cz_2010))))

# --- Aggregate restriction panel to CZ + state ----------------------
panel <- readRDS(file.path(deriv, "restriction_panel.rds"))
panel[, county_fips := as.character(county_fips)]
cz[, county_fips := as.character(county_fips)]
panel <- merge(panel, cz[, .(county_fips, cz_2010)], by = "county_fips", all.x = TRUE)

# CZ-level: weighted-mean of Myers distance, mode of state policy
panel_cz <- panel[, .(
  state_abbrs = paste(unique(state_abbr), collapse = ";"),
  state_abbr_primary = names(sort(table(state_abbr), decreasing = TRUE))[1],
  guttmacher_composite_predobbs = mean(guttmacher_composite_predobbs, na.rm = TRUE),
  myers_distance_predobbs = mean(myers_distance_predobbs, na.rm = TRUE),
  post_dobbs_sharp = mean(post_dobbs_sharp, na.rm = TRUE),
  post_dobbs_state_trigger = mean(post_dobbs_state_trigger, na.rm = TRUE)
), by = .(cz_2010, year, month)]

saveRDS(panel_cz, file.path(deriv, "restriction_panel_cz.rds"))
cat(sprintf("CZ panel: %d rows × %d cols → restriction_panel_cz.rds\n",
            nrow(panel_cz), ncol(panel_cz)))

# State-level: state-month direct aggregation
panel_state <- panel[, .(
  guttmacher_composite_predobbs = first(na.omit(guttmacher_composite_predobbs)),
  myers_distance_predobbs = mean(myers_distance_predobbs, na.rm = TRUE),
  post_dobbs_sharp = first(post_dobbs_sharp),
  post_dobbs_state_trigger = first(post_dobbs_state_trigger)
), by = .(state_abbr, year, month)]

saveRDS(panel_state, file.path(deriv, "restriction_panel_state.rds"))
cat(sprintf("State panel: %d rows × %d cols → restriction_panel_state.rds\n",
            nrow(panel_state), ncol(panel_state)))

# --- Aggregate WONDER outputs (if available) ------------------------
agg_wonder <- function(file_pat, out_name, unit_col) {
  files <- list.files(file.path(repo, "data/raw/wonder"),
                      pattern = file_pat, full.names = TRUE)
  if (length(files) == 0) {
    cat(sprintf("[skip] No WONDER files matching %s — pipeline gating step\n",
                file_pat))
    return(invisible(NULL))
  }
  # Assumes parsed county-level CSV with columns:
  #   county_fips, year, race, age_group, deaths (or births), suppressed
  ws <- rbindlist(lapply(files, fread), fill = TRUE, use.names = TRUE)
  if (unit_col == "cz_2010") {
    ws <- merge(ws, cz[, .(county_fips, cz_2010)], by = "county_fips",
                all.x = TRUE)
    agg <- ws[, .(deaths_births_count = sum(get("deaths_or_births"), na.rm = TRUE),
                  n_suppressed = sum(suppressed == TRUE, na.rm = TRUE)),
              by = .(cz_2010, year, race, age_group)]
  } else {
    agg <- ws[, .(deaths_births_count = sum(get("deaths_or_births"), na.rm = TRUE),
                  n_suppressed = sum(suppressed == TRUE, na.rm = TRUE)),
              by = .(state_abbr, year, race, age_group)]
  }
  saveRDS(agg, file.path(deriv, out_name))
  cat(sprintf("Saved %s (%d rows)\n", out_name, nrow(agg)))
}

# Will silently skip if WONDER county pulls haven't run yet
agg_wonder("mortality_county.*\\.csv", "wonder_mortality_cz.rds",  "cz_2010")
agg_wonder("mortality_county.*\\.csv", "wonder_mortality_state.rds", "state_abbr")
agg_wonder("natality_county.*\\.csv",  "wonder_natality_cz.rds",   "cz_2010")
agg_wonder("natality_county.*\\.csv",  "wonder_natality_state.rds",  "state_abbr")

cat("\nAggregation complete. Run scripts/05_restriction_correlation.R next.\n")
