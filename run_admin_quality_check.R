# =============================================================
# Daily administrative data quality check (no app needed)
# =============================================================
# Run from the portal folder:
#
#   Rscript run_admin_quality_check.R
#       checks the repository, output/AFRO_admin_data_repository.rds
#   Rscript run_admin_quality_check.R path/to/AFRO_admin_data.xlsx
#       checks any admin data file (.rds or .xlsx), for example the file HQ downloads
#   Rscript run_admin_quality_check.R --country=Nigeria
#       limits the report to one country
#   Rscript run_admin_quality_check.R --cv-ceiling=150 --pop-factor=3
#       changes the thresholds (coverage ceiling in %, target population jump factor)
#   Rscript run_admin_quality_check.R --build-geo=path/to/africa_districts_simplified.rds
#       rebuilds input/geo_reference.rds from the district shapefile (needs the sf package)
#
# Writes   output/quality/admin_data_quality_report_<date>.xlsx
#          (Overview, By check, By country, Issues, Suggested fixes)
# and prints a short summary. Nothing in the repository is changed.
# =============================================================

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[1]) else default
}
files <- args[!grepl("^--", args)]

source("admin_quality_checks.R")

geo_path <- file.path("input", "geo_reference.rds")
build <- opt("build-geo")
if (!is.null(build)) {
  g <- aq_build_geo_reference(build, geo_path)
  cat("Geography reference written:", geo_path, "-", nrow(g), "districts in", length(unique(g$country)), "countries\n")
  if (!length(files) && is.null(opt("country"))) quit(save = "no")
}

path <- if (length(files)) files[1] else file.path("output", "AFRO_admin_data_repository.rds")
if (!file.exists(path)) stop("File not found: ", path)
cat("Reading", path, "...\n")
df <- if (grepl("\\.rds$", path, ignore.case = TRUE)) readRDS(path) else readxl::read_excel(path, guess_max = 20000)
df <- as.data.frame(df)
if (!"ROW_ID" %in% names(df)) df$ROW_ID <- seq_len(nrow(df))

ctry <- opt("country")
if (!is.null(ctry)) df <- df[aq_country_key(df$Country) == aq_country_key(ctry), , drop = FALSE]
cat(nrow(df), "records\n")

geo <- aq_load_geo_reference(geo_path)
if (is.null(geo)) cat("Note: input/geo_reference.rds not found - the province / country check is skipped.\n")

cfg <- aq_config(cv_ceiling = as.numeric(opt("cv-ceiling", 150)) / 100,
                 pop_factor = as.numeric(opt("pop-factor", 3)))
res <- aq_run_checks(df, geo, cfg)

n_of <- function(sv) length(unique(res$issues$idx[res$issues$severity == sv]))
cat(sprintf("\nChecked %s records in %s s\n  Errors:   %s records\n  Warnings: %s records\n  Info:     %s records\n\n",
            format(res$n_rows, big.mark = ","), res$seconds, format(n_of("Error"), big.mark = ","),
            format(n_of("Warning"), big.mark = ","), format(n_of("Info"), big.mark = ",")))
print(res$by_check, row.names = FALSE)

dir.create(file.path("output", "quality"), showWarnings = FALSE, recursive = TRUE)
out <- file.path("output", "quality", paste0("admin_data_quality_report_", format(Sys.Date(), "%Y-%m-%d"),
                                             if (!is.null(ctry)) paste0("_", gsub(" ", "_", ctry)) else "", ".xlsx"))
writexl::write_xlsx(aq_report_sheets(res), out)
cat("\nReport written:", out, "\n")
