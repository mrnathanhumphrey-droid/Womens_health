# Study 03 — Build pre-Dobbs restriction-intensity panel.
#
# Combines Guttmacher state-monthly policy variables + Caitlin Myers
# county-year clinic distance + KFF post-Dobbs effective dates into
# the analysis-ready restriction panel.
#
# Inputs (manual downloads expected; see scripts/00_data_access_scope.md):
#   data/raw/reference/guttmacher_state_policy_2017_2022.csv
#   data/raw/reference/kff_post_dobbs_status.csv
#   data/raw/reference/myers_county_distance.csv
#
# Output:
#   data/derived/restriction_panel.rds
#     Columns: state, county_fips, year, month,
#              guttmacher_composite, guttmacher_components_*,
#              myers_distance_miles,
#              post_dobbs_sharp, post_dobbs_state_trigger,
#              state_trigger_date

user_lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R/win-library/4.6")
.libPaths(c(user_lib, .libPaths()))

for (pkg in c("data.table", "lubridate")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg, lib = user_lib)
}
library(data.table); library(lubridate)

repo <- "D:/Women's Health/Study_03_Roe_Fall_Shock"
ref <- file.path(repo, "data/raw/reference")
deriv <- file.path(repo, "data/derived")
dir.create(deriv, showWarnings = FALSE, recursive = TRUE)

# Sharp Dobbs date
DOBBS_DATE <- as.Date("2022-06-24")

# --- Load Guttmacher state-monthly policy timeline -------------------
gutt_file <- file.path(ref, "guttmacher_state_policy_2017_2022.csv")
if (!file.exists(gutt_file)) {
  stop("Guttmacher file missing at ", gutt_file,
       ". Manual download required — see scripts/00_data_access_scope.md.")
}
gutt <- fread(gutt_file)
cat(sprintf("Guttmacher: %d rows × %d cols\n", nrow(gutt), ncol(gutt)))

# Expected Guttmacher columns (may need renaming based on actual download):
#   state, state_abbr, year, month, gestational_limit_weeks,
#   medicaid_funding_restricted, trap_law, mandatory_counseling,
#   waiting_period_hours, parental_notification
# Adjust this section once file lands.

# Build composite score (per pre-reg §4):
#   Sum of binary policy indicators measured pre-Dobbs at 2017 baseline OR
#   any monthly observation. We use a continuous count of restrictive-policy
#   indicators at the state-month level.
required_cols <- c("state_abbr", "year", "month",
                   "medicaid_funding_restricted", "trap_law",
                   "mandatory_counseling", "parental_notification")
missing_cols <- setdiff(required_cols, names(gutt))
if (length(missing_cols) > 0) {
  cat("[WARN] Guttmacher missing expected columns:",
      paste(missing_cols, collapse = ", "), "\n",
      "Adapt this block to actual file structure.\n")
}

# Composite construction (assuming binary 0/1 indicators where applicable)
gutt[, guttmacher_composite := rowSums(.SD, na.rm = TRUE),
     .SDcols = intersect(c("medicaid_funding_restricted", "trap_law",
                           "mandatory_counseling", "parental_notification"),
                         names(gutt))]
# Add gestational-limit and waiting-period as binaries (1 if restrictive)
if ("gestational_limit_weeks" %in% names(gutt)) {
  gutt[, gest_limit_restrictive := as.integer(gestational_limit_weeks <= 20)]
  gutt[, guttmacher_composite := guttmacher_composite + gest_limit_restrictive]
}
if ("waiting_period_hours" %in% names(gutt)) {
  gutt[, wait_period_restrictive := as.integer(waiting_period_hours > 0)]
  gutt[, guttmacher_composite := guttmacher_composite + wait_period_restrictive]
}

cat(sprintf("Guttmacher composite range: %d - %d (mean %.2f)\n",
            min(gutt$guttmacher_composite, na.rm = TRUE),
            max(gutt$guttmacher_composite, na.rm = TRUE),
            mean(gutt$guttmacher_composite, na.rm = TRUE)))

# Pre-Dobbs baseline = mean composite Jan 2017 through May 2022
gutt_pre <- gutt[(year < 2022) | (year == 2022 & month <= 5),
                 .(guttmacher_composite_predobbs = mean(guttmacher_composite,
                                                        na.rm = TRUE)),
                 by = state_abbr]

# --- Load KFF post-Dobbs status --------------------------------------
kff_file <- file.path(ref, "kff_post_dobbs_status.csv")
if (!file.exists(kff_file)) {
  stop("KFF file missing at ", kff_file)
}
kff <- fread(kff_file)
cat(sprintf("KFF: %d rows\n", nrow(kff)))
# Expected: state_abbr, status (Banned / Restricted / etc.), effective_date

# --- Load Myers county-distance --------------------------------------
myers_file <- file.path(ref, "myers_county_distance.csv")
if (!file.exists(myers_file)) {
  stop("Myers file missing at ", myers_file)
}
myers <- fread(myers_file)
cat(sprintf("Myers: %d rows\n", nrow(myers)))
# Expected: county_fips, year, mean_distance_miles (or similar)

# Pre-Dobbs distance baseline (2021 vintage per pre-reg §4)
myers_pre <- myers[year == 2021, .(myers_distance_predobbs = mean_distance_miles,
                                    county_fips = county_fips)]
if (nrow(myers_pre) == 0) {
  # Fallback to latest available pre-Dobbs year
  latest_pre <- max(myers$year[myers$year <= 2021])
  cat(sprintf("[NOTE] No 2021 vintage; falling back to %d\n", latest_pre))
  myers_pre <- myers[year == latest_pre,
                     .(myers_distance_predobbs = mean_distance_miles,
                       county_fips = county_fips)]
}

# --- Assemble panel ---------------------------------------------------
# Expand state-monthly Guttmacher to county-monthly via state join
# Then join Myers county-yearly distance
# Then add post-Dobbs indicators

# Build county-month skeleton from Myers counties × time range
county_list <- unique(myers$county_fips)
year_grid <- 2017:2024
month_grid <- 1:12
panel <- CJ(county_fips = county_list, year = year_grid, month = month_grid)

# Add state from county FIPS (first 2 digits of FIPS)
panel[, state_fips := substr(sprintf("%05d", as.integer(county_fips)), 1, 2)]
fips_to_abbr <- c(
  "01"="AL","02"="AK","04"="AZ","05"="AR","06"="CA","08"="CO","09"="CT",
  "10"="DE","11"="DC","12"="FL","13"="GA","15"="HI","16"="ID","17"="IL",
  "18"="IN","19"="IA","20"="KS","21"="KY","22"="LA","23"="ME","24"="MD",
  "25"="MA","26"="MI","27"="MN","28"="MS","29"="MO","30"="MT","31"="NE",
  "32"="NV","33"="NH","34"="NJ","35"="NM","36"="NY","37"="NC","38"="ND",
  "39"="OH","40"="OK","41"="OR","42"="PA","44"="RI","45"="SC","46"="SD",
  "47"="TN","48"="TX","49"="UT","50"="VT","51"="VA","53"="WA","54"="WV",
  "55"="WI","56"="WY"
)
panel[, state_abbr := fips_to_abbr[state_fips]]

# Join pre-Dobbs Guttmacher composite
panel <- merge(panel, gutt_pre, by = "state_abbr", all.x = TRUE)

# Join pre-Dobbs Myers distance
panel <- merge(panel, myers_pre, by = "county_fips", all.x = TRUE)

# Post-Dobbs sharp indicator
panel[, date := as.Date(sprintf("%d-%02d-01", year, month))]
panel[, post_dobbs_sharp := as.integer(date >= DOBBS_DATE)]

# Post-Dobbs state-trigger indicator from KFF
state_trigger <- kff[, .(state_abbr, state_trigger_date = as.Date(effective_date))]
panel <- merge(panel, state_trigger, by = "state_abbr", all.x = TRUE)
panel[is.na(state_trigger_date), state_trigger_date := DOBBS_DATE]
panel[, post_dobbs_state_trigger := as.integer(date >= state_trigger_date)]

saveRDS(panel, file.path(deriv, "restriction_panel.rds"))
cat(sprintf("\nSaved restriction panel: %d rows × %d cols → %s\n",
            nrow(panel), ncol(panel),
            file.path(deriv, "restriction_panel.rds")))
