# Study 01 — Harmonize stratifiers and pool across years.
#
# Inputs:
#   data/derived/nis_YYYY_deliveries_smm_coded.rds  (for each year in 2017:2021)
#   data/raw/reference/kff_medicaid_expansion.csv
#
# Output:
#   data/derived/analysis_table.rds   (pooled across years, all stratifiers
#                                       coded per PRE_REGISTRATION.md §4)
#
# Stratifiers built (per pre-reg §4):
#   - race (NH White / NH Black / Hispanic / NH AAPI / NH AIAN / Other)
#   - insurance (Medicaid / Private / Self-pay-uninsured / Other)
#   - parity (continuous if codeable; tertile fallback)
#   - hospital bed size (Small / Medium / Large)
#   - hospital urban/rural (NCHS 6-level; HCUP 4-level fallback)
#   - maternal age group (12-17 / 18-24 / 25-29 / 30-34 / 35-39 / 40+)
#   - comorbidities (chronic_htn, preexisting_dm, prior_cesarean)
#   - state Medicaid expansion (TRUE/FALSE at delivery year)
#
# Run: Rscript scripts/03_harmonize_stratifiers.R

user_lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R/win-library/4.6")
.libPaths(c(user_lib, .libPaths()))

for (pkg in c("data.table")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg, lib = user_lib)
}
library(data.table)

repo <- "D:/Women's Health/Study_01_Maternal_Mortality"
years <- 2017:2021
deriv <- file.path(repo, "data/derived")

# --- Load all years, pool ---------------------------------------------
dt_list <- list()
for (y in years) {
  f <- file.path(deriv, sprintf("nis_%d_deliveries_smm_coded.rds", y))
  if (!file.exists(f)) {
    cat(sprintf("[WARN] missing %s — skipping year %d\n", f, y))
    next
  }
  dt_list[[as.character(y)]] <- readRDS(f)
}
if (length(dt_list) == 0) stop("No year files found.")
dt <- rbindlist(dt_list, use.names = TRUE, fill = TRUE)
cat(sprintf("Pooled rows: %d across %d years\n", nrow(dt), length(dt_list)))

# --- Race / ethnicity ------------------------------------------------
# NIS RACE coding (verify per year via NIS_YYYY_Description_of_Data_Elements.pdf):
#   1 = White (NH)
#   2 = Black (NH)
#   3 = Hispanic
#   4 = Asian or Pacific Islander (NH)
#   5 = Native American (NH)
#   6 = Other
dt[, race := fcase(
  RACE == 1L, "NH White",
  RACE == 2L, "NH Black",
  RACE == 3L, "Hispanic",
  RACE == 4L, "NH AAPI",
  RACE == 5L, "NH AIAN",
  RACE == 6L, "Other / Multiracial",
  default = NA_character_
)]
dt[, race := factor(race, levels = c("NH White", "NH Black", "Hispanic",
                                     "NH AAPI", "NH AIAN", "Other / Multiracial"))]

# --- Insurance / payer ------------------------------------------------
# NIS PAY1 coding (1=Medicare, 2=Medicaid, 3=Private, 4=Self-pay,
# 5=No charge, 6=Other). Medicare for delivery hospitalizations is rare
# (mostly disability or end-stage renal), grouped into "Other" for analysis.
dt[, insurance := fcase(
  PAY1 == 2L, "Medicaid",
  PAY1 == 3L, "Private",
  PAY1 == 4L, "Self-pay / Uninsured",
  PAY1 %in% c(1L, 5L, 6L), "Other (Medicare/no-charge/military/IHS)",
  default = NA_character_
)]
dt[, insurance := factor(insurance, levels = c("Private", "Medicaid",
                                               "Self-pay / Uninsured",
                                               "Other (Medicare/no-charge/military/IHS)"))]

# --- Age group --------------------------------------------------------
dt[, age_group := cut(AGE,
  breaks = c(12, 17, 24, 29, 34, 39, 55),
  labels = c("12-17", "18-24", "25-29", "30-34", "35-39", "40+"),
  include.lowest = TRUE, right = TRUE)]

# --- Hospital bed size -----------------------------------------------
# NIS HOSP_BEDSIZE: 1 = Small, 2 = Medium, 3 = Large
dt[, bed_size := factor(fcase(
  HOSP_BEDSIZE == 1L, "Small",
  HOSP_BEDSIZE == 2L, "Medium",
  HOSP_BEDSIZE == 3L, "Large",
  default = NA_character_
), levels = c("Small", "Medium", "Large"))]

# --- Urban/rural -----------------------------------------------------
# Use NCHS 6-level (HOSP_NCHS_URCAT) if available; else HCUP 4-level (HOSP_URCAT4)
ncols <- names(dt)
if ("HOSP_NCHS_URCAT" %in% ncols) {
  dt[, urban_rural := factor(fcase(
    HOSP_NCHS_URCAT == 1L, "Large Central Metro",
    HOSP_NCHS_URCAT == 2L, "Large Fringe Metro",
    HOSP_NCHS_URCAT == 3L, "Medium Metro",
    HOSP_NCHS_URCAT == 4L, "Small Metro",
    HOSP_NCHS_URCAT == 5L, "Micropolitan",
    HOSP_NCHS_URCAT == 6L, "Non-core",
    default = NA_character_
  ), levels = c("Large Central Metro", "Large Fringe Metro",
                "Medium Metro", "Small Metro",
                "Micropolitan", "Non-core"))]
} else if ("HOSP_URCAT4" %in% ncols) {
  cat("[WARN] HOSP_NCHS_URCAT missing; using HCUP 4-level fallback\n")
  dt[, urban_rural := factor(fcase(
    HOSP_URCAT4 == 1L, "Large Metro",
    HOSP_URCAT4 == 2L, "Small Metro",
    HOSP_URCAT4 == 3L, "Micropolitan",
    HOSP_URCAT4 == 4L, "Non-core",
    default = NA_character_
  ), levels = c("Large Metro", "Small Metro", "Micropolitan", "Non-core"))]
} else {
  cat("[WARN] No urban-rural classification column found.\n")
  dt[, urban_rural := NA_character_]
}

# --- Parity (continuous if codeable; tertile fallback) ----------------
# NIS doesn't have a direct parity variable. Extract from ICD-10 codes:
#   Z3A.xx — weeks of gestation (current pregnancy)
#   O09.x — high-risk pregnancy codes that sometimes encode parity
#   Z64.0x — counseling on parity
# Most reliable parity proxy: count past pregnancies via O09.x subcodes.
# For v1 fallback, use the presence of "elderly multigravida" (O09.5x) +
# "supervision of high parity" (O09.3x) as binary multiparous indicators,
# combined with primigravida indicators (O09.4x supervision of young primigravida).
# This gives a coarse tertile but NOT continuous.

dx_cols <- grep("^I10_DX[0-9]+$|^DX[0-9]+$", names(dt), value = TRUE)
dx_mat <- as.matrix(dt[, ..dx_cols])
# Normalize (strip dots, uppercase)
dx_mat <- toupper(gsub("\\.", "", dx_mat))

has_code_prefix <- function(mat, prefix) {
  rowSums(matrix(startsWith(mat, prefix), nrow = nrow(mat))) > 0
}

# Primigravida indicators
is_primigravida <- has_code_prefix(dx_mat, "O094") |
                   has_code_prefix(dx_mat, "Z6402") |
                   has_code_prefix(dx_mat, "Z3A14")   # first pregnancy
# Multiparous (3+)
is_high_parity <- has_code_prefix(dx_mat, "O093") |
                  has_code_prefix(dx_mat, "Z6404")
# Elderly multigravida (≥35 + multiparous)
is_elderly_multi <- has_code_prefix(dx_mat, "O095")

dt[, parity_tertile := fcase(
  is_primigravida, "0 (Nulliparous)",
  is_high_parity | is_elderly_multi, "3+ (Grand-multiparous)",
  default = "1-2 (Multiparous)"   # default for documented deliveries
)]
dt[, parity_tertile := factor(parity_tertile,
  levels = c("0 (Nulliparous)", "1-2 (Multiparous)", "3+ (Grand-multiparous)"))]

cat("\nParity tertile distribution:\n")
print(table(dt$parity_tertile, useNA = "always"))
cat("[NOTE] Parity extraction from ICD codes is coarse. Continuous gravidity\n",
    "      not extractable from NIS without supplemental files. Tertile is\n",
    "      the operational definition per pre-reg fallback.\n", sep = "")

# --- Comorbidities (3 separate binary) --------------------------------
# Chronic hypertension: I10.x (essential HTN), O10.x (pre-existing HTN
# complicating pregnancy), I11-I13.x
is_chronic_htn <- has_code_prefix(dx_mat, "I10") |
                  has_code_prefix(dx_mat, "O10") |
                  has_code_prefix(dx_mat, "I11") |
                  has_code_prefix(dx_mat, "I12") |
                  has_code_prefix(dx_mat, "I13")
dt[, chronic_htn := as.integer(is_chronic_htn)]

# Pre-existing diabetes: E10-E13 (DM), O24.0-O24.3 (DM in pregnancy,
# pre-existing). NOT O24.4 (gestational diabetes).
is_preexisting_dm <- has_code_prefix(dx_mat, "E10") |
                     has_code_prefix(dx_mat, "E11") |
                     has_code_prefix(dx_mat, "E12") |
                     has_code_prefix(dx_mat, "E13") |
                     has_code_prefix(dx_mat, "O240") |
                     has_code_prefix(dx_mat, "O241") |
                     has_code_prefix(dx_mat, "O242") |
                     has_code_prefix(dx_mat, "O243")
dt[, preexisting_dm := as.integer(is_preexisting_dm)]

# Prior cesarean: O34.21 (maternal care for scar from previous cesarean),
# Z3A.xx with delivery via cesarean (less specific). Primary signal: O34.21.
is_prior_cs <- has_code_prefix(dx_mat, "O3421")
dt[, prior_cesarean := as.integer(is_prior_cs)]

# --- State Medicaid expansion -----------------------------------------
kff <- fread(file.path(repo, "data/raw/reference/kff_medicaid_expansion.csv"))
# Build expansion flag by (state, year)
kff[, implementation_year := as.integer(format(as.Date(implementation_date), "%Y"))]

# NIS HOSP_STATE: 2-letter abbreviation in some years, FIPS in others.
# Check what we have.
state_col <- intersect(c("HOSP_STATE", "HOSPST"), names(dt))[1]
if (is.na(state_col)) {
  cat("[WARN] No state column; medicaid_expansion will be NA\n")
  dt[, medicaid_expansion := NA_integer_]
} else {
  state_kff <- kff$state_abbr
  exp_year <- setNames(kff$implementation_year, state_kff)
  dt[, hosp_state_clean := as.character(get(state_col))]
  dt[, medicaid_expansion := as.integer(
    !is.na(exp_year[hosp_state_clean]) &
    year_actual >= exp_year[hosp_state_clean]
  )]
}

# --- Final analysis table --------------------------------------------
keep_cols <- c("year_actual", "AGE", "age_group", "race", "insurance",
               "parity_tertile",
               "bed_size", "urban_rural", "medicaid_expansion",
               "chronic_htn", "preexisting_dm", "prior_cesarean",
               state_col,
               grep("^smm_", names(dt), value = TRUE),
               grep("^DISCWT|^TRENDWT", names(dt), value = TRUE))   # NIS weights
keep_cols <- keep_cols[!is.na(keep_cols) & keep_cols %in% names(dt)]
analysis_dt <- dt[, ..keep_cols]

cat(sprintf("\nAnalysis table: %d rows × %d cols\n", nrow(analysis_dt),
            ncol(analysis_dt)))

# Stratifier completeness
for (col in c("race", "insurance", "age_group", "bed_size", "urban_rural",
              "parity_tertile", "medicaid_expansion")) {
  if (col %in% names(analysis_dt)) {
    n_missing <- sum(is.na(analysis_dt[[col]]))
    cat(sprintf("  %s: %d (%.2f%%) missing\n", col, n_missing,
                100 * n_missing / nrow(analysis_dt)))
  }
}

out_file <- file.path(deriv, "analysis_table.rds")
saveRDS(analysis_dt, out_file)
cat(sprintf("\nSaved analysis table to %s\n", out_file))
