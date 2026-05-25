# Parse WONDER MCD CSV exports → clean state × age × race × year panel.
# Auto-detects which columns are present (year may or may not be in the
# group-by). Strips WONDER's footer metadata rows.
#
# Input: data/raw/wonder/*.csv (any MCD export)
# Output: data/derived/wonder_mortality_parsed.rds

user_lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R/win-library/4.6")
.libPaths(c(user_lib, .libPaths()))
library(data.table)

repo <- "D:/Women's Health/Study_03_Roe_Fall_Shock"
wonder_dir <- file.path(repo, "data/raw/wonder")
deriv <- file.path(repo, "data/derived")
dir.create(deriv, showWarnings = FALSE, recursive = TRUE)

files <- list.files(wonder_dir, pattern = "\\.csv$", full.names = TRUE)
if (length(files) == 0) stop("No WONDER CSV in ", wonder_dir)

parse_one <- function(f) {
  cat(sprintf("Parsing %s\n", basename(f)))
  # WONDER appends free-text footnotes after the data; fread stops at
  # first non-conforming row when given fill=TRUE — easier: read all,
  # then keep only rows where State Code looks like a 2-digit FIPS.
  raw <- fread(f, fill = TRUE, na.strings = c("", "NA", "Suppressed",
                                              "Missing", "Not Applicable"))
  # Real data rows: State Code matches /^\d{2}$/
  raw[, `State Code` := as.character(`State Code`)]
  dt <- raw[grepl("^\\d{2}$", `State Code`)]
  cat(sprintf("  raw=%d, clean=%d (footnotes stripped)\n",
              nrow(raw), nrow(dt)))
  # Standardize column names
  setnames(dt, c("State", "State Code"), c("state_name", "state_fips"))
  if ("Year" %in% names(dt)) setnames(dt, "Year", "year")
  if ("Year Code" %in% names(dt)) dt[, year := as.integer(`Year Code`)]
  if ("Ten-Year Age Groups Code" %in% names(dt)) {
    setnames(dt, "Ten-Year Age Groups Code", "age_group")
  } else if ("Ten-Year Age Groups" %in% names(dt)) {
    setnames(dt, "Ten-Year Age Groups", "age_group")
  }
  if ("Single Race 6" %in% names(dt)) setnames(dt, "Single Race 6", "race")
  dt[, Deaths := as.integer(Deaths)]
  dt[, Population := as.integer(Population)]
  dt
}

parsed <- rbindlist(lapply(files, parse_one), use.names = TRUE, fill = TRUE)
cat(sprintf("\nMerged: %d rows from %d files\n", nrow(parsed), length(files)))
cat("Columns: ", paste(names(parsed), collapse = ", "), "\n", sep = "")

# Filter to reproductive age groups (15-54)
repro <- c("15-24", "25-34", "35-44", "45-54")
if ("age_group" %in% names(parsed)) {
  parsed_repro <- parsed[age_group %in% repro]
  cat(sprintf("Reproductive-age rows (15–54): %d\n", nrow(parsed_repro)))
} else {
  parsed_repro <- parsed
}

# Aggregate to state × race (collapsing age) — for cross-sectional analysis
if ("race" %in% names(parsed_repro)) {
  state_race <- parsed_repro[, .(deaths = sum(Deaths, na.rm = TRUE),
                                  population = sum(Population, na.rm = TRUE)),
                              by = .(state_fips, state_name, race)]
  state_race[, rate_per_100k := deaths / population * 1e5]
  cat("\nTop 15 state × race cells by death count:\n")
  print(state_race[order(-deaths)][1:15])
}

# Also: state-level totals across race
state_totals <- parsed_repro[, .(deaths = sum(Deaths, na.rm = TRUE),
                                  population = sum(Population, na.rm = TRUE)),
                              by = .(state_fips, state_name)]
state_totals[, rate_per_100k := deaths / population * 1e5]
cat(sprintf("\nTotal female maternal-cause deaths (reproductive age) 2018-2024: %d\n",
            sum(state_totals$deaths, na.rm = TRUE)))
cat(sprintf("Total reproductive-age female-years: %.1fM\n",
            sum(state_totals$population, na.rm = TRUE) / 1e6))
cat(sprintf("Crude national rate: %.1f per 100k\n",
            sum(state_totals$deaths, na.rm = TRUE) /
              sum(state_totals$population, na.rm = TRUE) * 1e5))

saveRDS(list(per_state_race = if (exists("state_race")) state_race else NULL,
             per_state_total = state_totals,
             raw_rows_repro = parsed_repro),
        file.path(deriv, "wonder_mortality_parsed.rds"))
cat(sprintf("\nSaved parsed data to %s\n",
            file.path(deriv, "wonder_mortality_parsed.rds")))
