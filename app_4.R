# =============================================================
# WHO AFRO Admin Data Portal – Country Focal Point Interface
# Complete Excel-like View with WHO Branding
# FULL UPDATED VERSION - DUPLICATE DETECTION FIXED
# =============================================================

library(shiny)
library(shinyjs)
library(readxl)
library(dplyr)
library(purrr)
library(writexl)
library(DT)
library(tibble)
library(stringr)
library(lubridate)
library(data.table)

# -----------------------------
# 0. Admin token
# -----------------------------
admin_token <- "AFRO-ADMIN-2025"

# -----------------------------
# 1. Focal points table
# -----------------------------
focal_points <- tribble(
  ~country,                         ~focal_point,                               ~email,
  "Algeria",                        "AIDARA, Mariem Seynath",                  "aidaram@who.int",
  "Angola",                         "AGOSTINHO, Dalton Ngando Jose",           "agostinhoda@who.int",
  "Angola",                         "LUTEGANYA, Victor Potens",                "luteganyav@who.int",
  "Benin",                          "Andre Kindjinou",                         "andrekindjinou@gmail.com",
  "Benin",                          "KINDJINOU André",                         "andrekindjinou@gmail.com",
  "Botswana",                       "SELELO, Lorina Rose",                     "selelol@who.int",
  "Burbina Faso",                   "SESSOUMA ABDOULAYE",                      "sesabdnaz@yahoo.fr",
  "Burkina Faso",                   "M'BOUTIKI, Gilles",                       "mboutikig@who.int",
  "Cameroon",                       "Mr Lele parfait",                         "lelec@who.int",
  "Cameroon",                       "RAKOTOARIVOLONA, Tania",                  "rakotoarivololonat@who.int",
  "Cameroon",                       "Kouontchou Jean Christian",               "kouontchoumimbej@who.int",
  "Central African Republic",       "M. OUEDRAOGO Salfo",                      "ouedsalfo@gmail.com",
  "Central African Republic",       "MBARY DABA Régis",                        "mbarydabar@who.int",
  "Chad",                           "Mr NGADJADOUM Emmanuel",                  "ngadjadoummb@who.int",
  "Chad",                           "CHOUANGMO WABO Yannick Franck",           "chouangmoy@who.int",
  "Cod'vore (CIV)",                 "KOUADIO, Sie Kabran",                     "kouadios@who.int",
  "Cod'vore (CIV)",                 "Bohoussou, Philibert Kouakou",            "bohoussoup@who.int",
  "Democratic Republic of the Congo","NSEYA MUTOMBO, Claudine",                "nseyac@who.int",
  "Eritrea",                        "GEBRESLASSIE ASFEHA, Azmera",             "gebreslassiea@who.int",
  "Eswatini",                       "DLAMINI, Makhoselive",                    "dlaminim@who.int",
  "Ethiopia",                       "Mr. Fasil Teshager",                      "teshagerf@who.int",
  "Gabon",                          "AMALET Brice",                            "amaletb@who.int",
  "Gambia",                         "Mustapha Sanyang",                        "sanyangm@who.int",
  "Ghana",                          "TAMAL, Christopher",                      "tamalc@who.int",
  "Guinea",                         "Sylla Mohamed",                           "mosylla@who.int",
  "Guinea Bissau (GNB)",            "Mamadou DIAW",                            "diawm2000@yahoo.fr",
  "Kenya",                          "MAINA, Stephen Karuru",                   "mainas@who.int",
  "Lesotho",                        "Maepe SELLEANO",                          "maepes@who.int",
  "Liberia",                        "SESAY, Jeremy S.",                        "sesayj@who.int",
  "Malawi",                         "GALANDI, Albert Mandala",                 "galandia@who.int",
  "Mali",                           "YAYA COULIBALY",                          "coulibalyy@who.int",
  "Mozambique",                     "ODALLAH, Anita Aunda Pedro",              "odallaha@who.int",
  "Namibia",                        "NASHIPILI, Japhet",                       "nashipilij@who.int",
  "Niger",                          "HALADOU, Moussa",                         "haladoum@who.int",
  "Nigeria",                        "SOLOMON, Jason Praise",                   "solomonj@who.int",
  "Republic of Congo",              "ELENGA GARBA, Serge Francis",             "elengaf@who.int",
  "Rwanda",                         "DUSHIMIMANA JEAN DE DIEU",                "dushimimanaj@who.int",
  "Senegal",                        "Dr Alassane Ndiaye",                      "ndiayea@who.int",
  "Sierra Leone",                   "SESAY, Abdul Regis Stephen",              "sesays@who.int",
  "South Africa",                   "BUTHELEZI, Thulasizwe John",              "buthelezit@who.int",
  "South Sudan",                    "David Taban KILO OCHAN",                  "ochant@who.int",
  "Togo",                           "Dzidzino Richard",                        "dzidzinyok@who.int",
  "Uganda",                         "Emmanuel TENYWA",                         "tenywaem@who.int",
  "Zimbabwe",                       "Trevor Muchabaiwa",                       "muchabaiwat@who.int",
  "Namibia",                        "Albert Tjaronda",                         "ahltjaronda@gmail.com"
)

# -----------------------------
# 2. Token generator
# -----------------------------
generate_token <- function(country, year = format(Sys.Date(), "%Y"), len = 6) {
  prefix <- toupper(gsub("\\s+", "", substr(country, 1, 3)))
  chars <- c(LETTERS, 0:9)
  rand_part <- paste0(sample(chars, len, replace = TRUE), collapse = "")
  paste0(prefix, "-", year, "-", rand_part)
}

set.seed(2025)
tokens_tbl <- focal_points %>% mutate(token = generate_token(country))
country_tokens <- setNames(tokens_tbl$country, tokens_tbl$token)

# -----------------------------
# 3. Paths & Template
# -----------------------------
input_dir   <- "input"
output_dir  <- "output"

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

detect_template_path <- function(input_dir) {
  if (!dir.exists(input_dir)) {
    stop("Input directory not found. Please create an 'input' folder in the app directory.")
  }
  
  xlsx_files <- list.files(input_dir, pattern = "\\.xlsx$", full.names = TRUE, ignore.case = TRUE)
  if (length(xlsx_files) == 0) {
    stop("No .xlsx file found in the 'input' folder. Please place the admin template Excel file there.")
  }
  
  base <- basename(xlsx_files)
  preferred <- xlsx_files[grepl("AFRO.*admin.*data", base, ignore.case = TRUE)]
  pick <- if (length(preferred) > 0) preferred else xlsx_files
  pick[which.max(file.info(pick)$mtime)]
}

template_path <- detect_template_path(input_dir)

repo_rds_path  <- file.path(output_dir, "AFRO_admin_data_repository.rds")
repo_xlsx_path <- file.path(output_dir, "AFRO_admin_data_repository.xlsx")

# -----------------------------
# 4. Key definitions
# -----------------------------
duplicate_key_cols <- c(
  "Country", "Province", "District", "SIA_date",
  "Round_Add", "Vaccine_type", "Response"
)

count_columns <- c(
  "Nbr0dosesVaccPolio_0_11M", "Nbr_1doses_Plus_VacPolio_0_11M",
  "Nbr0dosesVacPolio_12_59M", "Nbr_1doses_Plus_VacPolio_12_59M",
  "Total_Nbr_0doseVaccPolio_0_59M", "Total_Nbr_1dose_Plus_vaccPolio_0_59M",
  "TotalNbrVaccPolio", "PopPolio", "Doses.UsedPolio", "TotalDoses",
  "PopPolio_0_11M", "PopPolio_12_59M"
)

rate_columns <- c(
  "CVPolio", "WastRPolio", "Prop_0dosesPolio",
  "Nbr0dosePct_0_11M", "Nbr0dosePct_12_59M"
)

geo_columns <- c(
  "Admin_1","Admin_2","Admin_3","Admin_4",
  "Country","Region","Province","District","Ward","Village"
)

# -----------------------------
# 5. Normalization helpers
# -----------------------------
normalize_admin_columns <- function(df) {
  if ("SIA-date" %in% names(df) && !"SIA_date" %in% names(df)) {
    names(df)[names(df) == "SIA-date"] <- "SIA_date"
  }
  df
}

parse_sia_date <- function(x) {
  if (length(x) == 0) return(as.Date(character(0)))
  if (inherits(x, "Date")) return(as.Date(x))
  if (inherits(x, c("POSIXct", "POSIXt"))) return(as.Date(x))
  if (is.numeric(x)) return(as.Date(x, origin = "1899-12-30"))
  
  s <- trimws(as.character(x))
  s[s %in% c("", "NA", "NaN", "NULL")] <- NA_character_
  if (all(is.na(s))) return(as.Date(s))
  
  s <- gsub("\\s+UTC$", "", s, ignore.case = TRUE)
  s <- tolower(s)
  
  s <- gsub("janv\\.?","jan", s)
  s <- gsub("févr\\.?|fevr\\.?|fév\\.?|fev\\.?","feb", s)
  s <- gsub("mars","mar", s)
  s <- gsub("avr\\.?","apr", s)
  s <- gsub("mai","may", s)
  s <- gsub("juin","jun", s)
  s <- gsub("juil\\.?","jul", s)
  s <- gsub("août|aout","aug", s)
  s <- gsub("sept\\.?","sep", s)
  s <- gsub("oct\\.?","oct", s)
  s <- gsub("nov\\.?","nov", s)
  s <- gsub("déc\\.?|dec\\.?","dec", s)
  
  parsed <- suppressWarnings(
    lubridate::parse_date_time(
      s,
      orders = c(
        "Y-m-d H:M:S", "Y-m-d",
        "d-b-y", "d-b-Y",
        "d/m/Y", "m/d/Y", "d.m.Y"
      ),
      tz = "UTC"
    )
  )
  as.Date(parsed)
}

normalize_admin_dates <- function(df) {
  df <- normalize_admin_columns(df)
  if ("SIA_date" %in% names(df)) df$SIA_date <- parse_sia_date(df$SIA_date)
  if ("Entry_Date" %in% names(df)) df$Entry_Date <- as.Date(df$Entry_Date)
  df
}

.clean_key_vec <- function(v) {
  v <- as.character(v)
  v[is.na(v) | trimws(v) == "" | trimws(v) %in% c("NA", "NULL")] <- "NA"
  v <- toupper(trimws(v))
  v <- gsub("[[:space:]]+", " ", v)
  v <- iconv(v, from = "", to = "ASCII//TRANSLIT", sub = "")
  v[is.na(v)] <- "NA"
  v <- gsub("[^A-Z0-9 ]", "", v)
  v <- trimws(v)
  v[v == ""] <- "NA"
  v
}

.format_sia_key <- function(v) {
  dv <- parse_sia_date(v)
  out <- format(dv, "%Y-%m-%d")
  out[is.na(dv)] <- "NA"
  out
}

# -----------------------------
# 6. Template schema
# -----------------------------
guess_type_from_name <- function(nm) {
  nm0 <- tolower(nm)
  if (grepl("date", nm0) || nm %in% c("SIA_date", "Entry_Date")) return("Date")
  if (grepl("totpop|population|pop|target|ageg|num|count|dose|coverage|cv|pct|prop|wast", nm0)) return("numeric")
  "character"
}

detect_column_types_robust <- function(df, col_names) {
  out <- setNames(rep("character", length(col_names)), col_names)
  
  for (nm in col_names) {
    if (!nm %in% names(df)) {
      out[[nm]] <- guess_type_from_name(nm)
      next
    }
    
    v <- df[[nm]]
    if (length(v) > 0 && any(!is.na(v))) {
      cls <- class(v)[1]
      if (cls %in% c("Date", "POSIXct", "POSIXt")) out[[nm]] <- "Date"
      else if (cls %in% c("numeric", "double", "integer")) out[[nm]] <- "numeric"
      else out[[nm]] <- "character"
    } else {
      out[[nm]] <- guess_type_from_name(nm)
    }
  }
  
  out
}

read_template_schema <- function(template_path) {
  df <- suppressWarnings(readxl::read_excel(template_path, n_max = 5000)) %>%
    normalize_admin_columns()
  
  col_names <- names(df)
  if (length(col_names) == 0) {
    stop("Template appears to have no headers. Please ensure the first row contains column names.")
  }
  
  df <- normalize_admin_dates(df)
  col_types <- detect_column_types_robust(df, col_names)
  
  if (!"Entry_Date" %in% col_names) {
    col_names <- c(col_names, "Entry_Date")
    col_types <- c(col_types, Entry_Date = "Date")
  }
  
  list(
    template_df   = df,
    column_names  = col_names,
    column_types  = col_types
  )
}

make_empty_df_from_schema <- function(schema, n_rows = 0) {
  out <- setNames(vector("list", length(schema$column_names)), schema$column_names)
  
  for (nm in schema$column_names) {
    tp <- schema$column_types[[nm]]
    out[[nm]] <- if (!is.null(tp) && tp == "Date") {
      rep(as.Date(NA), n_rows)
    } else if (!is.null(tp) && tp == "numeric") {
      rep(NA_real_, n_rows)
    } else {
      rep(NA_character_, n_rows)
    }
  }
  
  df <- as.data.frame(out, stringsAsFactors = FALSE)
  if (n_rows == 0) df <- df[0, , drop = FALSE]
  df
}

template_schema <- read_template_schema(template_path)
template_df <- template_schema$template_df %>% normalize_admin_dates()
if (!"Entry_Date" %in% names(template_df)) template_df$Entry_Date <- as.Date(NA)

# -----------------------------
# 7. KEY_ID creation
# -----------------------------
create_unique_id_dt <- function(df) {
  available_cols <- intersect(duplicate_key_cols, names(df))
  if (length(available_cols) == 0 || nrow(df) == 0) return(character(0))
  
  dt <- as.data.table(df)[, ..available_cols]
  
  for (col in available_cols) {
    if (col == "SIA_date") {
      dt[[col]] <- .format_sia_key(dt[[col]])
    } else {
      dt[[col]] <- .clean_key_vec(dt[[col]])
    }
  }
  
  dt[, KEY_ID := do.call(paste, c(.SD, sep = "|"))]
  dt$KEY_ID
}

convert_geo <- function(df) {
  geo_cols <- intersect(geo_columns, names(df))
  for (col in geo_cols) df[[col]] <- as.character(df[[col]])
  df
}

ensure_rowid_keyid <- function(df) {
  df <- normalize_admin_dates(df)
  
  if (!"Entry_Date" %in% names(df)) df$Entry_Date <- as.Date(NA)
  
  if (!"ROW_ID" %in% names(df)) {
    df$ROW_ID <- seq_len(nrow(df))
  } else {
    miss <- which(is.na(df$ROW_ID))
    if (length(miss) > 0) {
      max_id <- suppressWarnings(max(df$ROW_ID, na.rm = TRUE))
      if (!is.finite(max_id)) max_id <- 0
      df$ROW_ID[miss] <- seq(max_id + 1, max_id + length(miss))
    }
  }
  
  df$KEY_ID <- create_unique_id_dt(df)
  df
}

save_repo <- function(df) {
  df <- ensure_rowid_keyid(df)
  saveRDS(df, repo_rds_path)
  writexl::write_xlsx(df, repo_xlsx_path)
}

# -----------------------------
# 8. Duplicate detection
# -----------------------------
calculate_duplicate_confidence <- function(row1, row2, key_cols = duplicate_key_cols) {
  matches <- 0
  total <- 0
  
  for (col in key_cols) {
    if (!(col %in% names(row1)) || !(col %in% names(row2))) next
    
    if (col == "SIA_date") {
      val1 <- .format_sia_key(row1[[col]])
      val2 <- .format_sia_key(row2[[col]])
    } else {
      val1 <- .clean_key_vec(row1[[col]])
      val2 <- .clean_key_vec(row2[[col]])
    }
    
    if (!is.na(val1) && !is.na(val2)) {
      total <- total + 1
      if (identical(val1, val2)) matches <- matches + 1
    }
  }
  
  if (total == 0) return(0)
  round((matches / total) * 100, 1)
}

find_partial_duplicates <- function(df, threshold = 85, key_cols = duplicate_key_cols) {
  if (nrow(df) < 2) return(data.frame())
  
  df <- ensure_rowid_keyid(df)
  reps <- df %>%
    group_by(KEY_ID) %>%
    slice(1) %>%
    ungroup()
  
  if (nrow(reps) < 2) return(data.frame())
  
  partials <- list()
  idx <- 1
  
  for (i in 1:(nrow(reps) - 1)) {
    for (j in (i + 1):nrow(reps)) {
      conf <- calculate_duplicate_confidence(reps[i, , drop = FALSE], reps[j, , drop = FALSE], key_cols = key_cols)
      if (conf >= threshold && conf < 100) {
        partials[[idx]] <- data.frame(
          KEY_ID_1 = reps$KEY_ID[i],
          KEY_ID_2 = reps$KEY_ID[j],
          confidence = conf,
          stringsAsFactors = FALSE
        )
        idx <- idx + 1
      }
    }
  }
  
  if (length(partials) == 0) return(data.frame())
  bind_rows(partials) %>% arrange(desc(confidence))
}

find_all_duplicates <- function(df) {
  if (nrow(df) == 0) return(data.frame())
  
  df <- ensure_rowid_keyid(df)
  
  out <- df %>%
    group_by(KEY_ID) %>%
    mutate(n_in_group = n()) %>%
    ungroup() %>%
    filter(n_in_group > 1) %>%
    arrange(KEY_ID, ROW_ID)
  
  if (nrow(out) == 0) return(data.frame())
  
  out <- out %>%
    group_by(KEY_ID) %>%
    mutate(
      duplicate_group = cur_group_id(),
      record_num = row_number(),
      confidence = 100
    ) %>%
    ungroup()
  
  as.data.frame(out)
}

# -----------------------------
# 9. Validation
# -----------------------------
validate_admin_data <- function(new_df, existing_df = NULL) {
  errors <- list()
  new_df <- normalize_admin_dates(new_df)
  
  missing_keys <- setdiff(duplicate_key_cols, names(new_df))
  if (length(missing_keys) > 0) {
    errors$missing_columns <- paste("Missing key columns:", paste(missing_keys, collapse = ", "))
    return(errors)
  }
  
  for (col in duplicate_key_cols) {
    empty_count <- sum(is.na(new_df[[col]]) | trimws(as.character(new_df[[col]])) == "")
    if (empty_count > 0) {
      errors[[paste0("empty_", col)]] <- paste(col, "has", empty_count, "empty values")
    }
  }
  
  if ("SIA_date" %in% names(new_df) && any(is.na(new_df$SIA_date))) {
    errors$invalid_sia_date <- "Some SIA_date values could not be parsed."
  }
  
  if (nrow(new_df) > 1) {
    new_ids <- create_unique_id_dt(new_df)
    dup_ids <- new_ids[duplicated(new_ids)]
    if (length(dup_ids) > 0) {
      errors$internal_duplicates <- paste(length(unique(dup_ids)), "duplicate key(s) found within uploaded data")
    }
  }
  
  if (!is.null(existing_df) && nrow(existing_df) > 0 && nrow(new_df) > 0) {
    existing_ids <- create_unique_id_dt(existing_df)
    new_ids <- create_unique_id_dt(new_df)
    overlap <- intersect(new_ids, existing_ids)
    
    if (length(overlap) > 0) {
      errors$existing_duplicates <- list(
        count = length(overlap),
        ids = overlap,
        message = paste(length(overlap), "records already exist in repository.")
      )
    }
  }
  
  errors
}

# -----------------------------
# 10. Merge / recalc helpers
# -----------------------------
recalculate_percentages <- function(df) {
  if (nrow(df) == 0) return(df)
  
  if (all(c("TotalNbrVaccPolio", "PopPolio", "CVPolio") %in% names(df))) {
    idx <- !is.na(df$TotalNbrVaccPolio) & !is.na(df$PopPolio) & df$PopPolio > 0
    df$CVPolio[idx] <- (df$TotalNbrVaccPolio[idx] / df$PopPolio[idx]) * 100
  }
  
  if (all(c("Doses.UsedPolio", "TotalDoses", "WastRPolio") %in% names(df))) {
    idx <- !is.na(df$Doses.UsedPolio) & !is.na(df$TotalDoses) & df$TotalDoses > 0
    df$WastRPolio[idx] <- ((df$TotalDoses[idx] - df$Doses.UsedPolio[idx]) / df$TotalDoses[idx]) * 100
  }
  
  if (all(c("Total_Nbr_0doseVaccPolio_0_59M", "TotalNbrVaccPolio", "Prop_0dosesPolio") %in% names(df))) {
    idx <- !is.na(df$Total_Nbr_0doseVaccPolio_0_59M) & !is.na(df$TotalNbrVaccPolio) & df$TotalNbrVaccPolio > 0
    df$Prop_0dosesPolio[idx] <- df$Total_Nbr_0doseVaccPolio_0_59M[idx] / df$TotalNbrVaccPolio[idx]
    idx_zero <- !is.na(df$Total_Nbr_0doseVaccPolio_0_59M) & df$Total_Nbr_0doseVaccPolio_0_59M == 0
    df$Prop_0dosesPolio[idx_zero] <- 0
  }
  
  if (all(c("Nbr0dosesVaccPolio_0_11M", "PopPolio_0_11M", "Nbr0dosePct_0_11M") %in% names(df))) {
    idx <- !is.na(df$Nbr0dosesVaccPolio_0_11M) & !is.na(df$PopPolio_0_11M) & df$PopPolio_0_11M > 0
    df$Nbr0dosePct_0_11M[idx] <- df$Nbr0dosesVaccPolio_0_11M[idx] / df$PopPolio_0_11M[idx]
  }
  
  if (all(c("Nbr0dosesVacPolio_12_59M", "PopPolio_12_59M", "Nbr0dosePct_12_59M") %in% names(df))) {
    idx <- !is.na(df$Nbr0dosesVacPolio_12_59M) & !is.na(df$PopPolio_12_59M) & df$PopPolio_12_59M > 0
    df$Nbr0dosePct_12_59M[idx] <- df$Nbr0dosesVacPolio_12_59M[idx] / df$PopPolio_12_59M[idx]
  }
  
  df
}

merge_duplicate_rows <- function(duplicate_group_df, merge_strategy = "weighted_average") {
  if (nrow(duplicate_group_df) == 1) return(duplicate_group_df)
  
  duplicate_group_df <- duplicate_group_df[order(duplicate_group_df$ROW_ID), , drop = FALSE]
  result <- duplicate_group_df[1, , drop = FALSE]
  
  key_cols_present <- intersect(duplicate_key_cols, names(result))
  for (col in key_cols_present) {
    non_empty <- duplicate_group_df[[col]][!is.na(duplicate_group_df[[col]]) & trimws(as.character(duplicate_group_df[[col]])) != ""]
    if (length(non_empty) > 0) result[[col]] <- non_empty[1]
  }
  
  char_cols <- names(duplicate_group_df)[sapply(duplicate_group_df, function(x) is.character(x) || is.factor(x))]
  for (col in setdiff(char_cols, c(key_cols_present, "KEY_ID"))) {
    non_empty <- duplicate_group_df[[col]][!is.na(duplicate_group_df[[col]]) & trimws(as.character(duplicate_group_df[[col]])) != ""]
    if (length(non_empty) > 0) result[[col]] <- as.character(non_empty[1])
  }
  
  numeric_cols <- names(duplicate_group_df)[sapply(duplicate_group_df, is.numeric)]
  numeric_cols <- setdiff(numeric_cols, c("ROW_ID", "duplicate_group", "record_num", "confidence", "n_in_group"))
  
  if (merge_strategy %in% c("weighted_average", "sum_numeric")) {
    for (col in intersect(count_columns, numeric_cols)) {
      value <- sum(duplicate_group_df[[col]], na.rm = TRUE)
      if (is.nan(value)) value <- NA_real_
      result[[col]] <- value
    }
  }
  
  if (merge_strategy == "mean_numeric") {
    for (col in intersect(count_columns, numeric_cols)) {
      value <- sum(duplicate_group_df[[col]], na.rm = TRUE)
      if (is.nan(value)) value <- NA_real_
      result[[col]] <- value
    }
    for (col in intersect(rate_columns, numeric_cols)) {
      value <- mean(duplicate_group_df[[col]], na.rm = TRUE)
      if (is.nan(value)) value <- NA_real_
      result[[col]] <- value
    }
  }
  
  if (merge_strategy == "max_numeric") {
    for (col in numeric_cols) {
      value <- suppressWarnings(max(duplicate_group_df[[col]], na.rm = TRUE))
      if (!is.finite(value)) value <- NA_real_
      result[[col]] <- value
    }
  }
  
  if (merge_strategy == "min_numeric") {
    for (col in numeric_cols) {
      value <- suppressWarnings(min(duplicate_group_df[[col]], na.rm = TRUE))
      if (!is.finite(value)) value <- NA_real_
      result[[col]] <- value
    }
  }
  
  result <- recalculate_percentages(result)
  
  if ("Entry_Date" %in% names(result)) result$Entry_Date <- Sys.Date()
  result$KEY_ID <- create_unique_id_dt(result)[1]
  
  result
}

# -----------------------------
# 11. UI
# -----------------------------
ui <- fluidPage(
  useShinyjs(),
  
  tags$head(
    tags$link(
      href = "https://fonts.googleapis.com/css2?family=Segoe+UI:wght@300;400;600;700&display=swap",
      rel = "stylesheet"
    ),
    tags$style(HTML("
      * { font-family: 'Segoe UI', 'Open Sans', sans-serif; }
      body { background: #f5f5f5; color: #333; }
      .excel-panel {
        background: white;
        border: 1px solid #ddd;
        border-radius: 8px;
        padding: 15px;
        margin-top: 15px;
        box-shadow: 0 1px 3px rgba(0,0,0,0.08);
      }
      .excel-title {
        font-size: 16px;
        font-weight: 600;
        color: #0066b3;
        margin-bottom: 10px;
        border-left: 3px solid #0066b3;
        padding-left: 10px;
      }
      .excel-subtitle {
        font-size: 12px;
        color: #666;
        margin-bottom: 10px;
      }
      .btn {
        border-radius: 4px;
        font-weight: 600;
        margin: 2px;
        padding: 6px 12px;
        font-size: 13px;
      }
      .btn-primary { background: linear-gradient(135deg, #0066b3 0%, #0088cc 100%); border: none; color: white; }
      .btn-success { background: linear-gradient(135deg, #28a745 0%, #34ce57 100%); border: none; color: white; }
      .btn-warning { background: linear-gradient(135deg, #ffc107 0%, #ffda6a 100%); border: none; color: #5b4500; }
      .btn-danger  { background: linear-gradient(135deg, #dc3545 0%, #ff4757 100%); border: none; color: white; }
      .btn-info    { background: linear-gradient(135deg, #17a2b8 0%, #1fc8e3 100%); border: none; color: white; }
      .btn-secondary { background: linear-gradient(135deg, #6c757d 0%, #868e96 100%); border: none; color: white; }
      .nav-tabs > li > a { font-weight: 600; }
      .dataTables_wrapper { overflow-x: auto; }
      .small-note { font-size: 12px; color: #666; }
    "))
  ),
  
  div(
    id = "who-header",
    style = "
      position: sticky;
      top: 0;
      z-index: 1000;
      background: linear-gradient(135deg, #003366 0%, #0066b3 100%);
      padding: 10px 20px;
      border-bottom: 2px solid #00a0dc;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
      display: flex;
      align-items: center;
      gap: 15px;
      flex-wrap: wrap;
    ",
    div(
      style = "display: flex; align-items: center; gap: 10px;",
      div(style = "font-size: 22px; font-weight: 700; color: white;", "WHO"),
      div(style = "height: 30px; width: 1px; background-color: rgba(255,255,255,0.3);"),
      div(style = "font-size: 18px; font-weight: 600; color: white;", "AFRO")
    ),
    div(
      style = "flex-grow: 1;",
      h4("Administrative Data Portal", style = "color:white; margin:0; font-weight:600; font-size:18px;"),
      div("Polio Eradication Program", style = "color:#cce5ff; margin-top:2px; font-size:11px;"),
      div(textOutput("last_update"), style = "color:#a8d4ff; margin-top:2px; font-size:10px;")
    ),
    div(
      actionButton(
        "refresh_data", "Refresh",
        style = "background: rgba(255,255,255,0.15); border: 1px solid rgba(255,255,255,0.3); color: white; border-radius: 4px;"
      )
    )
  ),
  
  uiOutput("theme_css"),
  uiOutput("app_body")
)

# -----------------------------
# 12. SERVER
# -----------------------------
server <- function(input, output, session) {
  
  user_country <- reactiveVal(NULL)
  user_role    <- reactiveVal("user")
  merge_history <- reactiveVal(list())
  manual_data  <- reactiveVal(NULL)
  
  # ---------------------------
  # Theme
  # ---------------------------
  output$theme_css <- renderUI({
    if (isTRUE(input$dark_mode)) {
      tags$style(HTML("
        body { background: #1a1a2e; color: #e0e0e0; }
        .well, .panel, .panel-body, .excel-panel {
          background: #16213e !important;
          border-color: #0f3460 !important;
          color: #e0e0e0 !important;
        }
        .form-control, .selectize-input {
          background-color: #0f3460;
          border-color: #1a5276;
          color: #e0e0e0;
        }
        .nav-tabs { border-bottom-color: #0f3460; }
        .nav-tabs > li > a {
          background: #16213e;
          color: #b8c5d6;
          border-color: #0f3460;
        }
        .nav-tabs > li.active > a {
          background: #1a1a2e;
          color: #00a0dc;
          border-color: #00a0dc #0f3460 #1a1a2e;
        }
      "))
    } else {
      tags$style(HTML(""))
    }
  })
  
  # ---------------------------
  # Repository state
  # ---------------------------
  admin_repo <- reactiveVal({
    if (file.exists(repo_rds_path)) {
      repo <- readRDS(repo_rds_path)
      repo <- convert_geo(repo)
      repo <- ensure_rowid_keyid(repo)
      save_repo(repo)
      repo
    } else {
      df0 <- make_empty_df_from_schema(template_schema, n_rows = 0)
      df0 <- convert_geo(df0)
      df0 <- ensure_rowid_keyid(df0)
      df0
    }
  })
  
  repo_country <- reactive({
    req(user_country())
    df <- admin_repo()
    if (isTRUE(user_role() == "admin")) return(df)
    if ("Country" %in% names(df)) df <- df %>% filter(.data$Country == user_country())
    df
  })
  
  output$last_update <- renderText({
    if (file.exists(repo_rds_path)) {
      t <- file.info(repo_rds_path)$mtime
      paste0("Last update: ", format(t, "%Y-%m-%d %H:%M:%S"))
    } else {
      "Repository not yet created"
    }
  })
  
  observeEvent(input$refresh_data, {
    if (file.exists(repo_rds_path)) {
      repo <- readRDS(repo_rds_path)
      repo <- convert_geo(repo)
      repo <- ensure_rowid_keyid(repo)
      admin_repo(repo)
      showNotification("Data refreshed successfully.", type = "message", duration = 2)
    } else {
      showNotification("No data repository found.", type = "warning", duration = 2)
    }
  })
  
  # ---------------------------
  # Login
  # ---------------------------
  observeEvent(input$login_btn, {
    token <- trimws(input$access_token)
    
    if (identical(token, admin_token)) {
      user_role("admin")
      user_country("ALL")
      showNotification("Admin login successful – full repository access.", type = "message")
    } else if (token %in% names(country_tokens)) {
      user_role("user")
      user_country(country_tokens[[token]])
      showNotification(paste("Login successful – country:", country_tokens[[token]]), type = "message")
    } else {
      showNotification("Invalid token. Please check your access code.", type = "error")
    }
  })
  
  # ---------------------------
  # Manual entry initialization
  # ---------------------------
  observeEvent(user_country(), {
    req(user_country())
    df <- make_empty_df_from_schema(template_schema, n_rows = 1)
    if ("Entry_Date" %in% names(df)) df$Entry_Date[1] <- Sys.Date()
    if (isTRUE(user_role() != "admin") && "Country" %in% names(df)) df$Country[1] <- user_country()
    df <- convert_geo(df)
    manual_data(df)
  }, ignoreInit = FALSE)
  
  # ---------------------------
  # Downloads
  # ---------------------------
  output$download_empty_template <- downloadHandler(
    filename = function() paste0("AFRO_admin_data_TEMPLATE_EMPTY_", Sys.Date(), ".xlsx"),
    content = function(file) {
      empty_df <- make_empty_df_from_schema(template_schema, n_rows = 0)
      writexl::write_xlsx(empty_df, path = file)
    }
  )
  
  output$download_repo_xlsx <- downloadHandler(
    filename = function() {
      if (isTRUE(user_role() == "admin")) {
        paste0("AFRO_admin_data_repository_", Sys.Date(), ".xlsx")
      } else {
        paste0("AFRO_admin_data_repository_", gsub(" ", "_", user_country()), "_", Sys.Date(), ".xlsx")
      }
    },
    content = function(file) writexl::write_xlsx(repo_country(), path = file)
  )
  
  output$download_repo_rds <- downloadHandler(
    filename = function() {
      if (isTRUE(user_role() == "admin")) {
        paste0("AFRO_admin_data_repository_", Sys.Date(), ".rds")
      } else {
        paste0("AFRO_admin_data_repository_", gsub(" ", "_", user_country()), ".rds")
      }
    },
    content = function(file) saveRDS(repo_country(), file)
  )
  
  # ---------------------------
  # Manual entry table
  # ---------------------------
  output$manual_table <- renderDT({
    req(manual_data())
    datatable(
      manual_data(),
      editable = list(target = "cell", disable = list(columns = 0)),
      selection = "single",
      extensions = c("KeyTable", "Buttons"),
      options = list(
        pageLength = 10,
        scrollX = TRUE,
        scrollY = 400,
        keys = TRUE,
        dom = "Bfrtip",
        buttons = c("copy", "csv", "excel")
      ),
      class = "display compact hover row-border stripe"
    )
  }, server = TRUE)
  
  observeEvent(input$manual_table_cell_edit, {
    req(manual_data())
    info <- input$manual_table_cell_edit
    df <- manual_data()
    col_name <- names(df)[info$col + 1]
    
    if (col_name == "SIA_date") {
      df[info$row, col_name] <- parse_sia_date(info$value)
    } else if (col_name %in% names(df) && is.numeric(df[[col_name]])) {
      df[info$row, col_name] <- suppressWarnings(as.numeric(info$value))
    } else {
      df[info$row, col_name] <- info$value
    }
    
    if (isTRUE(user_role() != "admin") && "Country" %in% names(df)) df$Country <- user_country()
    df <- normalize_admin_dates(df)
    df <- convert_geo(df)
    manual_data(df)
  })
  
  observeEvent(input$add_manual_row, {
    req(user_country())
    df <- manual_data()
    if (is.null(df)) df <- make_empty_df_from_schema(template_schema, n_rows = 0)
    
    new_row <- make_empty_df_from_schema(template_schema, n_rows = 1)
    df <- bind_rows(df, new_row)
    
    if ("Entry_Date" %in% names(df)) df$Entry_Date[nrow(df)] <- Sys.Date()
    if (isTRUE(user_role() != "admin") && "Country" %in% names(df)) df$Country[nrow(df)] <- user_country()
    
    df <- normalize_admin_dates(df)
    df <- convert_geo(df)
    manual_data(df)
    showNotification("New row added. Double-click cells to edit.", type = "message", duration = 2)
  })
  
  observeEvent(input$delete_manual_row, {
    req(manual_data())
    df <- manual_data()
    selected <- input$manual_table_rows_selected
    
    if (is.null(selected) || length(selected) == 0) {
      showNotification("Please select a row to delete.", type = "warning")
      return(NULL)
    }
    
    df <- df[-selected, , drop = FALSE]
    if (nrow(df) == 0) {
      df <- make_empty_df_from_schema(template_schema, n_rows = 1)
      if ("Entry_Date" %in% names(df)) df$Entry_Date[1] <- Sys.Date()
      if (isTRUE(user_role() != "admin") && "Country" %in% names(df)) df$Country[1] <- user_country()
    }
    
    df <- normalize_admin_dates(df)
    df <- convert_geo(df)
    manual_data(df)
    showNotification("Row deleted from manual grid.", type = "message")
  })
  
  observeEvent(input$append_manual_rows, {
    req(user_country(), manual_data())
    df <- manual_data()
    
    non_empty <- df %>%
      filter(!if_all(everything(), ~ is.na(.) | trimws(as.character(.)) == ""))
    
    if (nrow(non_empty) == 0) {
      showNotification("No non-empty rows to append.", type = "warning")
      return(NULL)
    }
    
    if (isTRUE(user_role() != "admin") && "Country" %in% names(non_empty)) non_empty$Country <- user_country()
    if ("Entry_Date" %in% names(non_empty)) non_empty$Entry_Date <- Sys.Date()
    
    non_empty <- normalize_admin_dates(non_empty)
    repo <- admin_repo()
    repo <- bind_rows(repo, non_empty)
    repo <- convert_geo(repo)
    repo <- ensure_rowid_keyid(repo)
    repo <- recalculate_percentages(repo)
    
    # IMPORTANT: DO NOT auto-remove duplicates here
    save_repo(repo)
    admin_repo(repo)
    
    showNotification(
      paste("Added", nrow(non_empty), "record(s). Duplicates, if any, are retained for management."),
      type = "message"
    )
    
    df_new <- make_empty_df_from_schema(template_schema, n_rows = 1)
    if ("Entry_Date" %in% names(df_new)) df_new$Entry_Date[1] <- Sys.Date()
    if (isTRUE(user_role() != "admin") && "Country" %in% names(df_new)) df_new$Country[1] <- user_country()
    df_new <- normalize_admin_dates(df_new)
    df_new <- convert_geo(df_new)
    manual_data(df_new)
  })
  
  # ---------------------------
  # File upload
  # ---------------------------
  observeEvent(input$add_file, {
    req(input$upload_file, user_country())
    
    new_data <- tryCatch(
      read_excel(input$upload_file$datapath),
      error = function(e) {
        showNotification(e$message, type = "error")
        return(NULL)
      }
    )
    req(!is.null(new_data))
    
    new_data <- normalize_admin_dates(new_data)
    schema_cols <- template_schema$column_names
    
    if (!setequal(names(new_data), schema_cols)) {
      showNotification("Uploaded file columns do not match the template.", type = "error")
      return(NULL)
    }
    
    new_data <- new_data %>% select(all_of(schema_cols))
    new_data <- convert_geo(new_data)
    
    if (isTRUE(user_role() != "admin") && "Country" %in% names(new_data)) {
      if (any(!is.na(new_data$Country) & new_data$Country != user_country())) {
        showNotification(
          paste0("Uploaded file contains rows for another country. Only '", user_country(), "' is allowed."),
          type = "error"
        )
        return(NULL)
      }
      new_data$Country <- user_country()
    }
    
    if ("Entry_Date" %in% names(new_data)) new_data$Entry_Date <- Sys.Date()
    
    repo <- admin_repo()
    repo <- bind_rows(repo, new_data)
    repo <- convert_geo(repo)
    repo <- ensure_rowid_keyid(repo)
    repo <- recalculate_percentages(repo)
    
    # IMPORTANT: DO NOT auto-remove duplicates here
    save_repo(repo)
    admin_repo(repo)
    
    showNotification("File data appended successfully. Duplicates are retained for review.", type = "message")
  })
  
  # ---------------------------
  # Repository preview
  # ---------------------------
  output$repo_table <- renderDT({
    req(user_country())
    datatable(
      repo_country(),
      extensions = c("Scroller", "Buttons", "KeyTable"),
      options = list(
        pageLength = 25,
        scrollX = TRUE,
        scrollY = 500,
        scroller = TRUE,
        keys = TRUE,
        dom = "Bfrtip",
        buttons = c("copy", "csv", "excel", "pdf")
      ),
      class = "display compact hover row-border stripe"
    )
  }, server = TRUE)
  
  output$column_info <- renderTable({
    tibble(
      column_name = template_schema$column_names,
      column_type = unname(template_schema$column_types[template_schema$column_names])
    )
  })
  
  output$tokens_table <- renderDT({
    req(isTRUE(user_role() == "admin"))
    datatable(
      tokens_tbl,
      extensions = c("Scroller", "Buttons"),
      options = list(
        pageLength = 20,
        scrollX = TRUE,
        scrollY = 520,
        scroller = TRUE,
        dom = "Bfrtip",
        buttons = c("copy", "csv", "excel")
      ),
      class = "display compact hover row-border stripe"
    )
  }, server = TRUE)
  
  # ---------------------------
  # Duplicate helpers for UI
  # ---------------------------
  output$recalculation_help <- renderUI({
    duplicates <- find_all_duplicates(admin_repo())
    if (nrow(duplicates) == 0) return(NULL)
    
    div(
      style = "background: #e8f4fd; border-left: 3px solid #0066b3; border-radius: 4px; padding: 10px; margin-bottom: 15px; font-size: 12px;",
      strong("Automatic Recalculation After Merge:"),
      tags$ul(
        style = "margin-top: 5px; margin-bottom: 0; padding-left: 20px;",
        tags$li("CVPolio = (TotalNbrVaccPolio / PopPolio) × 100"),
        tags$li("Prop_0dosesPolio = Total_Nbr_0doseVaccPolio_0_59M / TotalNbrVaccPolio"),
        tags$li("WastRPolio = (TotalDoses - Doses.UsedPolio) / TotalDoses × 100")
      )
    )
  })
  
  output$duplicate_panel <- renderUI({
    all_duplicates <- find_all_duplicates(admin_repo())
    
    if (nrow(all_duplicates) == 0) {
      return(
        div(
          class = "alert alert-success",
          style = "border-radius: 4px; padding: 15px;",
          icon("check-circle"), " No duplicates found in the repository."
        )
      )
    }
    
    div(
      class = "excel-panel",
      div(class = "excel-title", "Duplicate Management"),
      div(
        class = "excel-subtitle",
        paste(
          "Found", nrow(all_duplicates), "records in",
          length(unique(all_duplicates$duplicate_group)), "duplicate groups"
        )
      ),
      
      uiOutput("recalculation_help"),
      
      div(
        style = "margin-bottom: 15px;",
        strong("Merge Strategy: "),
        radioButtons(
          "merge_strategy", NULL,
          choices = c(
            "Weighted Average for Rates (Recommended)" = "weighted_average",
            "Sum All Numeric Values" = "sum_numeric",
            "Mean of Rates" = "mean_numeric",
            "Keep Maximum Values" = "max_numeric",
            "Keep Minimum Values" = "min_numeric"
          ),
          selected = "weighted_average",
          inline = FALSE
        )
      ),
      
      div(
        style = "margin-bottom: 15px;",
        sliderInput(
          "dup_confidence_threshold",
          "Partial Duplicate Confidence Threshold",
          min = 50, max = 100, value = 85, step = 5
        ),
        div(class = "small-note", "Potential partial duplicates are shown below this section.")
      ),
      
      div(
        style = "margin-bottom: 10px; display: flex; gap: 8px; flex-wrap: wrap;",
        actionButton("keep_first_rows_all", "Keep ALL First Rows", class = "btn-info"),
        actionButton("apply_merge_all", "Merge ALL Duplicate Groups", class = "btn-warning"),
        actionButton("preview_merge", "Preview Merge", class = "btn-primary")
      ),
      
      div(
        style = "margin-bottom: 10px; display: flex; gap: 8px; flex-wrap: wrap;",
        actionButton("keep_first_rows_selected", "Keep First Row of Selected", class = "btn-success"),
        actionButton("merge_selected_group", "Merge Selected Group", class = "btn-primary"),
        actionButton("keep_selected_rows", "Keep Selected Rows", class = "btn-info"),
        actionButton("delete_selected_rows", "Delete Selected Rows", class = "btn-danger"),
        actionButton("edit_selected_duplicate", "Edit Selected Row", class = "btn-warning")
      ),
      
      div(
        style = "margin-bottom: 10px;",
        actionButton("find_partial_duplicates", "Find Partial Duplicates", class = "btn-secondary")
      ),
      
      DTOutput("all_duplicates_table"),
      
      br(),
      div(class = "excel-title", "Partial Duplicates (Potential Matches)"),
      div(class = "excel-subtitle", "Rows that are similar but not exact duplicates."),
      DTOutput("partial_duplicates_table")
    )
  })
  
  output$all_duplicates_table <- renderDT({
    duplicates <- find_all_duplicates(admin_repo())
    if (nrow(duplicates) == 0) {
      return(datatable(data.frame(Message = "No duplicates found"), options = list(dom = "t")))
    }
    
    datatable(
      duplicates,
      selection = "multiple",
      filter = "top",
      extensions = c("Scroller", "Buttons", "KeyTable"),
      options = list(
        pageLength = 10,
        scrollX = TRUE,
        scrollY = 450,
        scroller = TRUE,
        keys = TRUE,
        dom = "Bfrtip",
        buttons = c("copy", "csv", "excel")
      ),
      class = "display compact hover row-border stripe"
    )
  }, server = TRUE)
  
  output$partial_duplicates_table <- renderDT({
    input$find_partial_duplicates
    repo <- admin_repo()
    
    partials <- find_partial_duplicates(
      repo,
      threshold = input$dup_confidence_threshold %||% 85
    )
    
    if (nrow(partials) == 0) {
      return(datatable(data.frame(Message = "No partial duplicates found above threshold"), options = list(dom = "t")))
    }
    
    show_cols <- c("Country", "Province", "District", "SIA_date", "Round_Add", "Vaccine_type", "Response")
    
    partials$record_1 <- vapply(partials$KEY_ID_1, function(kid) {
      row <- repo[repo$KEY_ID == kid, , drop = FALSE][1, , drop = FALSE]
      cols <- intersect(show_cols, names(row))
      paste(paste(cols, as.character(unlist(row[cols])), sep = ": "), collapse = " | ")
    }, character(1))
    
    partials$record_2 <- vapply(partials$KEY_ID_2, function(kid) {
      row <- repo[repo$KEY_ID == kid, , drop = FALSE][1, , drop = FALSE]
      cols <- intersect(show_cols, names(row))
      paste(paste(cols, as.character(unlist(row[cols])), sep = ": "), collapse = " | ")
    }, character(1))
    
    datatable(
      partials[, c("KEY_ID_1", "KEY_ID_2", "confidence", "record_1", "record_2")],
      selection = "multiple",
      extensions = c("Scroller", "Buttons"),
      options = list(
        pageLength = 10,
        scrollX = TRUE,
        scrollY = 300,
        dom = "Bfrtip",
        buttons = c("copy", "csv", "excel")
      ),
      colnames = c("Key ID 1", "Key ID 2", "Confidence %", "Record 1", "Record 2"),
      class = "display compact hover row-border stripe"
    )
  }, server = TRUE)
  
  # ---------------------------
  # Duplicate actions
  # ---------------------------
  observeEvent(input$keep_first_rows_all, {
    duplicates <- find_all_duplicates(admin_repo())
    if (nrow(duplicates) == 0) {
      showNotification("No duplicates to process.", type = "info")
      return(NULL)
    }
    
    group_count <- length(unique(duplicates$duplicate_group))
    rows_to_delete <- nrow(duplicates) - group_count
    
    showModal(modalDialog(
      title = "Keep First Row of Each Duplicate Group",
      p(paste("This will keep only the FIRST row from each of the", group_count, "duplicate group(s).")),
      p(paste(rows_to_delete, "row(s) will be deleted."), style = "color: #dc3545;"),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_keep_first_all", "Confirm", class = "btn-primary")
      )
    ))
  })
  
  observeEvent(input$confirm_keep_first_all, {
    repo <- admin_repo()
    duplicates <- find_all_duplicates(repo)
    
    rows_to_keep <- duplicates %>%
      group_by(KEY_ID) %>%
      slice_min(ROW_ID, n = 1, with_ties = FALSE) %>%
      pull(ROW_ID)
    
    non_dup <- repo %>% filter(!(KEY_ID %in% duplicates$KEY_ID))
    rows_to_keep <- c(rows_to_keep, non_dup$ROW_ID)
    
    repo <- repo %>% filter(ROW_ID %in% rows_to_keep)
    repo <- ensure_rowid_keyid(repo)
    save_repo(repo)
    admin_repo(repo)
    removeModal()
    
    showNotification("Kept first row of each duplicate group.", type = "message")
  })
  
  observeEvent(input$keep_first_rows_selected, {
    req(input$all_duplicates_table_rows_selected)
    duplicates <- find_all_duplicates(admin_repo())
    selected_groups <- unique(duplicates$duplicate_group[input$all_duplicates_table_rows_selected])
    
    if (length(selected_groups) == 0) {
      showNotification("Please select rows from duplicate groups to process.", type = "warning")
      return(NULL)
    }
    
    session$userData$selected_groups_to_keep <- selected_groups
    
    showModal(modalDialog(
      title = "Keep First Row of Selected Duplicate Groups",
      p(paste("This will keep only the first row in", length(selected_groups), "selected group(s).")),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_keep_first_selected", "Confirm", class = "btn-success")
      )
    ))
  })
  
  observeEvent(input$confirm_keep_first_selected, {
    req(session$userData$selected_groups_to_keep)
    repo <- admin_repo()
    duplicates <- find_all_duplicates(repo)
    selected_groups <- session$userData$selected_groups_to_keep
    
    selected_dups <- duplicates %>% filter(duplicate_group %in% selected_groups)
    rows_to_keep_selected <- selected_dups %>%
      group_by(KEY_ID) %>%
      slice_min(ROW_ID, n = 1, with_ties = FALSE) %>%
      pull(ROW_ID)
    
    rows_from_other_dups <- duplicates %>%
      filter(!(duplicate_group %in% selected_groups)) %>%
      pull(ROW_ID)
    
    non_dup <- repo %>% filter(!(KEY_ID %in% duplicates$KEY_ID)) %>% pull(ROW_ID)
    rows_to_keep <- c(rows_to_keep_selected, rows_from_other_dups, non_dup)
    
    repo <- repo %>% filter(ROW_ID %in% rows_to_keep)
    repo <- ensure_rowid_keyid(repo)
    save_repo(repo)
    admin_repo(repo)
    removeModal()
    session$userData$selected_groups_to_keep <- NULL
    
    showNotification("Selected duplicate groups processed.", type = "message")
  })
  
  observeEvent(input$apply_merge_all, {
    duplicates <- find_all_duplicates(admin_repo())
    if (nrow(duplicates) == 0) {
      showNotification("No duplicates to merge.", type = "info")
      return(NULL)
    }
    
    showModal(modalDialog(
      title = "Merge ALL Duplicate Groups",
      p("This will merge all exact duplicate groups using the selected strategy."),
      p("This action will overwrite duplicate groups with one merged record each.", style = "color: #dc3545;"),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_merge_all", "Merge All", class = "btn-warning")
      )
    ))
  })
  
  observeEvent(input$confirm_merge_all, {
    repo <- admin_repo()
    duplicates <- find_all_duplicates(repo)
    if (nrow(duplicates) == 0) {
      removeModal()
      return(NULL)
    }
    
    non_dup <- repo %>% filter(!(KEY_ID %in% duplicates$KEY_ID))
    merged_rows <- duplicates %>%
      group_by(KEY_ID) %>%
      group_split() %>%
      lapply(function(g) {
        out <- merge_duplicate_rows(as.data.frame(g), input$merge_strategy)
        hist <- merge_history()
        hist[[length(hist) + 1]] <- list(
          timestamp = Sys.time(),
          action = "merge_all",
          key_id = unique(g$KEY_ID),
          row_ids = g$ROW_ID,
          strategy = input$merge_strategy
        )
        merge_history(hist)
        out
      }) %>%
      bind_rows()
    
    repo <- bind_rows(non_dup, merged_rows)
    repo <- ensure_rowid_keyid(repo)
    repo <- recalculate_percentages(repo)
    save_repo(repo)
    admin_repo(repo)
    removeModal()
    
    showNotification("All duplicate groups merged.", type = "message")
  })
  
  observeEvent(input$merge_selected_group, {
    req(input$all_duplicates_table_rows_selected)
    duplicates <- find_all_duplicates(admin_repo())
    selected_groups <- unique(duplicates$duplicate_group[input$all_duplicates_table_rows_selected])
    
    if (length(selected_groups) == 0) {
      showNotification("Please select rows from the duplicate group(s) to merge.", type = "warning")
      return(NULL)
    }
    
    repo <- admin_repo()
    groups_to_merge <- duplicates %>% filter(duplicate_group %in% selected_groups)
    key_ids_to_merge <- unique(groups_to_merge$KEY_ID)
    
    keep_part <- repo %>% filter(!(KEY_ID %in% key_ids_to_merge))
    merged_part <- lapply(key_ids_to_merge, function(kid) {
      g <- repo %>% filter(KEY_ID == kid)
      out <- merge_duplicate_rows(g, input$merge_strategy)
      
      hist <- merge_history()
      hist[[length(hist) + 1]] <- list(
        timestamp = Sys.time(),
        action = "merge_selected",
        key_id = kid,
        row_ids = g$ROW_ID,
        strategy = input$merge_strategy
      )
      merge_history(hist)
      
      out
    }) %>% bind_rows()
    
    repo <- bind_rows(keep_part, merged_part)
    repo <- ensure_rowid_keyid(repo)
    repo <- recalculate_percentages(repo)
    save_repo(repo)
    admin_repo(repo)
    
    showNotification("Selected duplicate group(s) merged successfully.", type = "message")
  })
  
  observeEvent(input$keep_selected_rows, {
    req(input$all_duplicates_table_rows_selected)
    repo <- admin_repo()
    duplicates <- find_all_duplicates(repo)
    selected_rows <- duplicates[input$all_duplicates_table_rows_selected, , drop = FALSE]
    
    if (nrow(selected_rows) == 0) {
      showNotification("Please select rows to keep.", type = "warning")
      return(NULL)
    }
    
    affected_keys <- unique(selected_rows$KEY_ID)
    repo_out <- repo
    
    for (kid in affected_keys) {
      selected_ids <- selected_rows %>% filter(KEY_ID == kid) %>% pull(ROW_ID)
      repo_out <- repo_out %>% filter(!(KEY_ID == kid & !(ROW_ID %in% selected_ids)))
    }
    
    repo_out <- ensure_rowid_keyid(repo_out)
    save_repo(repo_out)
    admin_repo(repo_out)
    
    showNotification("Selected rows kept. Other rows in those duplicate groups were removed.", type = "message")
  })
  
  observeEvent(input$delete_selected_rows, {
    req(input$all_duplicates_table_rows_selected)
    repo <- admin_repo()
    duplicates <- find_all_duplicates(repo)
    selected_rows <- duplicates[input$all_duplicates_table_rows_selected, , drop = FALSE]
    
    if (nrow(selected_rows) == 0) {
      showNotification("Please select rows to delete.", type = "warning")
      return(NULL)
    }
    
    repo <- repo %>% filter(!(ROW_ID %in% selected_rows$ROW_ID))
    repo <- ensure_rowid_keyid(repo)
    save_repo(repo)
    admin_repo(repo)
    
    showNotification("Selected duplicate row(s) deleted.", type = "message")
  })
  
  observeEvent(input$preview_merge, {
    req(input$all_duplicates_table_rows_selected)
    duplicates <- find_all_duplicates(admin_repo())
    selected_groups <- unique(duplicates$duplicate_group[input$all_duplicates_table_rows_selected])
    
    if (length(selected_groups) == 0) {
      showNotification("Please select rows from the duplicate group(s) to preview.", type = "warning")
      return(NULL)
    }
    
    preview_keys <- duplicates %>%
      filter(duplicate_group %in% selected_groups) %>%
      pull(KEY_ID) %>%
      unique()
    
    repo <- admin_repo()
    preview_list <- lapply(preview_keys, function(kid) {
      orig <- repo %>% filter(KEY_ID == kid)
      merged <- merge_duplicate_rows(orig, input$merge_strategy)
      list(key_id = kid, original = orig, merged = merged)
    })
    
    session$userData$preview_groups <- selected_groups
    session$userData$preview_list <- preview_list
    
    showModal(modalDialog(
      title = "Merge Preview",
      size = "l",
      uiOutput("preview_merge_content"),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_merge_from_preview", "Proceed with Merge", class = "btn-primary")
      )
    ))
  })
  
  output$preview_merge_content <- renderUI({
    req(session$userData$preview_list)
    pl <- session$userData$preview_list
    
    tagList(
      lapply(seq_along(pl), function(i) {
        item <- pl[[i]]
        div(
          style = "margin-bottom: 25px;",
          h5(paste("Group", i)),
          div(class = "small-note", paste("KEY_ID:", item$key_id)),
          h6("Original rows"),
          DTOutput(paste0("preview_orig_", i)),
          h6("Merged result"),
          DTOutput(paste0("preview_merged_", i)),
          tags$hr()
        )
      })
    )
  })
  
  observe({
    req(session$userData$preview_list)
    pl <- session$userData$preview_list
    for (i in seq_along(pl)) {
      local({
        ii <- i
        output[[paste0("preview_orig_", ii)]] <- renderDT({
          datatable(pl[[ii]]$original, options = list(pageLength = 5, scrollX = TRUE), class = "display compact")
        })
        output[[paste0("preview_merged_", ii)]] <- renderDT({
          datatable(pl[[ii]]$merged, options = list(pageLength = 1, scrollX = TRUE), class = "display compact")
        })
      })
    }
  })
  
  observeEvent(input$confirm_merge_from_preview, {
    req(session$userData$preview_groups)
    repo <- admin_repo()
    duplicates <- find_all_duplicates(repo)
    selected_groups <- session$userData$preview_groups
    
    key_ids_to_merge <- duplicates %>%
      filter(duplicate_group %in% selected_groups) %>%
      pull(KEY_ID) %>%
      unique()
    
    keep_part <- repo %>% filter(!(KEY_ID %in% key_ids_to_merge))
    merged_part <- lapply(key_ids_to_merge, function(kid) {
      g <- repo %>% filter(KEY_ID == kid)
      merge_duplicate_rows(g, input$merge_strategy)
    }) %>% bind_rows()
    
    repo <- bind_rows(keep_part, merged_part)
    repo <- ensure_rowid_keyid(repo)
    repo <- recalculate_percentages(repo)
    save_repo(repo)
    admin_repo(repo)
    
    removeModal()
    session$userData$preview_groups <- NULL
    session$userData$preview_list <- NULL
    
    showNotification("Previewed duplicate groups merged successfully.", type = "message")
  })
  
  # ---------------------------
  # Edit selected duplicate row
  # ---------------------------
  observeEvent(input$edit_selected_duplicate, {
    req(input$all_duplicates_table_rows_selected)
    duplicates <- find_all_duplicates(admin_repo())
    selected_row <- duplicates[input$all_duplicates_table_rows_selected[1], , drop = FALSE]
    
    session$userData$editing_row <- selected_row
    
    showModal(modalDialog(
      title = paste("Edit Row - Duplicate Group", selected_row$duplicate_group),
      size = "l",
      div(
        p("Edit values below. Changes may affect duplicate status."),
        hr(),
        uiOutput("edit_row_ui")
      ),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("save_row_edit", "Save Changes", class = "btn-primary")
      )
    ))
  })
  
  output$edit_row_ui <- renderUI({
    req(session$userData$editing_row)
    df_row <- session$userData$editing_row
    
    important_cols <- c(
      duplicate_key_cols,
      "Province", "District",
      "TotalNbrVaccPolio", "Total_Nbr_0doseVaccPolio_0_59M",
      "WastRPolio", "Doses.UsedPolio", "TotalDoses", "PopPolio"
    )
    
    cols_to_show <- unique(intersect(important_cols, names(df_row)))
    
    inputs <- lapply(cols_to_show, function(col) {
      val <- df_row[[col]]
      
      if (col == "SIA_date") {
        dateInput(paste0("edit_", col), col, value = as.Date(val))
      } else if (is.numeric(val)) {
        numericInput(paste0("edit_", col), col, value = suppressWarnings(as.numeric(val)))
      } else {
        textInput(paste0("edit_", col), col, value = as.character(val))
      }
    })
    
    tagList(inputs)
  })
  
  observeEvent(input$save_row_edit, {
    req(session$userData$editing_row)
    edited_row <- session$userData$editing_row
    repo <- admin_repo()
    
    row_idx <- which(repo$ROW_ID == edited_row$ROW_ID[1])
    if (length(row_idx) == 0) {
      showNotification("Unable to locate selected row in repository.", type = "error")
      return(NULL)
    }
    
    for (col in names(repo)) {
      id <- paste0("edit_", col)
      if (!is.null(input[[id]]) && col != "ROW_ID" && col != "KEY_ID") {
        if (col == "SIA_date") {
          repo[row_idx, col] <- as.Date(input[[id]])
        } else if (is.numeric(repo[[col]])) {
          repo[row_idx, col] <- suppressWarnings(as.numeric(input[[id]]))
        } else {
          repo[row_idx, col] <- as.character(input[[id]])
        }
      }
    }
    
    repo <- normalize_admin_dates(repo)
    repo <- ensure_rowid_keyid(repo)
    repo <- recalculate_percentages(repo)
    
    save_repo(repo)
    admin_repo(repo)
    removeModal()
    
    showNotification("Row updated successfully.", type = "message")
  })
  
  # ---------------------------
  # Edit repository tab
  # ---------------------------
  output$edit_table <- renderDT({
    req(repo_country())
    datatable(
      repo_country(),
      editable = list(target = "cell", disable = list(columns = 0)),
      filter = "top",
      extensions = c("KeyTable", "Buttons"),
      options = list(
        pageLength = 25,
        scrollX = TRUE,
        scrollY = 500,
        keys = TRUE,
        dom = "Bfrtip",
        buttons = c("copy", "csv", "excel")
      ),
      class = "display compact hover row-border stripe"
    )
  }, server = TRUE)
  
  observeEvent(input$edit_table_cell_edit, {
    info <- input$edit_table_cell_edit
    repo <- admin_repo()
    col_name <- names(repo)[info$col + 1]
    
    if (col_name == "SIA_date") {
      repo[info$row, col_name] <- parse_sia_date(info$value)
    } else if (is.numeric(repo[[col_name]])) {
      repo[info$row, col_name] <- suppressWarnings(as.numeric(info$value))
    } else {
      repo[info$row, col_name] <- info$value
    }
    
    repo <- normalize_admin_dates(repo)
    repo <- ensure_rowid_keyid(repo)
    repo <- recalculate_percentages(repo)
    
    save_repo(repo)
    admin_repo(repo)
  })
  
  # ---------------------------
  # Merge history
  # ---------------------------
  output$merge_history_table <- renderDT({
    hist <- merge_history()
    if (length(hist) == 0) {
      return(datatable(data.frame(Message = "No merge actions recorded in this session."), options = list(dom = "t")))
    }
    
    hist_df <- bind_rows(lapply(hist, function(x) {
      tibble(
        timestamp = as.character(x$timestamp),
        action = x$action %||% NA_character_,
        key_id = paste(x$key_id %||% "", collapse = ", "),
        row_ids = paste(x$row_ids %||% "", collapse = ", "),
        strategy = x$strategy %||% NA_character_
      )
    }))
    
    datatable(
      hist_df,
      extensions = c("Buttons"),
      options = list(scrollX = TRUE, dom = "Bfrtip", buttons = c("copy", "csv", "excel")),
      class = "display compact hover row-border stripe"
    )
  }, server = TRUE)
  
  # ---------------------------
  # Main app body
  # ---------------------------
  output$app_body <- renderUI({
    if (is.null(user_country())) {
      return(
        fluidRow(
          column(
            width = 4, offset = 4,
            br(), br(),
            div(
              style = "background: white; border-radius: 8px; padding: 25px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); text-align: center;",
              div(
                style = "margin-bottom: 20px;",
                h3("WHO AFRO", style = "color: #0066b3; margin: 0;")
              ),
              h4("Administrative Data Portal", style = "margin-top: 0; color: #333;"),
              div("Polio Eradication Program", style = "margin-bottom: 20px; color: #666; font-size: 13px;"),
              hr(),
              div("Please enter your access token to continue.", style = "margin-bottom: 20px; color: #555;"),
              passwordInput("access_token", "Access token", width = "100%"),
              actionButton("login_btn", "Login to Portal", class = "btn-primary", style = "width: 100%; margin-top: 10px;"),
              br(), br(),
              tags$small("If you do not have a token, please contact the regional administrator.", style = "color: #999;")
            )
          )
        )
      )
    }
    
    fluidPage(
      fluidRow(
        column(
          width = 12,
          div(
            class = "excel-panel",
            fluidRow(
              column(
                width = 4,
                checkboxInput("dark_mode", "Dark mode", value = FALSE)
              ),
              column(
                width = 8,
                div(
                  style = "text-align: right; padding-top: 6px;",
                  strong("Logged in as: "),
                  if (isTRUE(user_role() == "admin")) "Administrator" else paste0(user_country(), " focal point")
                )
              )
            )
          )
        )
      ),
      
      tabsetPanel(
        id = "main_tabs",
        
        tabPanel(
          "Data Entry",
          br(),
          fluidRow(
            column(
              width = 3,
              div(
                class = "excel-panel",
                div(class = "excel-title", "Template & Upload"),
                downloadButton("download_empty_template", "Download Empty Template", class = "btn-info"),
                br(), br(),
                fileInput("upload_file", "Upload completed template (.xlsx)", accept = c(".xlsx")),
                actionButton("add_file", "Append Uploaded File", class = "btn-primary"),
                hr(),
                div(class = "small-note", "Uploaded data are appended without silently deleting duplicates.")
              )
            ),
            column(
              width = 9,
              div(
                class = "excel-panel",
                div(class = "excel-title", "Manual Entry Grid"),
                div(
                  style = "margin-bottom: 10px;",
                  actionButton("add_manual_row", "Add Row", class = "btn-success"),
                  actionButton("delete_manual_row", "Delete Selected Row", class = "btn-danger"),
                  actionButton("append_manual_rows", "Append to Repository", class = "btn-primary")
                ),
                DTOutput("manual_table")
              )
            )
          )
        ),
        
        tabPanel(
          "Repository Preview",
          br(),
          div(
            class = "excel-panel",
            div(class = "excel-title", "Current Repository"),
            downloadButton("download_repo_xlsx", "Download XLSX", class = "btn-info"),
            downloadButton("download_repo_rds", "Download RDS", class = "btn-secondary"),
            br(), br(),
            DTOutput("repo_table")
          )
        ),
        
        tabPanel(
          "Manage Duplicates",
          br(),
          uiOutput("duplicate_panel")
        ),
        
        tabPanel(
          "Edit Repository",
          br(),
          div(
            class = "excel-panel",
            div(class = "excel-title", "Edit Repository in Place"),
            div(class = "small-note", "Double-click a cell to edit."),
            br(),
            DTOutput("edit_table")
          )
        ),
        
        tabPanel(
          "Schema / Help",
          br(),
          fluidRow(
            column(
              width = 7,
              div(
                class = "excel-panel",
                div(class = "excel-title", "Template Columns"),
                tableOutput("column_info")
              )
            ),
            column(
              width = 5,
              div(
                class = "excel-panel",
                div(class = "excel-title", "Duplicate Key Used"),
                tags$ul(lapply(duplicate_key_cols, tags$li)),
                hr(),
                div(class = "small-note", "Exact duplicates are defined on the normalized combination of these fields.")
              )
            )
          )
        ),
        
        tabPanel(
          "Merge History",
          br(),
          div(
            class = "excel-panel",
            div(class = "excel-title", "Session Merge History"),
            DTOutput("merge_history_table")
          )
        ),
        
        if (isTRUE(user_role() == "admin")) {
          tabPanel(
            "Admin Tokens",
            br(),
            div(
              class = "excel-panel",
              div(class = "excel-title", "Country Access Tokens"),
              DTOutput("tokens_table")
            )
          )
        }
      )
    )
  })
}

shinyApp(ui, server)