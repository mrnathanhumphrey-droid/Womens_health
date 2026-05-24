# Study 03 — Pull CDC WONDER maternal mortality + natality + linked birth-death.
#
# Uses CDC WONDER's XML API (https://wonder.cdc.gov/wonder/help/WONDER-API.html).
# No registration; no DUA. Public access.
#
# Datasets pulled:
#   D77 — Underlying Cause of Death (1999-2020) [pre-Dobbs portion]
#   D157 — Multiple Cause of Death (2018-current) [carries through 2023+]
#   D66 — Natality (denominator)
#   D69 — Linked Birth/Infant Death (for pregnancy-associated death broader def)
#
# Filters:
#   ICD-10: O00-O99 + A34 (maternal causes)
#   Female, age 10-55
#   Year 2017 - latest available
#
# Suppressed cells (<10 deaths) are kept as NA per CDC convention.
#
# Output:
#   data/raw/wonder/mortality_county_year_race_age.csv
#   data/raw/wonder/mortality_state_year_race_age.csv
#   data/raw/wonder/natality_county_year_race_age.csv
#   data/raw/wonder/natality_state_year_race_age.csv
#   data/raw/wonder/pregnancy_associated_death_state_year.csv
#
# Run: Rscript scripts/01_pull_wonder.R [outcome] [granularity]
#       outcome: "mortality" | "natality" | "linked_pad"
#       granularity: "county" | "state"

user_lib <- file.path(Sys.getenv("LOCALAPPDATA"), "R/win-library/4.6")
.libPaths(c(user_lib, .libPaths()))
options(repos = c(CRAN = "https://cloud.r-project.org"))

for (pkg in c("httr", "xml2", "data.table", "stringr")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg, lib = user_lib)
}
library(httr); library(xml2); library(data.table); library(stringr)

args <- commandArgs(trailingOnly = TRUE)
outcome     <- if (length(args) >= 1) args[[1]] else "mortality"
granularity <- if (length(args) >= 2) args[[2]] else "state"
stopifnot(outcome %in% c("mortality", "natality", "linked_pad"))
stopifnot(granularity %in% c("county", "state"))

repo <- "D:/Women's Health/Study_03_Roe_Fall_Shock"
out_dir <- file.path(repo, "data/raw/wonder")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# --- WONDER dataset IDs -----------------------------------------------
DATASET <- switch(outcome,
  "mortality"  = "D157",  # Multiple Cause of Death 2018-current
  "natality"   = "D66",   # Natality
  "linked_pad" = "D69"    # Linked Birth/Infant Death
)

# --- Build query XML --------------------------------------------------
# WONDER API expects a request XML following their schema. Each
# dataset has different parameter codes. Below is the mortality variant;
# natality and linked-PAD use different codes per CDC documentation.

build_mortality_xml <- function(years, granularity) {
  group_by_lines <- if (granularity == "county") {
    '<value>D157.V1-level1</value>   <!-- Year -->
     <value>D157.V9</value>          <!-- County -->
     <value>D157.V19</value>         <!-- Race/Ethnicity (single race) -->
     <value>D157.V5</value>          <!-- Five-year age groups -->'
  } else {
    '<value>D157.V1-level1</value>
     <value>D157.V7</value>          <!-- State -->
     <value>D157.V19</value>
     <value>D157.V5</value>'
  }

  sprintf('<?xml version="1.0" encoding="utf-8"?>
<request-parameters>
  <parameter><name>B_1</name><value>D157.V1-level1</value></parameter>
  <parameter><name>B_2</name><value>%s</value></parameter>
  <parameter><name>O_title</name><value>Maternal mortality (O00-O99 + A34)</value></parameter>

  <!-- Multiple Cause of Death: ICD-10 O00-O99 + A34 -->
  <parameter><name>F_D157.V2</name><value>O00</value><value>O01</value><value>O02</value>
    <value>O03</value><value>O04</value><value>O05</value><value>O06</value><value>O07</value>
    <value>O08</value><value>O09</value><value>O10</value><value>O11</value><value>O12</value>
    <value>O13</value><value>O14</value><value>O15</value><value>O16</value><value>O20</value>
    <value>O21</value><value>O22</value><value>O23</value><value>O24</value><value>O25</value>
    <value>O26</value><value>O28</value><value>O29</value><value>O30</value><value>O31</value>
    <value>O32</value><value>O33</value><value>O34</value><value>O35</value><value>O36</value>
    <value>O40</value><value>O41</value><value>O42</value><value>O43</value><value>O44</value>
    <value>O45</value><value>O46</value><value>O47</value><value>O48</value><value>O60</value>
    <value>O61</value><value>O62</value><value>O63</value><value>O64</value><value>O65</value>
    <value>O66</value><value>O67</value><value>O68</value><value>O69</value><value>O70</value>
    <value>O71</value><value>O72</value><value>O73</value><value>O74</value><value>O75</value>
    <value>O80</value><value>O81</value><value>O82</value><value>O83</value><value>O84</value>
    <value>O85</value><value>O86</value><value>O87</value><value>O88</value><value>O89</value>
    <value>O90</value><value>O91</value><value>O92</value><value>O94</value><value>O95</value>
    <value>O96</value><value>O97</value><value>O98</value><value>O99</value>
    <value>A34</value></parameter>

  <!-- Female only -->
  <parameter><name>F_D157.V6</name><value>F</value></parameter>

  <!-- Years filter -->
  <parameter><name>F_D157.V1-level1</name>%s</parameter>

  <!-- Age 10-55 (5-year groups: 10-14, 15-19, 20-24, 25-29, 30-34, 35-39, 40-44, 45-49, 50-54) -->
  <parameter><name>F_D157.V5</name>
    <value>10-14</value><value>15-19</value><value>20-24</value>
    <value>25-29</value><value>30-34</value><value>35-39</value>
    <value>40-44</value><value>45-49</value><value>50-54</value></parameter>

  <!-- Output: deaths + population, grouped -->
  <parameter><name>M_1</name><value>D157.M1</value></parameter>  <!-- Deaths -->

  <!-- Group-by -->
  <parameter><name>B_1</name>%s</parameter>

  <!-- Show suppressed cells (treated as NA in output) -->
  <parameter><name>VM_D157.M6_D157.V10</name><value>*All*</value></parameter>
  <parameter><name>O_show_totals</name><value>false</value></parameter>
  <parameter><name>O_show_zeros</name><value>true</value></parameter>
  <parameter><name>O_show_suppressed</name><value>true</value></parameter>

  <!-- Accept the data use restrictions -->
  <parameter><name>action-Send</name><value>Send</value></parameter>
</request-parameters>',
  DATASET,
  paste(sprintf("<value>%d</value>", years), collapse = ""),
  group_by_lines)
}

# Similar builders for natality and linked-PAD would go here.
# For brevity and to keep this script focused, we implement mortality
# fully and stub natality + linked-PAD which will be filled in if/when
# we hit them in execution.

if (outcome != "mortality") {
  stop("Natality (D66) and Linked-PAD (D69) XML builders not yet implemented. ",
       "TODO: add per-dataset XML construction matching their parameter schemas. ",
       "For now, recommend pulling natality manually from wonder.cdc.gov and ",
       "placing CSV in data/raw/wonder/natality_*.csv.")
}

# --- Year-by-year pull (WONDER caps per-query rows) ------------------
WONDER_URL <- sprintf("https://wonder.cdc.gov/controller/datarequest/%s", DATASET)

pull_year_chunk <- function(years_chunk) {
  body <- build_mortality_xml(years_chunk, granularity)
  cat(sprintf("[%s] POSTing WONDER %s, years %s, granularity=%s\n",
              format(Sys.time()), DATASET,
              paste(range(years_chunk), collapse = "-"), granularity))
  resp <- POST(
    WONDER_URL,
    body = list(request_xml = body, accept_datause_restrictions = "true"),
    encode = "form",
    add_headers(`User-Agent` = "Womens-Health-Study03/0.1"),
    timeout(180)
  )
  if (status_code(resp) != 200) {
    cat(sprintf("  HTTP %d. Body preview: %s\n", status_code(resp),
                substr(content(resp, "text"), 1, 500)))
    return(NULL)
  }
  # WONDER returns HTML or XML wrapping a tab-delimited block
  txt <- content(resp, "text", encoding = "UTF-8")
  # Heuristic: find the data table block (tab-separated, starts with header)
  lines <- strsplit(txt, "\n")[[1]]
  # WONDER table block typically starts after "Notes" lines with header row
  # containing the grouping columns; parsing brittle without inspection.
  # For now, save the raw payload to disk for inspection and return NULL.
  raw_path <- file.path(out_dir, sprintf("raw_%s_%s_%d-%d.html",
                                         outcome, granularity,
                                         min(years_chunk), max(years_chunk)))
  writeLines(txt, raw_path)
  cat(sprintf("  Saved raw response to %s (%d bytes). Parse downstream.\n",
              raw_path, nchar(txt)))
  return(invisible(NULL))
}

YEARS <- 2017:2024
chunks <- split(YEARS, ceiling(seq_along(YEARS) / 2))   # 2-year chunks
for (ch in chunks) pull_year_chunk(ch)

cat("\nNote: WONDER API parsing is brittle without sample response in hand.\n",
    "If raw payloads above contain the expected tab-delimited data table,\n",
    "extract it with regex in a follow-up. If WONDER is throwing errors or\n",
    "redirecting to the interactive UI, fall back to manual CSV export from\n",
    "wonder.cdc.gov and place files in data/raw/wonder/.\n", sep = "")
