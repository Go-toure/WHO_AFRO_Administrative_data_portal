# =============================================================
# WHO AFRO - Administrative data quality checks
# =============================================================
# One set of checks, used in three places:
#   1. the "Data Quality" tab of the Administrative Data Portal (admin_data_portal.R)
#   2. the upload gate (rows with an Error are refused, the rest is appended and flagged)
#   3. the daily command line report (run_admin_quality_check.R)
#
# Main entry point:   aq_run_checks(df, geo_ref = NULL, config = aq_config())
# It returns a list; $issues has one row per problem found (a record can have several).
#
# Severity
#   Error    must be fixed before the record is used (wrong geography, missing key field,
#            impossible date or number). Uploads containing errors are refused.
#   Warning  needs a human look: it may be a real problem or a genuine exception
#            (coverage above the ceiling, target population jump, report date before the SIA ...).
#   Info     good practice (combined co-administration record, vaccine name spelling ...).
#
# Needs only dplyr and (optionally) lubridate. No shapefile is needed at run time: the geography
# check reads a small lookup, input/geo_reference.rds (country / province / district).
# =============================================================

suppressPackageStartupMessages(library(dplyr))

# base R has this operator from 4.4; older R versions (and shinyapps.io) may not
if (!exists("%||%", mode = "function")) `%||%` <- function(a, b) if (is.null(a)) b else a

# ---------------------------------------------------------------
# Settings (all can be changed in the portal, or passed to aq_run_checks)
# ---------------------------------------------------------------
aq_config <- function(cv_ceiling      = 1.5,    # coverage above this is flagged (HQ proposal: 150%)
                      cv_high         = 1.2,    # coverage above this (but below the ceiling) is a softer warning
                      cv_recalc_tol   = 0.02,   # reported vs recalculated coverage may differ by this much (2 points)
                      pop_factor      = 3,      # target population this many times above/below the district median
                      pop_min_rounds  = 3,      # a district needs this many campaign dates to be compared
                      report_late_days = 365,   # report date this long after the SIA start is flagged
                      min_sia_year    = 2015) {
  list(cv_ceiling = cv_ceiling, cv_high = cv_high, cv_recalc_tol = cv_recalc_tol,
       pop_factor = pop_factor, pop_min_rounds = pop_min_rounds,
       report_late_days = report_late_days, min_sia_year = min_sia_year)
}

AQ_CHECKS <- c(
  missing_key       = "Missing key field",
  country_name      = "Country name not standard",
  geo_province      = "Province does not belong to the country",
  geo_unknown       = "Province not found in the geography reference",
  sia_date          = "SIA date missing or implausible",
  report_date       = "Report date before the SIA start / in the future",
  negative_number   = "Negative number",
  target_missing    = "Target population missing or zero",
  target_gt_total   = "Target population larger than total population",
  coverage_ceiling  = "Coverage above the ceiling",
  coverage_high     = "Coverage high (verify)",
  coverage_mismatch = "Reported coverage differs from vaccinated / target",
  target_jump       = "Target population jump between rounds",
  coadmin_mixed     = "Co-administration reported both combined and separate",
  coadmin_combined  = "Combined co-administration record",
  coadmin_identical = "Identical figures for both vaccines",
  vaccine_spelling  = "Vaccine type spelling",
  duplicate_key     = "Duplicate record"
)

AQ_SEVERITY_LEVELS <- c("Error", "Warning", "Info")

# ---------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------
aq_norm <- function(x) {
  x <- iconv(as.character(x), to = "ASCII//TRANSLIT", sub = "")
  x <- toupper(x)
  x <- gsub("[^A-Z0-9]+", " ", x)
  trimws(gsub("\\s+", " ", x))
}

# Spellings seen in the repository -> the name used in the geography reference
AQ_COUNTRY_ALIASES <- c(
  "CAMEROUN" = "CAMEROON",
  "REPUBLIQUE CENTRAFRIQUE" = "CENTRAL AFRICAN REPUBLIC",
  "REPUBLIQUE CENTRAFRICAINE" = "CENTRAL AFRICAN REPUBLIC",
  "TANZANIA" = "UNITED REPUBLIC OF TANZANIA",
  "TCHAD" = "CHAD",
  "THE GAMBIA" = "GAMBIA",
  "SWAZILAND" = "ESWATINI",
  "CABO VERDE" = "CABO VERDE", "CAPE VERDE" = "CABO VERDE",
  "COTE DIVOIRE" = "COTE D IVOIRE", "IVORY COAST" = "COTE D IVOIRE",
  "DRC" = "DEMOCRATIC REPUBLIC OF THE CONGO",
  "CONGO DEMOCRATIC REPUBLIC" = "DEMOCRATIC REPUBLIC OF THE CONGO",
  "REPUBLIC OF CONGO" = "CONGO", "REPUBLIC OF THE CONGO" = "CONGO",
  "GUINEA BISSAU" = "GUINEA BISSAU", "GUINEE BISSAU" = "GUINEA BISSAU",
  "GUINEE" = "GUINEA", "GUINEE EQUATORIALE" = "EQUATORIAL GUINEA"
)
aq_country_key <- function(x) {
  k <- aq_norm(x)
  hit <- k %in% names(AQ_COUNTRY_ALIASES)
  k[hit] <- unname(AQ_COUNTRY_ALIASES[k[hit]])
  k
}

aq_as_date <- function(x) {
  if (inherits(x, "Date")) return(x)
  if (inherits(x, "POSIXt")) return(as.Date(x))
  if (is.numeric(x)) return(as.Date(x, origin = "1899-12-30"))   # Excel serial number
  x <- as.character(x)
  out <- suppressWarnings(as.Date(substr(x, 1, 10), optional = TRUE))
  bad <- is.na(out) & !is.na(x) & nzchar(trimws(x))
  if (any(bad) && requireNamespace("lubridate", quietly = TRUE)) {
    out[bad] <- suppressWarnings(as.Date(lubridate::parse_date_time(
      x[bad], orders = c("Ymd HMS", "Ymd", "dmY", "dbY", "dmy", "mdY"), quiet = TRUE)))
  }
  out
}

aq_num <- function(x) suppressWarnings(as.numeric(as.character(x)))
aq_col <- function(df, nm) if (nm %in% names(df)) df[[nm]] else rep(NA, nrow(df))
aq_blank <- function(x) is.na(x) | !nzchar(trimws(as.character(x)))

# Vaccine type -> canonical spelling and a "family" used by the co-administration checks
AQ_VACCINE_CANON <- c("nOPV2", "bOPV", "mOPV2", "nOPV2 & bOPV", "nOPV2_bOPV_IPV", "nOPV1", "nOPV3",
                      "IPV", "fIPV", "MR", "Measles", "YF", "OPV")
aq_vaccine_family <- function(v) {
  k <- aq_norm(v)
  has_n <- grepl("NOPV2", k); has_b <- grepl("BOPV", k)
  ifelse(has_n & has_b, "combined", ifelse(has_n, "nOPV2", ifelse(has_b, "bOPV", "other")))
}

# ---------------------------------------------------------------
# Geography reference
# ---------------------------------------------------------------
# Lookup of every country / province / district of the region, from the shapefiles.
# Build once with aq_build_geo_reference() (see run_admin_quality_check.R) and keep in input/.
aq_load_geo_reference <- function(path = file.path("input", "geo_reference.rds")) {
  if (is.null(path) || !file.exists(path)) return(NULL)
  g <- tryCatch(readRDS(path), error = function(e) NULL)
  if (is.null(g) || !all(c("country", "province", "district") %in% names(g))) return(NULL)
  g <- as.data.frame(g, stringsAsFactors = FALSE)
  g$c_key <- aq_country_key(g$country)
  g$p_key <- aq_norm(g$province)
  g$d_key <- aq_norm(g$district)
  g
}

aq_build_geo_reference <- function(districts_rds, out_path = file.path("input", "geo_reference.rds"),
                                   region = "AFRO") {
  d <- readRDS(districts_rds)
  if (inherits(d, "sf")) d <- sf::st_drop_geometry(d)
  d <- as.data.frame(d, stringsAsFactors = FALSE)
  if ("WHO_REGION" %in% names(d) && !is.null(region)) d <- d[d$WHO_REGION %in% region, , drop = FALSE]
  g <- unique(data.frame(country = d$ADM0_NAME, province = d$ADM1_NAME, district = d$ADM2_NAME,
                         stringsAsFactors = FALSE))
  g <- g[order(g$country, g$province, g$district), ]
  saveRDS(g, out_path)
  invisible(g)
}

# ---------------------------------------------------------------
# Preparation: one tidy working table with the fields the checks need
# ---------------------------------------------------------------
aq_prepare <- function(df) {
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  n <- nrow(df)
  w <- data.frame(
    idx      = seq_len(n),
    ROW_ID   = if ("ROW_ID" %in% names(df)) df$ROW_ID else seq_len(n),
    Country  = as.character(aq_col(df, "Country")),
    Province = as.character(aq_col(df, "Province")),
    District = as.character(aq_col(df, "District")),
    Round    = as.character(aq_col(df, "Round_Add")),
    Vaccine  = as.character(aq_col(df, "Vaccine_type")),
    Response = as.character(aq_col(df, "Response")),
    stringsAsFactors = FALSE
  )
  w$sia_date    <- aq_as_date(aq_col(df, "SIA_date"))
  w$report_date <- aq_as_date(aq_col(df, "Date_Report"))
  w$tot_pop <- aq_num(aq_col(df, "TotPop"))
  w$target  <- aq_num(aq_col(df, "PopPolio"))
  w$vacc    <- aq_num(aq_col(df, "TotalNbrVaccPolio"))
  w$cv_rep  <- aq_num(aq_col(df, "CVPolio"))
  w$age_grp <- as.character(aq_col(df, "AgeGPolio"))
  w$c_key <- aq_country_key(w$Country)
  w$p_key <- aq_norm(w$Province)
  w$d_key <- aq_norm(w$District)
  w$fam   <- aq_vaccine_family(w$Vaccine)
  w$key_id <- if ("KEY_ID" %in% names(df) && !any(is.na(df$KEY_ID))) as.character(df$KEY_ID) else
    paste(w$c_key, w$p_key, w$d_key, format(w$sia_date, "%Y-%m-%d"), aq_norm(w$Round),
          aq_norm(w$Vaccine), aq_norm(w$Response), sep = "|")
  w
}

# one issue table in a fixed shape
aq_issue <- function(w, idx, check, severity, message, current = NA_character_, suggested = NA_character_) {
  if (length(idx) == 0) return(NULL)
  data.frame(idx = idx, check = check, severity = severity,
             message = rep_len(message, length(idx)),
             current = rep_len(as.character(current), length(idx)),
             suggested = rep_len(as.character(suggested), length(idx)),
             stringsAsFactors = FALSE)
}

# ---------------------------------------------------------------
# The checks
# ---------------------------------------------------------------
aq_check_missing_key <- function(w) {
  out <- list()
  fields <- c(Country = "Country", Province = "Province", District = "District", Vaccine = "Vaccine_type",
              Response = "Response", Round = "Round_Add")
  for (nm in names(fields)) {
    i <- which(aq_blank(w[[nm]]))
    out[[nm]] <- aq_issue(w, i, "missing_key", "Error", paste0(fields[[nm]], " is empty"))
  }
  i <- which(is.na(w$sia_date))
  out$sia <- aq_issue(w, i, "sia_date", "Error", "SIA_date is empty or could not be read")
  bind_rows(out)
}

aq_check_country_name <- function(w, geo) {
  if (is.null(geo)) return(NULL)
  ref <- unique(geo$c_key)
  std <- geo$country[!duplicated(geo$c_key)]
  names(std) <- geo$c_key[!duplicated(geo$c_key)]
  i <- which(!aq_blank(w$Country) & !(w$c_key %in% ref))
  out <- aq_issue(w, i, "country_name", "Error", "Country name is not in the geography reference",
                  current = w$Country[i])
  # known alternative spellings (CAMEROUN, TANZANIA ...): not wrong, but they split one country into two names
  raw <- aq_norm(w$Country)
  v <- which(!aq_blank(w$Country) & raw %in% names(AQ_COUNTRY_ALIASES) & raw != w$c_key & w$c_key %in% ref)
  if (length(v)) {
    standard <- std[w$c_key[v]]
    out <- bind_rows(out, aq_issue(w, v, "country_name", "Info",
                                   paste0("Country spelled '", w$Country[v], "'; the standard name is '", standard, "'"),
                                   current = w$Country[v], suggested = standard))
  }
  out
}

# province / country consistency
aq_check_geo <- function(w, geo) {
  if (is.null(geo)) return(list(issues = NULL, corrections = NULL, prov_eff = w$Province))
  # provinces of each country, and which countries own a province name
  cp <- unique(geo[, c("c_key", "p_key")])
  prov_countries <- split(cp$c_key, cp$p_key)
  ok <- paste(w$c_key, w$p_key) %in% paste(cp$c_key, cp$p_key)
  known_country <- w$c_key %in% geo$c_key
  test <- which(known_country & !aq_blank(w$Province) & !ok)

  # suggestion 1: the province of this district in the reference (only if unique inside the country)
  cd <- unique(geo[, c("c_key", "d_key", "province")])
  cd_n <- cd |> group_by(c_key, d_key) |> summarise(n = n_distinct(province), province = first(province), .groups = "drop")
  uniq <- cd_n[cd_n$n == 1, ]
  m <- match(paste(w$c_key[test], w$d_key[test]), paste(uniq$c_key, uniq$d_key))
  sugg <- uniq$province[m]
  src  <- ifelse(is.na(sugg), NA_character_, "geography reference (district)")

  # suggestion 2: what the other valid records of the same district say
  need <- which(is.na(sugg))
  if (length(need)) {
    good <- which(ok & !aq_blank(w$District))
    ev <- w[good, c("c_key", "d_key", "Province", "p_key")] |>
      group_by(c_key, d_key, Province, p_key) |> summarise(n = n(), .groups = "drop") |>
      arrange(desc(n)) |> group_by(c_key, d_key) |>
      summarise(Province = first(Province), tot = sum(n), top = max(n), .groups = "drop") |>
      filter(top / tot >= 0.8)
    m2 <- match(paste(w$c_key[test[need]], w$d_key[test[need]]), paste(ev$c_key, ev$d_key))
    sugg[need] <- ev$Province[m2]
    src[need]  <- ifelse(is.na(ev$Province[m2]), NA_character_, "other records of the same district")
  }

  other <- vapply(w$p_key[test], function(p) {
    cs <- prov_countries[[p]]
    if (is.null(cs)) "" else paste(setdiff(cs, ""), collapse = ", ")
  }, character(1))
  cross <- nzchar(other)
  # cross-country contamination is certain (Error); an unknown spelling is only a Warning
  issues <- bind_rows(
    aq_issue(w, test[cross], "geo_province", "Error",
             paste0("Province '", w$Province[test[cross]], "' belongs to ", other[cross],
                    ", not to ", w$Country[test[cross]]),
             current = w$Province[test[cross]], suggested = sugg[cross]),
    aq_issue(w, test[!cross], "geo_unknown", "Info",
             paste0("Province '", w$Province[test[!cross]], "' is not an Admin1 of ", w$Country[test[!cross]],
                    " in the geography reference (spelling, or a new Admin1?)"),
             current = w$Province[test[!cross]], suggested = sugg[!cross])
  )
  corr <- NULL
  if (length(test)) {
    corr <- data.frame(idx = test, Country = w$Country[test], District = w$District[test],
                       current_province = w$Province[test], suggested_province = sugg,
                       source = src, certain = cross, stringsAsFactors = FALSE)
    corr <- corr[!is.na(corr$suggested_province), , drop = FALSE]
  }
  prov_eff <- w$Province
  if (!is.null(corr) && nrow(corr)) prov_eff[corr$idx] <- corr$suggested_province
  list(issues = issues, corrections = corr, prov_eff = prov_eff)
}

aq_check_dates <- function(w, cfg, today = Sys.Date()) {
  out <- list()
  yr <- as.integer(format(w$sia_date, "%Y"))
  i <- which(!is.na(w$sia_date) & (yr < cfg$min_sia_year | yr > as.integer(format(today, "%Y")) + 1))
  out$year <- aq_issue(w, i, "sia_date", "Error", paste0("SIA_date year ", yr[i], " is outside the plausible range"),
                       current = format(w$sia_date[i]))
  i <- which(!is.na(w$sia_date) & w$sia_date > today + 120)
  out$future <- aq_issue(w, i, "sia_date", "Warning", "SIA_date is more than 4 months in the future",
                         current = format(w$sia_date[i]))
  d <- as.numeric(w$report_date - w$sia_date)
  i <- which(!is.na(d) & d < 0)
  out$before <- aq_issue(w, i, "report_date", "Warning",
                         paste0("Report date is ", -d[i], " day(s) before the SIA start"),
                         current = format(w$report_date[i]), suggested = format(w$sia_date[i]))
  i <- which(!is.na(w$report_date) & w$report_date > today)
  out$rfuture <- aq_issue(w, i, "report_date", "Warning", "Report date is in the future", current = format(w$report_date[i]))
  i <- which(!is.na(d) & d > cfg$report_late_days)
  out$late <- aq_issue(w, i, "report_date", "Info", paste0("Report date is ", d[i], " days after the SIA start"),
                       current = format(w$report_date[i]))
  bind_rows(out)
}

aq_check_numbers <- function(w, cfg) {
  out <- list()
  neg <- which((!is.na(w$tot_pop) & w$tot_pop < 0) | (!is.na(w$target) & w$target < 0) | (!is.na(w$vacc) & w$vacc < 0))
  out$neg <- aq_issue(w, neg, "negative_number", "Error", "Population or number vaccinated is negative")

  polio <- !(is.na(w$target) & is.na(w$vacc))            # polio figures were reported on this row
  i <- which(polio & !is.na(w$vacc) & w$vacc > 0 & (is.na(w$target) | w$target <= 0))
  out$tm <- aq_issue(w, i, "target_missing", "Error", "Vaccinated children reported but the target population is missing or zero",
                     current = w$target[i])

  i <- which(!is.na(w$tot_pop) & !is.na(w$target) & w$tot_pop > 0 & w$target > w$tot_pop * 1.0001)
  out$gt <- aq_issue(w, i, "target_gt_total", "Warning",
                     paste0("Target population (", format(w$target[i], big.mark = ",", trim = TRUE), ") is larger than the total population (",
                            format(w$tot_pop[i], big.mark = ",", trim = TRUE), ")"))

  rc <- w$vacc / w$target
  ok <- is.finite(rc) & w$target > 0
  i <- which(ok & rc > cfg$cv_ceiling)
  out$ceil <- aq_issue(w, i, "coverage_ceiling", "Warning",
                       paste0("Vaccinated / target = ", round(100 * rc[i]), "% (above the ", round(100 * cfg$cv_ceiling),
                              "% ceiling): invalid for coverage analysis until verified"),
                       current = paste0(round(100 * rc[i], 1), "%"))
  i <- which(ok & rc > cfg$cv_high & rc <= cfg$cv_ceiling)
  out$high <- aq_issue(w, i, "coverage_high", "Info",
                       paste0("Vaccinated / target = ", round(100 * rc[i]), "%: please verify target and vaccinated"),
                       current = paste0(round(100 * rc[i], 1), "%"))
  # reported coverage must match vaccinated / target (reported as a ratio, 1 = 100%)
  rep <- w$cv_rep
  i <- which(ok & is.finite(rep) & abs(rc - rep) > cfg$cv_recalc_tol)
  out$mis <- aq_issue(w, i, "coverage_mismatch", ifelse(abs(rc[i] - rep[i]) > 0.10, "Warning", "Info"),
                      paste0("Reported coverage ", round(100 * rep[i], 1), "% but vaccinated / target = ", round(100 * rc[i], 1), "%"),
                      current = paste0(round(100 * rep[i], 1), "%"), suggested = paste0(round(100 * rc[i], 1), "%"))
  bind_rows(out)
}

# target population compared with the same district's other campaign dates
aq_check_target_jump <- function(w, cfg, prov_eff) {
  d <- w[!is.na(w$target) & w$target > 0 & !is.na(w$sia_date) & w$fam != "other" |
           (!is.na(w$target) & w$target > 0 & !is.na(w$sia_date)), , drop = FALSE]
  if (!nrow(d)) return(NULL)
  d$grp <- paste(d$c_key, aq_norm(prov_eff[d$idx]), d$d_key, aq_norm(d$age_grp), sep = "|")
  # one value per district and campaign date (several vaccines on the same date share the target)
  per_date <- d |> group_by(grp, sia_date) |> summarise(tp = median(target), .groups = "drop")
  cnt <- per_date |> count(grp, name = "n_dates")
  per_date <- per_date |> left_join(cnt, by = "grp") |> filter(n_dates >= cfg$pop_min_rounds)
  if (!nrow(per_date)) return(NULL)
  others <- per_date |> group_by(grp) |>
    mutate(med_others = vapply(seq_along(tp), function(i) median(tp[-i]), numeric(1))) |> ungroup()
  others$ratio <- others$tp / others$med_others
  flag <- others[others$ratio >= cfg$pop_factor | others$ratio <= 1 / cfg$pop_factor, ]
  if (!nrow(flag)) return(NULL)
  digit <- function(r) {
    for (k in 1:3) {
      if (abs(r / 10^k - 1) < 0.25) return("possible extra digit")
      if (abs(r * 10^k - 1) < 0.25) return("possible missing digit")
    }
    ""
  }
  flag$note <- vapply(flag$ratio, digit, character(1))
  hit <- d |> inner_join(flag[, c("grp", "sia_date", "tp", "med_others", "ratio", "note")], by = c("grp", "sia_date"))
  aq_issue(w, hit$idx, "target_jump",
           "Warning",
           paste0("Target ", format(hit$target, big.mark = ",", trim = TRUE), " is ", ifelse(hit$ratio >= 1, paste0(round(hit$ratio, 1), "x above"),
                  paste0(round(1 / hit$ratio, 1), "x below")), " the district median of its other campaign dates (",
                  format(round(hit$med_others), big.mark = ",", trim = TRUE), ")", ifelse(nzchar(hit$note), paste0(" - ", hit$note), "")),
           current = hit$target, suggested = round(hit$med_others))
}

aq_check_coadmin <- function(w) {
  out <- list()
  comb <- which(w$fam == "combined")
  out$comb <- aq_issue(w, comb, "coadmin_combined", "Info",
                       "Combined nOPV2 & bOPV record: confirm the target and the number vaccinated apply to both vaccines (separate records are preferred)",
                       current = w$Vaccine[comb])
  gk <- paste(w$c_key, w$d_key, format(w$sia_date, "%Y-%m-%d"))
  has_comb <- tapply(w$fam == "combined", gk, any)
  has_sep  <- tapply(w$fam %in% c("nOPV2", "bOPV"), gk, any)
  mixed_keys <- names(which(has_comb & has_sep[names(has_comb)]))
  i <- which(gk %in% mixed_keys & w$fam %in% c("combined", "nOPV2", "bOPV"))
  out$mixed <- aq_issue(w, i, "coadmin_mixed", "Warning",
                        "Same district and start date reported as a combined record and as separate vaccine records (risk of double counting)",
                        current = w$Vaccine[i])
  # separate records with identical numbers
  sep <- which(w$fam %in% c("nOPV2", "bOPV") & !is.na(w$vacc))
  if (length(sep)) {
    s <- w[sep, ]
    s$gk <- gk[sep]
    g <- s |> group_by(gk) |> summarise(nf = n_distinct(fam), nv = n_distinct(vacc), nt = n_distinct(target), .groups = "drop") |>
      filter(nf == 2, nv == 1, nt == 1)
    i <- s$idx[s$gk %in% g$gk]
    out$ident <- aq_issue(w, i, "coadmin_identical", "Info",
                          "nOPV2 and bOPV records of the same district and date have identical target and vaccinated: please confirm",
                          current = w$vacc[i])
  }
  bind_rows(out)
}

aq_check_vaccine_spelling <- function(w) {
  v <- trimws(w$Vaccine)
  k <- tolower(v)
  canon <- AQ_VACCINE_CANON[match(k, tolower(AQ_VACCINE_CANON))]
  i <- which(!aq_blank(v) & !is.na(canon) & v != canon)
  aq_issue(w, i, "vaccine_spelling", "Info", paste0("Vaccine type '", v[i], "' is spelled differently from '", canon[i], "'"),
           current = v[i], suggested = canon[i])
}

aq_check_duplicates <- function(w) {
  d <- w$key_id[duplicated(w$key_id) | duplicated(w$key_id, fromLast = TRUE)]
  i <- which(w$key_id %in% d)
  if (!length(i)) return(NULL)
  n <- table(w$key_id)[w$key_id[i]]
  aq_issue(w, i, "duplicate_key", "Warning",
           paste0("Same country, province, district, SIA date, round, vaccine and response appears ", as.integer(n), " times"))
}

# ---------------------------------------------------------------
# Run everything
# ---------------------------------------------------------------
aq_run_checks <- function(df, geo_ref = NULL, config = aq_config(), today = Sys.Date()) {
  t0 <- Sys.time()
  if (is.null(df) || !nrow(df)) {
    return(list(issues = aq_empty_issues(), corrections = NULL, n_rows = 0L, n_flagged = 0L,
                by_check = data.frame(), by_country = data.frame(), config = config, ran_at = t0))
  }
  w <- aq_prepare(df)
  geo <- geo_ref
  if (!is.null(geo) && !("c_key" %in% names(geo))) {
    geo$c_key <- aq_country_key(geo$country); geo$p_key <- aq_norm(geo$province); geo$d_key <- aq_norm(geo$district)
  }
  g <- aq_check_geo(w, geo)
  parts <- list(
    aq_check_missing_key(w),
    aq_check_country_name(w, geo),
    g$issues,
    aq_check_dates(w, config, today),
    aq_check_numbers(w, config),
    aq_check_target_jump(w, config, g$prov_eff),
    aq_check_coadmin(w),
    aq_check_vaccine_spelling(w),
    aq_check_duplicates(w)
  )
  iss <- bind_rows(parts)
  if (is.null(iss) || !nrow(iss)) iss <- aq_empty_issues_raw()
  iss <- iss |> left_join(w[, c("idx", "ROW_ID", "Country", "Province", "District", "sia_date", "Round", "Vaccine", "Response")],
                          by = "idx")
  iss$check_label <- unname(AQ_CHECKS[iss$check])
  iss$severity <- factor(iss$severity, levels = AQ_SEVERITY_LEVELS)
  iss <- iss |> arrange(severity, Country, check, District, sia_date)
  iss$severity <- as.character(iss$severity)
  iss <- iss[, c("severity", "check", "check_label", "Country", "Province", "District", "sia_date", "Round",
                 "Vaccine", "Response", "message", "current", "suggested", "ROW_ID", "idx")]
  names(iss)[names(iss) == "sia_date"] <- "SIA_date"
  rownames(iss) <- NULL

  corr <- g$corrections
  if (!is.null(corr) && nrow(corr)) {
    corr$ROW_ID <- w$ROW_ID[corr$idx]
    corr$SIA_date <- w$sia_date[corr$idx]
    corr$Response <- w$Response[corr$idx]
    corr <- corr[, c("ROW_ID", "idx", "Country", "current_province", "District", "suggested_province", "source",
                     "certain", "SIA_date", "Response")]
  }

  list(issues = iss, corrections = corr, n_rows = nrow(df), n_flagged = length(unique(iss$idx)),
       by_check = aq_summary_by_check(iss), by_country = aq_summary_by_country(iss, w),
       config = config, ran_at = t0, seconds = round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1))
}

aq_empty_issues_raw <- function() data.frame(idx = integer(0), check = character(0), severity = character(0),
                                             message = character(0), current = character(0), suggested = character(0),
                                             stringsAsFactors = FALSE)
aq_empty_issues <- function() {
  data.frame(severity = character(0), check = character(0), check_label = character(0), Country = character(0),
             Province = character(0), District = character(0), SIA_date = as.Date(character(0)), Round = character(0),
             Vaccine = character(0), Response = character(0), message = character(0), current = character(0),
             suggested = character(0), ROW_ID = integer(0), idx = integer(0), stringsAsFactors = FALSE)
}

aq_summary_by_check <- function(iss) {
  if (!nrow(iss)) return(data.frame(Check = character(0), Severity = character(0), Records = integer(0), Countries = integer(0)))
  iss |> group_by(Check = check_label, Severity = severity) |>
    summarise(Records = n_distinct(idx), Countries = n_distinct(Country), .groups = "drop") |>
    arrange(factor(Severity, levels = AQ_SEVERITY_LEVELS), desc(Records)) |> as.data.frame()
}

aq_summary_by_country <- function(iss, w) {
  tot <- w |> count(Country, name = "Records")
  if (!nrow(iss)) return(transform(tot, Errors = 0L, Warnings = 0L, Infos = 0L, `Records with an issue` = 0L))
  s <- iss |> group_by(Country) |>
    summarise(Errors = n_distinct(idx[severity == "Error"]), Warnings = n_distinct(idx[severity == "Warning"]),
              Infos = n_distinct(idx[severity == "Info"]), `Records with an issue` = n_distinct(idx), .groups = "drop")
  out <- tot |> left_join(s, by = "Country")
  for (cn in c("Errors", "Warnings", "Infos", "Records with an issue")) out[[cn]][is.na(out[[cn]])] <- 0L
  ew <- iss |> filter(severity %in% c("Error", "Warning")) |> group_by(Country) |> summarise(.n = n_distinct(idx), .groups = "drop")
  out$`% with an error or warning` <- round(100 * ew$.n[match(out$Country, ew$Country)] / pmax(out$Records, 1), 1)
  out$`% with an error or warning`[is.na(out$`% with an error or warning`)] <- 0
  as.data.frame(out |> arrange(desc(Errors), desc(Warnings)), check.names = FALSE)
}

# ---------------------------------------------------------------
# Upload gate: check a batch of new rows against what the repository already holds
# ---------------------------------------------------------------
# Only the columns the checks use, with safe types, so new rows and repository rows can be stacked.
aq_slim <- function(df) {
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  chr <- c("Country", "Province", "District", "Round_Add", "Vaccine_type", "Response", "AgeGPolio")
  num <- c("TotPop", "PopPolio", "TotalNbrVaccPolio", "CVPolio")
  out <- data.frame(ROW_ID = if ("ROW_ID" %in% names(df)) aq_num(df$ROW_ID) else seq_len(nrow(df)),
                    stringsAsFactors = FALSE)
  for (nm in chr) out[[nm]] <- as.character(aq_col(df, nm))
  out$SIA_date <- aq_as_date(aq_col(df, "SIA_date"))
  out$Date_Report <- aq_as_date(aq_col(df, "Date_Report"))
  for (nm in num) out[[nm]] <- aq_num(aq_col(df, nm))
  out
}

# `new_df` = rows being added. The repository rows of the same countries are included as context
# (so a target population can be compared with the district's earlier rounds) but only the new rows
# are reported. Duplicates against the repository are left to the portal's own duplicate dialog.
# $issues$Row = position of the row in new_df (1 = first data row).
aq_run_gate <- function(new_df, repo_df = NULL, geo_ref = NULL, config = aq_config()) {
  nd <- aq_slim(new_df)
  nd$ROW_ID <- -seq_len(nrow(nd))
  ctx <- NULL
  if (!is.null(repo_df) && nrow(repo_df)) {
    ctx <- aq_slim(repo_df)
    ctx <- ctx[aq_country_key(ctx$Country) %in% aq_country_key(nd$Country), , drop = FALSE]
  }
  res <- aq_run_checks(bind_rows(ctx, nd), geo_ref, config)
  iss <- res$issues
  iss <- iss[!is.na(iss$ROW_ID) & iss$ROW_ID < 0 & iss$check != "duplicate_key", , drop = FALSE]
  iss$Row <- -iss$ROW_ID
  list(issues = iss,
       n_errors = length(unique(iss$Row[iss$severity == "Error"])),
       n_warnings = length(unique(iss$Row[iss$severity == "Warning"])))
}

# ---------------------------------------------------------------
# Applying the safe fixes (province from the geography reference)
# ---------------------------------------------------------------
# `corrections` comes from aq_run_checks()$corrections; `row_ids` limits the fix to chosen rows.
# Only suggestions marked certain (province belongs to another country) are applied by default.
aq_apply_province_fixes <- function(df, corrections, row_ids = NULL, only_certain = TRUE) {
  if (is.null(corrections) || !nrow(corrections)) return(list(data = df, log = NULL))
  cr <- corrections
  if (only_certain) cr <- cr[cr$certain, , drop = FALSE]
  if (!is.null(row_ids)) cr <- cr[cr$ROW_ID %in% row_ids, , drop = FALSE]
  if (!nrow(cr)) return(list(data = df, log = NULL))
  pos <- match(cr$ROW_ID, df$ROW_ID)
  keep <- !is.na(pos)
  cr <- cr[keep, , drop = FALSE]; pos <- pos[keep]
  log <- data.frame(ROW_ID = df$ROW_ID[pos], Country = df$Country[pos], District = df$District[pos],
                    field = "Province", old_value = as.character(df$Province[pos]),
                    new_value = cr$suggested_province, source = cr$source,
                    changed_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"), stringsAsFactors = FALSE)
  df$Province[pos] <- cr$suggested_province
  list(data = df, log = log)
}

# ---------------------------------------------------------------
# Excel report (used by the portal download and the daily script)
# ---------------------------------------------------------------
aq_report_sheets <- function(res) {
  cfg <- res$config
  overview <- data.frame(
    Item = c("Records checked", "Records with at least one issue", "Errors (records)", "Warnings (records)", "Info (records)",
             "Coverage ceiling", "Target population jump factor", "Run at"),
    Value = c(res$n_rows, res$n_flagged,
              length(unique(res$issues$idx[res$issues$severity == "Error"])),
              length(unique(res$issues$idx[res$issues$severity == "Warning"])),
              length(unique(res$issues$idx[res$issues$severity == "Info"])),
              paste0(round(100 * cfg$cv_ceiling), "%"), paste0(cfg$pop_factor, "x"),
              format(res$ran_at, "%Y-%m-%d %H:%M")),
    stringsAsFactors = FALSE)
  iss <- res$issues[, setdiff(names(res$issues), "idx")]
  iss$SIA_date <- as.character(iss$SIA_date)
  sheets <- list(Overview = overview, `By check` = res$by_check, `By country` = res$by_country, Issues = iss)
  if (!is.null(res$corrections) && nrow(res$corrections)) {
    cr <- res$corrections[, setdiff(names(res$corrections), "idx")]
    cr$SIA_date <- as.character(cr$SIA_date)
    sheets[["Suggested fixes"]] <- cr
  }
  sheets
}
