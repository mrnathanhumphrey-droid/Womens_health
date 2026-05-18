# Study 01 — Define analytic population (delivery hospitalizations).
#
# Inputs:
#   data/raw/nis_YYYY/NIS_YYYY_Core.csv (or .sas7bdat) — discharge core file
#   data/raw/nis_YYYY/NIS_YYYY_Hospital.csv             — hospital characteristics
#
# Output:
#   data/derived/nis_YYYY_deliveries.rds  (one row per delivery hospitalization)
#
# Inclusion (PRE_REGISTRATION.md §2):
#   - Female sex
#   - Age 12-55
#   - Delivery hospitalization, identified by:
#       DRG codes (765, 766, 767, 774, 775)
#       OR ICD-10-PCS delivery procedure codes
#       (10D00Z0, 10D00Z1, 10D00Z2, 10E0XZZ, 10D07Z3-Z8)
#
# Run: Rscript scripts/01_define_population.R <year>

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) stop("Usage: Rscript 01_define_population.R <year>")
year <- as.integer(args[[1]])
stopifnot(year %in% 2017:2023)

user_lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R/win-library/4.6")
.libPaths(c(user_lib, .libPaths()))
options(repos = c(CRAN = "https://cloud.r-project.org"))

for (pkg in c("data.table", "haven", "stringr")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg, lib = user_lib)
}
library(data.table)
library(haven)
library(stringr)

repo <- "D:/Women's Health/Study_01_Maternal_Mortality"
raw_dir <- file.path(repo, "data/raw", sprintf("nis_%d", year))
out_dir <- file.path(repo, "data/derived")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# --- Locate and load core file ----------------------------------------
# NIS distributes as .sas7bdat (SAS) or ASCII; we accept whichever.
core_candidates <- list.files(raw_dir,
  pattern = sprintf("NIS_%d_Core.*\\.(sas7bdat|csv|asc)$", year),
  full.names = TRUE, ignore.case = TRUE)
if (length(core_candidates) == 0) stop("No core file for ", year, " in ", raw_dir)
core_file <- core_candidates[[1]]
cat(sprintf("[%s] Loading core: %s\n", format(Sys.time()), core_file))

if (grepl("\\.sas7bdat$", core_file, ignore.case = TRUE)) {
  dt <- as.data.table(haven::read_sas(core_file))
} else {
  dt <- data.table::fread(core_file)
}
cat(sprintf("  rows: %d, cols: %d\n", nrow(dt), ncol(dt)))

# --- Standardize column case (NIS uses uppercase) ---------------------
setnames(dt, toupper(names(dt)))

# --- Inclusion: female, age 12-55 -------------------------------------
# FEMALE: 1 = female, 0 = male in NIS (varies — also SEX in some years)
sex_col <- intersect(c("FEMALE", "SEX"), names(dt))[1]
if (is.na(sex_col)) stop("Cannot find FEMALE/SEX column")
if (sex_col == "FEMALE") {
  dt <- dt[FEMALE == 1]
} else {
  dt <- dt[SEX == 2]   # NIS SEX: 1=M, 2=F (verify per year)
}
cat(sprintf("  After female filter: %d rows\n", nrow(dt)))

dt <- dt[AGE >= 12 & AGE <= 55]
cat(sprintf("  After age 12-55 filter: %d rows\n", nrow(dt)))

# --- Identify delivery hospitalizations -------------------------------
# DRG-based identifier
delivery_drgs <- c(765, 766, 767, 768, 774, 775)   # 768 added for completeness

drg_col <- intersect(c("DRG", "DRGVER", "DRG_NoPOA"), names(dt))[1]
if (is.na(drg_col)) {
  cat("  [WARN] No DRG column; using ICD-PCS only.\n")
  dt[, is_delivery_drg := FALSE]
} else {
  dt[, is_delivery_drg := get(drg_col) %in% delivery_drgs]
}

# ICD-10-PCS delivery procedure codes
delivery_pcs_codes <- c(
  "10D00Z0", "10D00Z1", "10D00Z2",
  "10E0XZZ",
  "10D07Z3", "10D07Z4", "10D07Z5", "10D07Z6", "10D07Z7", "10D07Z8"
)
pr_cols <- grep("^I10_PR[0-9]+$|^PR[0-9]+$", names(dt), value = TRUE)
if (length(pr_cols) == 0) {
  cat("  [WARN] No procedure columns found.\n")
  dt[, is_delivery_pcs := FALSE]
} else {
  cat(sprintf("  Procedure columns: %d (%s..%s)\n", length(pr_cols),
              pr_cols[1], pr_cols[length(pr_cols)]))
  # Vectorized check: ANY procedure column contains a delivery PCS code
  pcs_mat <- as.matrix(dt[, ..pr_cols])
  dt[, is_delivery_pcs := apply(pcs_mat, 1, function(row) {
    any(row %in% delivery_pcs_codes)
  })]
}

dt[, is_delivery := is_delivery_drg | is_delivery_pcs]
n_deliv <- sum(dt$is_delivery)
cat(sprintf("  Delivery hospitalizations: %d (%.1f%% of female-age-filtered)\n",
            n_deliv, 100 * n_deliv / nrow(dt)))

dt_deliv <- dt[is_delivery == TRUE]
dt_deliv[, c("is_delivery_drg", "is_delivery_pcs", "is_delivery") := NULL]
dt_deliv[, year_actual := year]

# --- Merge hospital characteristics -----------------------------------
hosp_candidates <- list.files(raw_dir,
  pattern = sprintf("NIS_%d_Hospital.*\\.(sas7bdat|csv|asc)$", year),
  full.names = TRUE, ignore.case = TRUE)
if (length(hosp_candidates) > 0) {
  hosp_file <- hosp_candidates[[1]]
  cat(sprintf("[%s] Loading hospital file: %s\n", format(Sys.time()), hosp_file))
  if (grepl("\\.sas7bdat$", hosp_file, ignore.case = TRUE)) {
    hosp <- as.data.table(haven::read_sas(hosp_file))
  } else {
    hosp <- data.table::fread(hosp_file)
  }
  setnames(hosp, toupper(names(hosp)))
  hosp_key <- intersect(c("HOSP_NIS", "HOSPID"), names(hosp))[1]
  if (is.na(hosp_key)) stop("No HOSP_NIS/HOSPID key in hospital file")
  cat(sprintf("  Hospital rows: %d, key: %s\n", nrow(hosp), hosp_key))
  dt_deliv <- merge(dt_deliv, hosp, by = hosp_key, all.x = TRUE)
}

# --- Save -------------------------------------------------------------
out_path <- file.path(out_dir, sprintf("nis_%d_deliveries.rds", year))
saveRDS(dt_deliv, out_path)
cat(sprintf("[%s] Saved %d delivery rows to %s\n",
            format(Sys.time()), nrow(dt_deliv), out_path))
