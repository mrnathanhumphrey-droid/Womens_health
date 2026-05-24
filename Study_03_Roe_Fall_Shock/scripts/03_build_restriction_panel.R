# Study 03 — Build treatment-intensity panel (pivoted per DEVIATIONS Entry 002).
#
# REPLACES original longitudinal-LawAtlas composite (unavailable publicly).
# Pivoted operationalization uses public revealed-preference indicators:
#   - ban_category: 4-level ordinal (No/Gest 19+/Gest ≤18/Total)
#   - time_to_ban_days: continuous days from Dobbs to ban implementation
#   - myers_distance_predobbs: optional county-level access measure
#
# Inputs:
#   data/raw/reference/guttmacher_ban_status_snapshot_2026_04.csv
#   data/raw/reference/state_time_to_ban_days.csv   (hand-coded, OPTIONAL —
#                                                    if missing, derive from
#                                                    Guttmacher categories only)
#   data/raw/reference/myers_county_distance.csv    (OPTIONAL)
#
# Output:
#   data/derived/restriction_panel.rds
#     Long panel: county_fips × year × month with treatment intensity
#     joined from state-level ban category + optional county-level Myers.

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

DOBBS_DATE <- as.Date("2022-06-24")

# --- Ban category from Guttmacher snapshot --------------------------
gutt_file <- file.path(ref, "guttmacher_ban_status_snapshot_2026_04.csv")
if (!file.exists(gutt_file)) stop("Guttmacher snapshot missing: ", gutt_file)
gutt <- fread(gutt_file)
cat(sprintf("Guttmacher snapshot: %d states\n", nrow(gutt)))

# Ordinal encoding 0-3
gutt[, ban_intensity := fcase(
  ban_category == "No restriction",          0L,
  ban_category == "Gestational limit 19+wk", 1L,
  ban_category == "Gestational limit <=18wk", 2L,
  ban_category == "Total ban",               3L,
  default = NA_integer_
)]
stopifnot(!any(is.na(gutt$ban_intensity)))
cat("Ban-category distribution:\n")
print(table(gutt$ban_category))

# --- Time-to-ban-days (optional hand-coded file) -------------------
ttb_file <- file.path(ref, "state_time_to_ban_days.csv")
if (file.exists(ttb_file)) {
  ttb <- fread(ttb_file)
  cat(sprintf("Time-to-ban file present: %d states\n", nrow(ttb)))
} else {
  cat("[NOTE] state_time_to_ban_days.csv not present. Deriving rough\n",
      "      proxy from ban_category: Total ban → 0 days (trigger-law\n",
      "      assumed); Gestational ≤18wk → 90 days; Gestational 19+wk\n",
      "      → 365 days; No restriction → 99999.\n",
      "      Replace with hand-coded effective-date file for higher-fidelity\n",
      "      analysis.\n", sep = "")
  ttb <- gutt[, .(state_abbr, time_to_ban_days = fcase(
    ban_intensity == 3L, 0L,
    ban_intensity == 2L, 90L,
    ban_intensity == 1L, 365L,
    ban_intensity == 0L, 99999L
  ))]
}
gutt <- merge(gutt, ttb, by = "state_abbr", all.x = TRUE)

# --- Myers county-distance (optional) ------------------------------
myers_file <- file.path(ref, "myers_county_distance.csv")
have_myers <- file.exists(myers_file)
if (have_myers) {
  myers <- fread(myers_file)
  cat(sprintf("Myers distance file present: %d rows\n", nrow(myers)))
  # Expected: county_fips, year, mean_distance_miles
  myers_pre <- myers[year == 2021,
                     .(myers_distance_predobbs = mean_distance_miles,
                       county_fips = county_fips)]
  if (nrow(myers_pre) == 0) {
    latest_pre <- max(myers$year[myers$year <= 2021])
    cat(sprintf("[NOTE] No 2021 vintage; using %d\n", latest_pre))
    myers_pre <- myers[year == latest_pre,
                       .(myers_distance_predobbs = mean_distance_miles,
                         county_fips = county_fips)]
  }
} else {
  cat("[NOTE] Myers county distance file not present. Continuing without\n",
      "      county-level access measure. Pre-reg §4 has this as optional.\n", sep = "")
  myers_pre <- NULL
}

# --- Build county-month panel skeleton ------------------------------
# Use USDA CZ crosswalk to get the full county list
cz_file <- file.path(ref, "usda_cz_2020_county_crosswalk.csv")
if (!file.exists(cz_file)) stop("CZ crosswalk missing: ", cz_file)
cz <- fread(cz_file)
setnames(cz, c("GEOID", "CZ20"), c("county_fips", "cz_2020"))
cz[, county_fips := sprintf("%05d", as.integer(county_fips))]

year_grid <- 2017:2024
month_grid <- 1:12
panel <- CJ(county_fips = unique(cz$county_fips),
            year = year_grid, month = month_grid)

# State from FIPS (first 2 digits)
panel[, state_fips := substr(county_fips, 1, 2)]
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
panel <- panel[!is.na(state_abbr)]   # drop territories not in lookup

# Join CZ
panel <- merge(panel, cz, by = "county_fips", all.x = TRUE)

# Join treatment intensities
panel <- merge(panel, gutt[, .(state_abbr, ban_category, ban_intensity,
                               time_to_ban_days)],
               by = "state_abbr", all.x = TRUE)

if (!is.null(myers_pre)) {
  myers_pre[, county_fips := sprintf("%05d", as.integer(county_fips))]
  panel <- merge(panel, myers_pre, by = "county_fips", all.x = TRUE)
} else {
  panel[, myers_distance_predobbs := NA_real_]
}

# --- Post-Dobbs indicators ----------------------------------------
panel[, date := as.Date(sprintf("%d-%02d-01", year, month))]
panel[, post_dobbs_sharp := as.integer(date >= DOBBS_DATE)]

# State-trigger: derived from time_to_ban_days. For each state-month, post=TRUE
# if (DOBBS_DATE + time_to_ban_days) <= panel$date
panel[, state_ban_date := DOBBS_DATE + time_to_ban_days]
panel[, post_dobbs_state_trigger := as.integer(date >= state_ban_date)]

saveRDS(panel, file.path(deriv, "restriction_panel.rds"))
cat(sprintf("\nSaved restriction panel: %d rows × %d cols → %s\n",
            nrow(panel), ncol(panel),
            file.path(deriv, "restriction_panel.rds")))
cat("Sample rows:\n")
print(head(panel))
