# Study 01 — Code CDC's 21 SMM indicators per delivery hospitalization.
#
# Inputs:
#   data/derived/nis_YYYY_deliveries.rds  (from 01_define_population.R)
#   data/raw/reference/cdc_smm_21_indicators.csv
#
# Output:
#   data/derived/nis_YYYY_deliveries_smm_coded.rds
#     - One row per delivery
#     - 21 binary columns: smm_01_acute_mi ... smm_21_ventilation
#     - 2 composite columns:
#         smm_composite_excl_trans (CDC primary)
#         smm_composite_incl_trans (CDC secondary)
#
# Run: Rscript scripts/02_code_smm_indicators.R <year>

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) stop("Usage: Rscript 02_code_smm_indicators.R <year>")
year <- as.integer(args[[1]])

user_lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R/win-library/4.6")
.libPaths(c(user_lib, .libPaths()))

for (pkg in c("data.table", "stringr")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg, lib = user_lib)
}
library(data.table)
library(stringr)

repo <- "D:/Women's Health/Study_01_Maternal_Mortality"
deliv_file <- file.path(repo, "data/derived", sprintf("nis_%d_deliveries.rds", year))
codes_file <- file.path(repo, "data/raw/reference/cdc_smm_21_indicators.csv")
out_file   <- file.path(repo, "data/derived",
                        sprintf("nis_%d_deliveries_smm_coded.rds", year))

dt <- readRDS(deliv_file)
codes <- fread(codes_file)
cat(sprintf("Loaded %d delivery rows; %d SMM indicators to code\n",
            nrow(dt), nrow(codes)))

# --- Helper: parse code spec into vector of code patterns -------------
# CDC code specs use:
#   "I21.xx"   → match any code starting with I21
#   "I50.20"   → match exact code I50.20
#   "I50.810-I50.814" → match range
#   "I60-I68.xx" → match prefix range from I60 to I68
# NIS stores diagnosis codes without dots (e.g., I2110 not I21.10),
# so we normalize both sides by stripping dots.

normalize_code <- function(x) gsub("\\.", "", x)

expand_code_spec <- function(spec_str) {
  if (is.na(spec_str) || spec_str == "") return(character(0))
  parts <- strsplit(spec_str, ";\\s*")[[1]]
  out <- character(0)
  for (p in parts) {
    p <- trimws(p)
    if (grepl("-", p) && !startsWith(p, "-")) {
      # Range: e.g., "I50.810-I50.814" or "I60-I68.xx"
      pieces <- strsplit(p, "-")[[1]]
      lo <- trimws(pieces[1]); hi <- trimws(pieces[2])
      lo_n <- normalize_code(gsub("x", "", lo, ignore.case = TRUE))
      hi_n <- normalize_code(gsub("x", "", hi, ignore.case = TRUE))
      # For simple numeric ranges, enumerate. Otherwise, fall back to prefix.
      if (nchar(lo_n) == nchar(hi_n) && grepl("^[A-Z]", lo_n)) {
        prefix_len <- max(nchar(lo_n), nchar(hi_n)) - 1
        prefixes <- substr(lo_n, 1, prefix_len)
        out <- c(out, paste0("^", prefixes))
      } else {
        out <- c(out, paste0("^", lo_n))
      }
    } else if (grepl("x", p, ignore.case = TRUE)) {
      # Prefix wildcard: "I21.xx" → starts with I21
      prefix <- normalize_code(gsub("x", "", p, ignore.case = TRUE))
      out <- c(out, paste0("^", prefix))
    } else {
      # Exact code
      out <- c(out, paste0("^", normalize_code(p), "$"))
    }
  }
  out
}

# --- Find diagnosis and procedure columns -----------------------------
dx_cols <- grep("^I10_DX[0-9]+$|^DX[0-9]+$", names(dt), value = TRUE)
pr_cols <- grep("^I10_PR[0-9]+$|^PR[0-9]+$", names(dt), value = TRUE)
cat(sprintf("  Diagnosis cols: %d, procedure cols: %d\n",
            length(dx_cols), length(pr_cols)))

# Materialize matrices of all DX / PR codes per row
dx_mat <- as.matrix(dt[, ..dx_cols])
pr_mat <- as.matrix(dt[, ..pr_cols])
# Normalize: strip dots and pad to consistent
dx_norm <- apply(dx_mat, c(1, 2), normalize_code)
pr_norm <- apply(pr_mat, c(1, 2), normalize_code)

# --- For each indicator, set a binary column --------------------------
for (i in seq_len(nrow(codes))) {
  ind <- codes[i]
  col_name <- sprintf("smm_%02d_%s", ind$indicator_id,
                      tolower(gsub("[^a-zA-Z0-9]+", "_", ind$indicator_name)))
  col_name <- gsub("_+", "_", col_name)
  col_name <- gsub("_$", "", col_name)

  dx_patterns <- expand_code_spec(ind$icd10cm_codes)
  pr_patterns <- expand_code_spec(ind$icd10pcs_codes)

  # Diagnosis match: any DX cell matches any pattern
  dx_hit <- rep(FALSE, nrow(dt))
  if (length(dx_patterns) > 0) {
    big_dx <- paste(dx_patterns, collapse = "|")
    dx_hit <- rowSums(matrix(grepl(big_dx, dx_norm), nrow = nrow(dt))) > 0
  }
  # Procedure match
  pr_hit <- rep(FALSE, nrow(dt))
  if (length(pr_patterns) > 0) {
    big_pr <- paste(pr_patterns, collapse = "|")
    pr_hit <- rowSums(matrix(grepl(big_pr, pr_norm), nrow = nrow(dt))) > 0
  }

  dt[[col_name]] <- as.integer(dx_hit | pr_hit)
  n_hits <- sum(dt[[col_name]])
  cat(sprintf("  [%2d] %-40s hits = %d (%.3f%%)\n",
              ind$indicator_id, col_name, n_hits, 100 * n_hits / nrow(dt)))
}

# --- Composite outcomes (CDC convention) ------------------------------
smm_cols <- grep("^smm_[0-9]+_", names(dt), value = TRUE)
transfusion_col <- grep("^smm_09_", names(dt), value = TRUE)
non_trans_cols <- setdiff(smm_cols, transfusion_col)

dt[, smm_composite_excl_trans := as.integer(rowSums(.SD) > 0),
   .SDcols = non_trans_cols]
dt[, smm_composite_incl_trans := as.integer(rowSums(.SD) > 0),
   .SDcols = smm_cols]

cat(sprintf("\nComposite SMM (excl transfusion): %d events (%.2f%%)\n",
            sum(dt$smm_composite_excl_trans),
            100 * mean(dt$smm_composite_excl_trans)))
cat(sprintf("Composite SMM (incl transfusion): %d events (%.2f%%)\n",
            sum(dt$smm_composite_incl_trans),
            100 * mean(dt$smm_composite_incl_trans)))

saveRDS(dt, out_file)
cat(sprintf("\nSaved %d rows × %d cols (%d SMM indicators + 2 composites) to %s\n",
            nrow(dt), ncol(dt), length(smm_cols), out_file))
