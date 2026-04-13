# =============================================================
# WHO AFRO Admin Data Portal – Country Focal Point Interface
# Complete Excel-like View with WHO Branding
# ENHANCED DUPLICATE DETECTION & MANAGEMENT
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
# 0. Admin token (for you)
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
# Paths & Template
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
# KEY DEFINITIONS
# -----------------------------
duplicate_key_cols <- c("Country", "Province", "District", "SIA_date",
                        "Round_Add", "Vaccine_type", "Response")

count_columns <- c(
  "Nbr0dosesVaccPolio_0_11M", "Nbr_1doses_Plus_VacPolio_0_11M",
  "Nbr0dosesVacPolio_12_59M", "Nbr_1doses_Plus_VacPolio_12_59M",
  "Total_Nbr_0doseVaccPolio_0_59M", "Total_Nbr_1dose_Plus_vaccPolio_0_59M",
  "TotalNbrVaccPolio", "PopPolio", "Doses.UsedPolio", "TotalDoses"
)

rate_columns <- c("CVPolio", "WastRPolio", "Prop_0dosesPolio", 
                  "Nbr0dosePct_0_11M", "Nbr0dosePct_12_59M")

geo_columns <- c("Admin_1","Admin_2","Admin_3","Admin_4",
                 "Country","Region","District","Ward","Village")

# -----------------------------
# IMPROVED KEY NORMALIZATION (handles NA better)
# -----------------------------
.clean_key_vec <- function(v) {
  v <- as.character(v)
  # Keep NA as NA, only convert empty strings
  v[v == ""] <- "EMPTY"
  v <- toupper(trimws(v))
  v <- gsub("[[:space:]]+", "_", v)
  v <- gsub("[^A-Za-z0-9_\\-]", "", v)
  v[v == ""] <- "EMPTY"
  # Return NA for actual NAs
  v[v == "NA"] <- NA_character_
  v
}

.format_sia_key <- function(v) {
  dv <- parse_sia_date(v)
  out <- format(dv, "%Y-%m-%d")
  out[is.na(dv)] <- NA_character_
  out
}

# -----------------------------
# CONFIDENCE SCORE FOR DUPLICATES
# -----------------------------
calculate_duplicate_confidence <- function(row1, row2, key_cols = duplicate_key_cols) {
  matches <- 0
  total <- 0
  
  for (col in key_cols) {
    val1 <- row1[[col]]
    val2 <- row2[[col]]
    
    # Only count if both are non-NA
    if (!is.na(val1) && !is.na(val2) && val1 != "" && val2 != "") {
      total <- total + 1
      # Normalize for comparison
      norm1 <- .clean_key_vec(val1)
      norm2 <- .clean_key_vec(val2)
      if (!is.na(norm1) && !is.na(norm2) && norm1 == norm2) {
        matches <- matches + 1
      }
    }
  }
  
  if (total == 0) return(0)
  return(round((matches / total) * 100, 1))
}

# -----------------------------
# FUZZY PARTIAL DUPLICATE DETECTION
# -----------------------------
find_partial_duplicates <- function(df, threshold = 0.85, key_cols = duplicate_key_cols) {
  if (nrow(df) < 2) return(data.frame())
  
  df <- ensure_rowid_keyid(df)
  partials <- list()
  
  # Get all unique keys
  unique_keys <- unique(df$KEY_ID)
  if (length(unique_keys) < 2) return(data.frame())
  
  for (i in 1:(length(unique_keys) - 1)) {
    key1 <- unique_keys[i]
    rows1 <- df[df$KEY_ID == key1, , drop = FALSE]
    row1 <- rows1[1, ]  # Representative row
    
    for (j in (i+1):length(unique_keys)) {
      key2 <- unique_keys[j]
      rows2 <- df[df$KEY_ID == key2, , drop = FALSE]
      row2 <- rows2[1, ]
      
      # Calculate confidence
      confidence <- calculate_duplicate_confidence(row1, row2, key_cols)
      
      if (confidence >= threshold && confidence < 100) {
        partials[[length(partials) + 1]] <- data.frame(
          KEY_ID_1 = key1,
          KEY_ID_2 = key2,
          confidence = confidence,
          stringsAsFactors = FALSE
        )
      }
    }
  }
  
  if (length(partials) == 0) return(data.frame())
  do.call(rbind, partials)
}

# -----------------------------
# DATE + COLUMN NORMALIZATION
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
  s[s %in% c("", "NA", "NaN")] <- NA_character_
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
  
  parsed <- suppressWarnings(lubridate::parse_date_time(
    s,
    orders = c("Y-m-d H:M:S", "Y-m-d", "d-b-y", "d-b-Y", "d/m/Y", "m/d/Y"),
    tz = "UTC"
  ))
  as.Date(parsed)
}

normalize_admin_dates <- function(df) {
  df <- normalize_admin_columns(df)
  if ("SIA_date" %in% names(df)) df$SIA_date <- parse_sia_date(df$SIA_date)
  if ("Entry_Date" %in% names(df)) df$Entry_Date <- as.Date(df$Entry_Date)
  df
}

# -----------------------------
# TEMPLATE SCHEMA
# -----------------------------
guess_type_from_name <- function(nm) {
  nm0 <- tolower(nm)
  if (grepl("date", nm0) || nm %in% c("SIA_date", "Entry_Date")) return("Date")
  if (grepl("totpop|population|pop|target|ageg|num|count|dose|coverage|cv", nm0)) return("numeric")
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
# FAST KEY_ID (IMPROVED - handles NA properly)
# -----------------------------
create_unique_id_dt <- function(df) {
  available_cols <- intersect(duplicate_key_cols, names(df))
  if (length(available_cols) == 0) return(character(0))
  if (nrow(df) == 0) return(character(0))
  
  dt <- as.data.table(df)[, ..available_cols]
  
  for (col in available_cols) {
    if (col == "SIA_date") {
      dt[[col]] <- .format_sia_key(dt[[col]])
    } else {
      dt[[col]] <- .clean_key_vec(dt[[col]])
    }
  }
  
  # Create key with NA handling - use a special placeholder for NA
  dt[, KEY_ID := do.call(paste, c(lapply(.SD, function(x) ifelse(is.na(x), "___NA___", x)), sep = "|")), .SDcols = available_cols]
  dt[["KEY_ID"]]
}

# -----------------------------
# MERGE FUNCTIONS FOR DUPLICATES (WITH HISTORY TRACKING)
# -----------------------------

# Global variable to store merge history
merge_history <- reactiveVal(list())

track_merge <- function(original_rows, merged_row, strategy) {
  history_entry <- list(
    timestamp = Sys.time(),
    original_row_ids = original_rows$ROW_ID,
    original_key_ids = original_rows$KEY_ID,
    merge_strategy = strategy,
    user = Sys.getenv("USER", "unknown")
  )
  current_history <- merge_history()
  current_history[[length(current_history) + 1]] <- history_entry
  merge_history(current_history)
  
  # Add merge history as an attribute to the merged row
  attr(merged_row, "merge_history") <- history_entry
  merged_row
}

recalculate_percentages <- function(df) {
  if (all(c("TotalNbrVaccPolio", "PopPolio") %in% names(df)) && "CVPolio" %in% names(df)) {
    if (!is.na(df$TotalNbrVaccPolio) && !is.na(df$PopPolio) && df$PopPolio > 0) {
      df$CVPolio <- (df$TotalNbrVaccPolio / df$PopPolio) * 100
    }
  }
  
  if (all(c("Doses.UsedPolio", "TotalDoses") %in% names(df)) && "WastRPolio" %in% names(df)) {
    if (!is.na(df$Doses.UsedPolio) && !is.na(df$TotalDoses) && df$TotalDoses > 0) {
      doses_wasted <- df$TotalDoses - df$Doses.UsedPolio
      df$WastRPolio <- (doses_wasted / df$TotalDoses) * 100
    }
  }
  
  if (all(c("Total_Nbr_0doseVaccPolio_0_59M", "TotalNbrVaccPolio") %in% names(df)) &&
      "Prop_0dosesPolio" %in% names(df)) {
    if (!is.na(df$Total_Nbr_0doseVaccPolio_0_59M) && !is.na(df$TotalNbrVaccPolio) && df$TotalNbrVaccPolio > 0) {
      df$Prop_0dosesPolio <- df$Total_Nbr_0doseVaccPolio_0_59M / df$TotalNbrVaccPolio
    } else if (!is.na(df$Total_Nbr_0doseVaccPolio_0_59M) && df$Total_Nbr_0doseVaccPolio_0_59M == 0) {
      df$Prop_0dosesPolio <- 0
    } else {
      df$Prop_0dosesPolio <- NA
    }
  }
  
  if (all(c("Nbr0dosesVaccPolio_0_11M", "PopPolio_0_11M") %in% names(df)) &&
      "Nbr0dosePct_0_11M" %in% names(df)) {
    if (!is.na(df$Nbr0dosesVaccPolio_0_11M) && !is.na(df$PopPolio_0_11M) && df$PopPolio_0_11M > 0) {
      df$Nbr0dosePct_0_11M <- df$Nbr0dosesVaccPolio_0_11M / df$PopPolio_0_11M
    } else if (!is.na(df$Nbr0dosesVaccPolio_0_11M) && df$Nbr0dosesVaccPolio_0_11M == 0) {
      df$Nbr0dosePct_0_11M <- 0
    } else {
      df$Nbr0dosePct_0_11M <- NA
    }
  }
  
  if (all(c("Nbr0dosesVacPolio_12_59M", "PopPolio_12_59M") %in% names(df)) &&
      "Nbr0dosePct_12_59M" %in% names(df)) {
    if (!is.na(df$Nbr0dosesVacPolio_12_59M) && !is.na(df$PopPolio_12_59M) && df$PopPolio_12_59M > 0) {
      df$Nbr0dosePct_12_59M <- df$Nbr0dosesVacPolio_12_59M / df$PopPolio_12_59M
    } else if (!is.na(df$Nbr0dosesVacPolio_12_59M) && df$Nbr0dosesVacPolio_12_59M == 0) {
      df$Nbr0dosePct_12_59M <- 0
    } else {
      df$Nbr0dosePct_12_59M <- NA
    }
  }
  
  df
}

merge_duplicate_rows <- function(duplicate_group_df, merge_strategy = "weighted_average") {
  if (nrow(duplicate_group_df) == 1) return(duplicate_group_df)
  
  result <- duplicate_group_df[1, ]
  
  if ("SIA_date" %in% names(result)) {
    valid_dates <- duplicate_group_df$SIA_date[!is.na(duplicate_group_df$SIA_date)]
    result$SIA_date <- if (length(valid_dates) > 0) valid_dates[1] else NA
  }
  
  char_cols <- names(duplicate_group_df)[sapply(duplicate_group_df, is.character)]
  for (col in char_cols) {
    if (col %in% duplicate_key_cols) next
    non_empty <- duplicate_group_df[[col]][duplicate_group_df[[col]] != "" & !is.na(duplicate_group_df[[col]])]
    result[[col]] <- if (length(non_empty) > 0) non_empty[1] else result[[col]]
  }
  
  if (merge_strategy == "weighted_average") {
    for (col in count_columns) {
      if (col %in% names(duplicate_group_df)) {
        result[[col]] <- sum(duplicate_group_df[[col]], na.rm = TRUE)
        if (is.na(result[[col]]) || result[[col]] == 0) result[[col]] <- NA
      }
    }
    
    if ("CVPolio" %in% names(result) && "TotalNbrVaccPolio" %in% names(duplicate_group_df) && 
        "PopPolio" %in% names(duplicate_group_df)) {
      total_vacc <- sum(duplicate_group_df$TotalNbrVaccPolio, na.rm = TRUE)
      total_pop <- sum(duplicate_group_df$PopPolio, na.rm = TRUE)
      if (total_pop > 0 && total_vacc > 0) {
        result$CVPolio <- (total_vacc / total_pop) * 100
      }
    }
    
    if ("WastRPolio" %in% names(result)) {
      if ("Doses.UsedPolio" %in% names(duplicate_group_df) && 
          "TotalDoses" %in% names(duplicate_group_df)) {
        total_doses_used <- sum(duplicate_group_df$Doses.UsedPolio, na.rm = TRUE)
        total_doses <- sum(duplicate_group_df$TotalDoses, na.rm = TRUE)
        if (total_doses > 0 && total_doses_used > 0) {
          doses_wasted <- total_doses - total_doses_used
          result$WastRPolio <- (doses_wasted / total_doses) * 100
        } else if (total_doses > 0) {
          result$WastRPolio <- mean(duplicate_group_df$WastRPolio, na.rm = TRUE)
        } else {
          result$WastRPolio <- mean(duplicate_group_df$WastRPolio, na.rm = TRUE)
        }
      } else {
        result$WastRPolio <- mean(duplicate_group_df$WastRPolio, na.rm = TRUE)
      }
      if (is.na(result$WastRPolio)) result$WastRPolio <- NA
    }
    
  } else if (merge_strategy == "sum_numeric") {
    for (col in count_columns) {
      if (col %in% names(duplicate_group_df)) {
        result[[col]] <- sum(duplicate_group_df[[col]], na.rm = TRUE)
        if (is.na(result[[col]]) || result[[col]] == 0) result[[col]] <- NA
      }
    }
    
    if ("CVPolio" %in% names(result) && "TotalNbrVaccPolio" %in% names(duplicate_group_df) && 
        "PopPolio" %in% names(duplicate_group_df)) {
      total_vacc <- sum(duplicate_group_df$TotalNbrVaccPolio, na.rm = TRUE)
      total_pop <- sum(duplicate_group_df$PopPolio, na.rm = TRUE)
      if (total_pop > 0 && total_vacc > 0) {
        result$CVPolio <- (total_vacc / total_pop) * 100
      }
    }
    
    if ("WastRPolio" %in% names(result)) {
      if ("Doses.UsedPolio" %in% names(duplicate_group_df) && 
          "TotalDoses" %in% names(duplicate_group_df)) {
        total_doses_used <- sum(duplicate_group_df$Doses.UsedPolio, na.rm = TRUE)
        total_doses <- sum(duplicate_group_df$TotalDoses, na.rm = TRUE)
        if (total_doses > 0) {
          doses_wasted <- total_doses - total_doses_used
          result$WastRPolio <- (doses_wasted / total_doses) * 100
        } else {
          result$WastRPolio <- mean(duplicate_group_df$WastRPolio, na.rm = TRUE)
        }
      } else {
        result$WastRPolio <- mean(duplicate_group_df$WastRPolio, na.rm = TRUE)
      }
      if (is.na(result$WastRPolio)) result$WastRPolio <- NA
    }
    
  } else if (merge_strategy == "mean_numeric") {
    for (col in count_columns) {
      if (col %in% names(duplicate_group_df)) {
        result[[col]] <- sum(duplicate_group_df[[col]], na.rm = TRUE)
        if (is.na(result[[col]]) || result[[col]] == 0) result[[col]] <- NA
      }
    }
    
    for (col in rate_columns) {
      if (col %in% names(duplicate_group_df)) {
        if (col == "WastRPolio") {
          if ("Doses.UsedPolio" %in% names(duplicate_group_df) && 
              "TotalDoses" %in% names(duplicate_group_df)) {
            total_doses_used <- sum(duplicate_group_df$Doses.UsedPolio, na.rm = TRUE)
            total_doses <- sum(duplicate_group_df$TotalDoses, na.rm = TRUE)
            if (total_doses > 0) {
              doses_wasted <- total_doses - total_doses_used
              result$WastRPolio <- (doses_wasted / total_doses) * 100
            } else {
              result[[col]] <- mean(duplicate_group_df[[col]], na.rm = TRUE)
            }
          } else {
            result[[col]] <- mean(duplicate_group_df[[col]], na.rm = TRUE)
          }
        } else {
          result[[col]] <- mean(duplicate_group_df[[col]], na.rm = TRUE)
        }
        if (is.na(result[[col]])) result[[col]] <- NA
      }
    }
    
  } else if (merge_strategy == "max_numeric") {
    for (col in names(duplicate_group_df)) {
      if (is.numeric(duplicate_group_df[[col]]) && !(col %in% duplicate_key_cols)) {
        result[[col]] <- max(duplicate_group_df[[col]], na.rm = TRUE)
        if (!is.finite(result[[col]])) result[[col]] <- NA
      }
    }
  } else if (merge_strategy == "min_numeric") {
    for (col in names(duplicate_group_df)) {
      if (is.numeric(duplicate_group_df[[col]]) && !(col %in% duplicate_key_cols)) {
        result[[col]] <- min(duplicate_group_df[[col]], na.rm = TRUE)
        if (!is.finite(result[[col]])) result[[col]] <- NA
      }
    }
  }
  
  result <- recalculate_percentages(result)
  
  if ("Entry_Date" %in% names(result)) {
    result$Entry_Date <- Sys.Date()
  }
  
  result$KEY_ID <- create_unique_id_dt(result)[1]
  
  # Track merge history
  result <- track_merge(duplicate_group_df, result, merge_strategy)
  
  result
}

keep_selected_rows <- function(full_df, rows_to_keep, duplicate_key_id) {
  rows_to_remove <- full_df$KEY_ID == duplicate_key_id & !(full_df$ROW_ID %in% rows_to_keep)
  full_df[!rows_to_remove, ]
}

# -----------------------------
# OTHER HELPERS
# -----------------------------
convert_geo <- function(df) {
  geo_columns_excluding_entry_date <- setdiff(geo_columns, "Entry_Date")
  for (col in geo_columns_excluding_entry_date) {
    if (col %in% names(df)) df[[col]] <- as.character(df[[col]])
  }
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
  
  if (!"KEY_ID" %in% names(df)) {
    df$KEY_ID <- create_unique_id_dt(df)
  } else {
    missk <- which(is.na(df$KEY_ID) | df$KEY_ID == "")
    if (length(missk) > 0) df$KEY_ID[missk] <- create_unique_id_dt(df[missk, , drop = FALSE])
  }
  
  df
}

save_repo <- function(df) {
  df <- ensure_rowid_keyid(df)
  saveRDS(df, repo_rds_path)
  writexl::write_xlsx(df, repo_xlsx_path)
}

remove_duplicates_from_repo <- function(df) {
  if (nrow(df) == 0) return(df)
  df <- ensure_rowid_keyid(df)
  keep_rows <- !duplicated(df$KEY_ID)
  df[keep_rows, , drop = FALSE]
}

validate_admin_data <- function(new_df, existing_df = NULL) {
  errors <- list()
  new_df <- normalize_admin_dates(new_df)
  
  missing_keys <- setdiff(duplicate_key_cols, names(new_df))
  if (length(missing_keys) > 0) {
    errors$missing_columns <- paste("Missing key columns:", paste(missing_keys, collapse = ", "))
    return(errors)
  }
  
  for (col in duplicate_key_cols) {
    empty_count <- sum(is.na(new_df[[col]]) | new_df[[col]] == "")
    if (empty_count > 0) errors[[paste0("empty_", col)]] <- paste(col, "has", empty_count, "empty values")
  }
  
  if ("SIA_date" %in% names(new_df) && any(is.na(new_df$SIA_date))) {
    errors$invalid_sia_date <- "Some SIA_date values could not be parsed."
  }
  
  if (nrow(new_df) > 1) {
    new_ids <- create_unique_id_dt(new_df)
    dup_ids <- new_ids[duplicated(new_ids)]
    if (length(dup_ids) > 0) errors$internal_duplicates <- paste(length(unique(dup_ids)), "duplicate key(s) found within uploaded data")
  }
  
  if (!is.null(existing_df) && nrow(existing_df) > 0 && nrow(new_df) > 0) {
    existing_df <- normalize_admin_dates(existing_df)
    new_ids <- create_unique_id_dt(new_df)
    existing_ids <- if ("KEY_ID" %in% names(existing_df)) existing_df$KEY_ID else create_unique_id_dt(existing_df)
    
    overlap <- intersect(new_ids, existing_ids)
    if (length(overlap) > 0) {
      duplicate_rows <- new_df[new_ids %in% overlap, duplicate_key_cols, drop = FALSE]
      errors$existing_duplicates <- list(
        count = length(overlap),
        ids = overlap,
        rows = duplicate_rows,
        message = paste(length(overlap), "records already exist in repository.")
      )
    }
  }
  
  errors
}

find_all_duplicates <- function(df) {
  if (nrow(df) == 0) return(data.frame())
  df <- ensure_rowid_keyid(df)
  dup_ids <- df$KEY_ID[df$KEY_ID %in% df$KEY_ID[duplicated(df$KEY_ID)]]
  if (length(dup_ids) == 0) return(data.frame())
  
  out <- df[df$KEY_ID %in% dup_ids, , drop = FALSE]
  out <- out %>%
    group_by(KEY_ID) %>%
    mutate(duplicate_group = cur_group_id(), record_num = row_number()) %>%
    ungroup()
  as.data.frame(out)
}

# -----------------------------
# UI WITH EXCEL-LIKE VIEW
# -----------------------------
ui <- fluidPage(
  useShinyjs(),
  
  tags$head(
    tags$link(href="https://fonts.googleapis.com/css2?family=Segoe+UI:wght@300;400;600;700&display=swap", rel="stylesheet"),
    tags$style(HTML("
      * {
        font-family: 'Segoe UI', 'Open Sans', sans-serif;
      }
      
      /* Excel-like table styling */
      .excel-table {
        overflow-x: auto;
      }
      
      .excel-table table {
        border-collapse: collapse;
        width: 100%;
        font-size: 13px;
      }
      
      .excel-table th {
        background: linear-gradient(135deg, #0066b3 0%, #0088cc 100%);
        color: white;
        font-weight: 600;
        padding: 8px;
        border: 1px solid #005a9e;
        position: sticky;
        top: 0;
        z-index: 10;
      }
      
      .excel-table td {
        padding: 6px 8px;
        border: 1px solid #d0d7de;
      }
      
      .excel-table tr:hover {
        background-color: #e6f3ff !important;
      }
      
      .excel-table .selected {
        background-color: #cce5ff !important;
      }
      
      .btn {
        border-radius: 4px;
        font-weight: 600;
        transition: all 0.2s ease;
        margin: 2px;
        padding: 6px 12px;
        font-size: 13px;
      }
      
      .btn:hover {
        transform: translateY(-1px);
        box-shadow: 0 2px 6px rgba(0,0,0,0.15);
      }
      
      .btn-primary {
        background: linear-gradient(135deg, #0066b3 0%, #0088cc 100%);
        border: none;
        color: white;
      }
      
      .btn-success {
        background: linear-gradient(135deg, #28a745 0%, #34ce57 100%);
        border: none;
        color: white;
      }
      
      .btn-warning {
        background: linear-gradient(135deg, #ffc107 0%, #ffda6a 100%);
        border: none;
        color: #856404;
      }
      
      .btn-danger {
        background: linear-gradient(135deg, #dc3545 0%, #ff4757 100%);
        border: none;
        color: white;
      }
      
      .btn-info {
        background: linear-gradient(135deg, #17a2b8 0%, #1fc8e3 100%);
        border: none;
        color: white;
      }
      
      .well, .panel {
        border-radius: 8px;
        box-shadow: 0 1px 4px rgba(0,0,0,0.08);
      }
      
      .form-control {
        border-radius: 4px;
        transition: all 0.2s ease;
      }
      
      .form-control:focus {
        border-color: #0088cc;
        box-shadow: 0 0 0 2px rgba(0,136,204,0.1);
      }
      
      .nav-tabs {
        border-bottom: 1px solid #ddd;
      }
      
      .nav-tabs > li > a {
        border-radius: 4px 4px 0 0;
        font-weight: 600;
        padding: 10px 15px;
        transition: all 0.2s ease;
        margin-right: 2px;
        color: #555;
      }
      
      .nav-tabs > li.active > a {
        border-top: 2px solid #0066b3;
        font-weight: 700;
        color: #0066b3;
      }
      
      .nav-tabs > li > a:hover {
        background-color: #f0f0f0;
      }
      
      .tab-content {
        padding: 15px 0;
      }
      
      .dataTables_wrapper {
        border-radius: 8px;
        overflow-x: auto;
      }
      
      /* Custom scrollbar */
      ::-webkit-scrollbar {
        width: 8px;
        height: 8px;
      }
      
      ::-webkit-scrollbar-track {
        background: #f1f1f1;
        border-radius: 4px;
      }
      
      ::-webkit-scrollbar-thumb {
        background: #888;
        border-radius: 4px;
      }
      
      ::-webkit-scrollbar-thumb:hover {
        background: #555;
      }
      
      /* Confidence badge styles */
      .conf-high {
        background-color: #d4edda;
        color: #155724;
        padding: 2px 8px;
        border-radius: 12px;
        font-size: 11px;
        font-weight: bold;
      }
      .conf-medium {
        background-color: #fff3cd;
        color: #856404;
        padding: 2px 8px;
        border-radius: 12px;
        font-size: 11px;
        font-weight: bold;
      }
      .conf-low {
        background-color: #f8d7da;
        color: #721c24;
        padding: 2px 8px;
        border-radius: 12px;
        font-size: 11px;
        font-weight: bold;
      }
    "))
  ),
  
  # WHO Header
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
      actionButton("refresh_data", "Refresh", 
                   style = "background: rgba(255,255,255,0.15); border: 1px solid rgba(255,255,255,0.3); color: white; border-radius: 4px;")
    )
  ),
  
  uiOutput("theme_css"),
  uiOutput("app_body")
)

# -----------------------------
# SERVER
# -----------------------------
server <- function(input, output, session) {
  
  user_country <- reactiveVal(NULL)
  user_role    <- reactiveVal("user")
  
  # Theme CSS
  output$theme_css <- renderUI({
    if (isTRUE(input$dark_mode)) {
      tags$style(HTML("
        body {
          background: #1a1a2e;
          color: #e0e0e0;
        }
        
        .well, .panel, .panel-body {
          background: #16213e !important;
          border-color: #0f3460 !important;
          color: #e0e0e0 !important;
        }
        
        .form-control, .selectize-input {
          background-color: #0f3460;
          border-color: #1a5276;
          color: #e0e0e0;
        }
        
        .form-control:focus {
          border-color: #00a0dc;
          box-shadow: 0 0 0 2px rgba(0,160,220,0.2);
        }
        
        .nav-tabs {
          border-bottom-color: #0f3460;
        }
        
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
        
        .excel-panel {
          background: #16213e;
          border: 1px solid #0f3460;
          border-radius: 8px;
          padding: 15px;
          margin-top: 15px;
        }
        
        .excel-title {
          color: #00a0dc;
          border-left-color: #00a0dc;
        }
        
        .excel-table th {
          background: linear-gradient(135deg, #003366 0%, #004d99 100%);
        }
        
        .excel-table td {
          border-color: #0f3460;
        }
        
        .excel-table tr:nth-child(odd) {
          background-color: #1a1a2e;
        }
        
        .excel-table tr:nth-child(even) {
          background-color: #16213e;
        }
        
        .excel-table tr:hover {
          background-color: #1a5276 !important;
        }
      "))
    } else {
      tags$style(HTML("
        body {
          background: #f5f5f5;
          color: #333;
        }
        
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
        
        .excel-table th {
          background: linear-gradient(135deg, #0066b3 0%, #0088cc 100%);
        }
        
        .excel-table tr:nth-child(odd) {
          background-color: #fff;
        }
        
        .excel-table tr:nth-child(even) {
          background-color: #f9f9f9;
        }
        
        .excel-table tr:hover {
          background-color: #e6f3ff !important;
        }
      "))
    }
  })
  
  # Refresh data observer
  observeEvent(input$refresh_data, {
    if (file.exists(repo_rds_path)) {
      repo <- readRDS(repo_rds_path)
      repo <- convert_geo(repo)
      repo <- ensure_rowid_keyid(repo)
      admin_repo(repo)
      showNotification("Data refreshed successfully!", type = "message", duration = 2)
    } else {
      showNotification("No data repository found.", type = "warning", duration = 2)
    }
  })
  
  # Repository load
  admin_repo <- reactiveVal({
    if (file.exists(repo_rds_path)) {
      repo <- readRDS(repo_rds_path)
      repo <- convert_geo(repo)
      repo <- ensure_rowid_keyid(repo)
      saveRDS(repo, repo_rds_path)
      writexl::write_xlsx(repo, repo_xlsx_path)
      repo
    } else {
      df0 <- make_empty_df_from_schema(template_schema, n_rows = 0)
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
      paste0("Repository not yet created")
    }
  })
  
  # Download empty template
  output$download_empty_template <- downloadHandler(
    filename = function() paste0("AFRO_admin_data_TEMPLATE_EMPTY_", Sys.Date(), ".xlsx"),
    content = function(file) {
      empty_df <- make_empty_df_from_schema(template_schema, n_rows = 0)
      writexl::write_xlsx(empty_df, path = file)
    }
  )
  
  # Manual entry grid with Excel-like editing
  manual_data <- reactiveVal(NULL)
  
  observeEvent(user_country(), {
    df <- make_empty_df_from_schema(template_schema, n_rows = 1)
    if ("Entry_Date" %in% names(df)) df$Entry_Date[1] <- Sys.Date()
    if (isTRUE(user_role() != "admin") && "Country" %in% names(df)) df$Country[1] <- user_country()
    df <- convert_geo(df)
    manual_data(df)
  })
  
  output$manual_table <- renderDT({
    req(manual_data())
    df <- manual_data()
    
    datatable(
      df,
      editable = list(target = "cell", disable = list(columns = 0)),
      selection = "single",
      extensions = c("KeyTable", "Buttons"),
      options = list(
        pageLength = 10,
        scrollX = TRUE,
        scrollY = 400,
        keys = TRUE,
        dom = 'Bfrtip',
        buttons = c('copy', 'csv', 'excel'),
        columnDefs = list(
          list(className = 'dt-center', targets = '_all')
        )
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
      showNotification("Please select a row to delete (click on row number).", type = "warning")
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
    non_empty <- df %>% filter(!if_all(everything(), ~ is.na(.) || . == ""))
    if (nrow(non_empty) == 0) {
      showNotification("No non-empty rows to append.", type = "warning")
      return(NULL)
    }
    
    if (isTRUE(user_role() != "admin") && "Country" %in% names(non_empty)) non_empty$Country <- user_country()
    if ("Entry_Date" %in% names(non_empty)) non_empty$Entry_Date <- Sys.Date()
    non_empty <- normalize_admin_dates(non_empty)
    
    repo <- admin_repo()
    repo <- bind_rows(repo, non_empty)
    repo <- ensure_rowid_keyid(repo)
    repo <- remove_duplicates_from_repo(repo)
    save_repo(repo)
    admin_repo(repo)
    
    showNotification(paste("Added", nrow(non_empty), "new record(s)."), type = "message")
    
    df_new <- make_empty_df_from_schema(template_schema, n_rows = 1)
    if ("Entry_Date" %in% names(df_new)) df_new$Entry_Date[1] <- Sys.Date()
    if (isTRUE(user_role() != "admin") && "Country" %in% names(df_new)) df_new$Country[1] <- user_country()
    df_new <- normalize_admin_dates(df_new)
    df_new <- convert_geo(df_new)
    manual_data(df_new)
  })
  
  # File upload
  observeEvent(input$add_file, {
    req(input$upload_file, user_country())
    new_data <- tryCatch(read_excel(input$upload_file$datapath),
                         error = function(e) { showNotification(e$message, type = "error"); return(NULL) })
    req(!is.null(new_data))
    new_data <- normalize_admin_dates(new_data)
    
    schema_cols <- template_schema$column_names
    if (!setequal(names(new_data), schema_cols)) {
      showNotification("Uploaded file columns do not match the template.", type = "error")
      return(NULL)
    }
    
    new_data <- new_data %>% dplyr::select(dplyr::all_of(schema_cols))
    new_data <- convert_geo(new_data)
    
    if (isTRUE(user_role() != "admin") && "Country" %in% names(new_data)) {
      if (any(!is.na(new_data$Country) & new_data$Country != user_country())) {
        showNotification(paste0("Uploaded file contains rows for another country. Only '", user_country(), "' is allowed."), type = "error")
        return(NULL)
      }
      new_data$Country <- user_country()
    }
    
    if ("Entry_Date" %in% names(new_data)) new_data$Entry_Date <- Sys.Date()
    new_data <- normalize_admin_dates(new_data)
    
    repo <- admin_repo()
    repo <- bind_rows(repo, new_data)
    repo <- ensure_rowid_keyid(repo)
    repo <- remove_duplicates_from_repo(repo)
    save_repo(repo)
    admin_repo(repo)
    
    showNotification("File data appended successfully.", type = "message")
  })
  
  # Repository preview with Excel-like view
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
        dom = 'Bfrtip',
        buttons = c('copy', 'csv', 'excel', 'pdf')
      ),
      class = "display compact hover row-border stripe"
    )
  }, server = TRUE)
  
  output$column_info <- renderTable({
    ci <- tibble::tibble(column_name = template_schema$column_names,
                         column_type = unname(template_schema$column_types[template_schema$column_names]))
    ci
  })
  
  output$tokens_table <- renderDT({
    req(isTRUE(user_role() == "admin"))
    datatable(tokens_tbl, extensions = c("Scroller", "Buttons"),
              options = list(pageLength = 20, scrollX = TRUE, scrollY = 520, scroller = TRUE,
                             dom = 'Bfrtip', buttons = c('copy', 'csv', 'excel')))
  }, server = TRUE)
  
  # Help texts
  output$recalculation_help <- renderUI({
    req(admin_repo())
    duplicates <- find_all_duplicates(admin_repo())
    if (nrow(duplicates) == 0) return(NULL)
    
    div(style = "background: #e8f4fd; border-left: 3px solid #0066b3; border-radius: 4px; padding: 10px; margin-bottom: 15px; font-size: 12px;",
        strong("Automatic Recalculation:"),
        tags$ul(style = "margin-top: 5px; margin-bottom: 0; padding-left: 20px;",
                tags$li("CVPolio = (TotalNbrVaccPolio / PopPolio) x 100"),
                tags$li("Prop_0dosesPolio = Total_Nbr_0doseVaccPolio_0_59M / TotalNbrVaccPolio"),
                tags$li("WastRPolio = (TotalDoses - Doses.UsedPolio) / TotalDoses x 100")
        )
    )
  })
  
  # Enhanced Duplicate Management UI
  output$duplicate_panel <- renderUI({
    req(admin_repo())
    all_duplicates <- find_all_duplicates(admin_repo())
    
    if (nrow(all_duplicates) == 0) {
      return(div(class = "alert alert-success", style = "border-radius: 4px; padding: 15px;", 
                 icon("check-circle"), " No duplicates found in the repository. Great job!"))
    }
    
    div(
      class = "excel-panel",
      div(class = "excel-title", "Duplicate Management"),
      div(class = "excel-subtitle",
          paste("Found", nrow(all_duplicates), "records in", length(unique(all_duplicates$duplicate_group)), "duplicate groups")),
      
      uiOutput("recalculation_help"),
      
      div(style = "margin-bottom: 15px;",
          strong("Merge Strategy: "),
          radioButtons("merge_strategy", NULL,
                       choices = c(
                         "Weighted Average for Rates (Recommended)" = "weighted_average",
                         "Sum All Numeric Values" = "sum_numeric",
                         "Mean of Rates" = "mean_numeric",
                         "Keep Maximum Values" = "max_numeric",
                         "Keep Minimum Values" = "min_numeric"
                       ),
                       selected = "weighted_average", inline = TRUE)
      ),
      
      div(style = "margin-bottom: 15px;",
          sliderInput("dup_confidence_threshold", "Partial Duplicate Confidence Threshold",
                      min = 50, max = 100, value = 85, step = 5,
                      helpText("Show potential partial duplicates above this confidence level"))
      ),
      
      div(style = "margin-bottom: 10px; display: flex; gap: 8px; flex-wrap: wrap;",
          actionButton("keep_first_rows_all", "Keep ALL First Rows", class = "btn-info", style = "font-size: 12px;"),
          actionButton("apply_merge_all", "Merge ALL Duplicate Groups", class = "btn-warning", style = "font-size: 12px;"),
          actionButton("preview_merge", "Preview Merge", class = "btn-primary", style = "font-size: 12px;")
      ),
      
      div(style = "margin-bottom: 10px; display: flex; gap: 8px; flex-wrap: wrap;",
          actionButton("keep_first_rows_selected", "Keep First Row of Selected", class = "btn-success", style = "font-size: 12px;"),
          actionButton("merge_selected_group", "Merge Selected Group", class = "btn-primary", style = "font-size: 12px;"),
          actionButton("keep_selected_rows", "Keep Selected Rows", class = "btn-info", style = "font-size: 12px;"),
          actionButton("delete_selected_rows", "Delete Selected Rows", class = "btn-danger", style = "font-size: 12px;"),
          actionButton("edit_selected_duplicate", "Edit Selected Row", class = "btn-warning", style = "font-size: 12px;")
      ),
      
      div(style = "margin-bottom: 10px;",
          actionButton("find_partial_duplicates", "Find Partial Duplicates", class = "btn-secondary", style = "font-size: 12px; background-color: #6c757d; color: white;")
      ),
      
      div(class = "excel-table", DTOutput("all_duplicates_table")),
      
      div(style = "margin-top: 20px;",
          div(class = "excel-title", "Partial Duplicates (Potential Matches)"),
          div(class = "excel-subtitle", "Rows that are similar but not exact duplicates. Review these manually."),
          DTOutput("partial_duplicates_table")
      )
    )
  })
  
  # Display duplicates table with selection and confidence scores
  output$all_duplicates_table <- renderDT({
    req(admin_repo())
    duplicates <- find_all_duplicates(admin_repo())
    if (nrow(duplicates) == 0) return(datatable(data.frame(Message = "No duplicates found")))
    
    # Add confidence score column (for display purposes)
    duplicates$confidence <- 100  # Exact duplicates get 100% confidence
    
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
        dom = 'Bfrtip', 
        buttons = c('copy', 'csv', 'excel')
      ),
      class = "display compact hover row-border stripe"
    ) %>%
      formatStyle("confidence",
                  backgroundColor = styleInterval(c(90, 99), c("#d4edda", "#fff3cd", "#f8d7da")),
                  fontWeight = "bold")
  }, server = TRUE)
  
  # Partial duplicates table
  output$partial_duplicates_table <- renderDT({
    req(admin_repo())
    repo <- admin_repo()
    
    partials <- find_partial_duplicates(repo, threshold = input$dup_confidence_threshold / 100)
    
    if (nrow(partials) == 0) {
      return(datatable(data.frame(Message = "No partial duplicates found above threshold")))
    }
    
    # Add human-readable information
    partials$confidence_display <- paste0(partials$confidence, "%")
    
    # Get sample data for display
    partials$sample_data_1 <- sapply(partials$KEY_ID_1, function(kid) {
      rows <- repo[repo$KEY_ID == kid, ]
      if (nrow(rows) > 0) {
        paste(rows[1, c("Country", "District", "SIA_date")], collapse = " | ")
      } else "N/A"
    })
    
    partials$sample_data_2 <- sapply(partials$KEY_ID_2, function(kid) {
      rows <- repo[repo$KEY_ID == kid, ]
      if (nrow(rows) > 0) {
        paste(rows[1, c("Country", "District", "SIA_date")], collapse = " | ")
      } else "N/A"
    })
    
    datatable(
      partials[, c("KEY_ID_1", "KEY_ID_2", "confidence_display", "sample_data_1", "sample_data_2")],
      selection = "multiple",
      extensions = c("Scroller", "Buttons"),
      options = list(
        pageLength = 10,
        scrollX = TRUE,
        scrollY = 300,
        dom = 'Bfrtip',
        buttons = c('copy', 'csv', 'excel')
      ),
      colnames = c("Key ID 1", "Key ID 2", "Confidence", "Record 1 (Country | District | Date)", "Record 2 (Country | District | Date)"),
      class = "display compact hover row-border stripe"
    ) %>%
      formatStyle("confidence_display",
                  backgroundColor = styleEqual(c("100%", "95%", "90%", "85%"), 
                                               c("#d4edda", "#d4edda", "#fff3cd", "#f8d7da")))
  }, server = TRUE)
  
  # Find partial duplicates button
  observeEvent(input$find_partial_duplicates, {
    showNotification("Scanning for partial duplicates...", type = "message", duration = 2)
    # The table will automatically refresh via the reactive expression
  })
  
  # Keep first row of ALL duplicate groups
  observeEvent(input$keep_first_rows_all, {
    all_duplicates <- find_all_duplicates(admin_repo())
    if (nrow(all_duplicates) == 0) {
      showNotification("No duplicates to process.", type = "info")
      return(NULL)
    }
    
    group_count <- length(unique(all_duplicates$duplicate_group))
    rows_to_delete <- nrow(all_duplicates) - group_count
    
    showModal(modalDialog(
      title = "Keep First Row of Each Duplicate Group",
      p(paste("This will keep only the FIRST row from each of the", group_count, "duplicate group(s).")),
      p(paste(rows_to_delete, "row(s) will be deleted."), style = "color: #dc3545;"),
      p("The first row is determined by the original entry order (lowest ROW_ID)."),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_keep_first_all", "Confirm Keep First Rows", class = "btn-primary")
      )
    ))
  })
  
  observeEvent(input$confirm_keep_first_all, {
    repo <- admin_repo()
    duplicates <- find_all_duplicates(repo)
    
    rows_to_keep <- c()
    
    for (group_id in unique(duplicates$duplicate_group)) {
      group_rows <- duplicates[duplicates$duplicate_group == group_id, ]
      group_rows <- group_rows[order(group_rows$ROW_ID), ]
      first_row_id <- group_rows$ROW_ID[1]
      rows_to_keep <- c(rows_to_keep, first_row_id)
    }
    
    non_duplicate_rows <- repo[!(repo$KEY_ID %in% duplicates$KEY_ID), ]
    rows_to_keep <- c(rows_to_keep, non_duplicate_rows$ROW_ID)
    
    repo <- repo[repo$ROW_ID %in% rows_to_keep, ]
    repo <- ensure_rowid_keyid(repo)
    save_repo(repo)
    admin_repo(repo)
    removeModal()
    
    showNotification(
      paste("Kept first row of", length(unique(duplicates$duplicate_group)), 
            "duplicate group(s). Deleted", nrow(duplicates) - length(unique(duplicates$duplicate_group)), "duplicate rows."),
      type = "message"
    )
  })
  
  # Keep first row of SELECTED duplicate groups
  observeEvent(input$keep_first_rows_selected, {
    req(input$all_duplicates_table_rows_selected)
    duplicates <- find_all_duplicates(admin_repo())
    selected_groups <- unique(duplicates$duplicate_group[input$all_duplicates_table_rows_selected])
    
    if (length(selected_groups) == 0) {
      showNotification("Please select rows from the duplicate group(s) to process.", type = "warning")
      return(NULL)
    }
    
    rows_in_selected_groups <- sum(duplicates$duplicate_group %in% selected_groups)
    rows_to_keep_count <- length(selected_groups)
    rows_to_delete_count <- rows_in_selected_groups - rows_to_keep_count
    
    showModal(modalDialog(
      title = "Keep First Row of Selected Duplicate Groups",
      p(paste("This will keep only the FIRST row from each of the", length(selected_groups), "selected duplicate group(s).")),
      p(paste(rows_to_delete_count, "row(s) will be deleted."), style = "color: #dc3545;"),
      p("Other duplicate groups will remain unchanged."),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_keep_first_selected", "Confirm Keep First Rows", class = "btn-success")
      )
    ))
    
    session$userData$selected_groups_to_keep <- selected_groups
  })
  
  observeEvent(input$confirm_keep_first_selected, {
    req(session$userData$selected_groups_to_keep)
    selected_groups <- session$userData$selected_groups_to_keep
    repo <- admin_repo()
    duplicates <- find_all_duplicates(repo)
    
    rows_to_keep <- c()
    
    for (group_id in selected_groups) {
      group_rows <- duplicates[duplicates$duplicate_group == group_id, ]
      group_rows <- group_rows[order(group_rows$ROW_ID), ]
      first_row_id <- group_rows$ROW_ID[1]
      rows_to_keep <- c(rows_to_keep, first_row_id)
    }
    
    non_selected_groups <- unique(duplicates$duplicate_group)[!(unique(duplicates$duplicate_group) %in% selected_groups)]
    for (group_id in non_selected_groups) {
      group_rows <- duplicates[duplicates$duplicate_group == group_id, ]
      rows_to_keep <- c(rows_to_keep, group_rows$ROW_ID)
    }
    
    non_duplicate_rows <- repo[!(repo$KEY_ID %in% duplicates$KEY_ID), ]
    rows_to_keep <- c(rows_to_keep, non_duplicate_rows$ROW_ID)
    
    repo <- repo[repo$ROW_ID %in% rows_to_keep, ]
    repo <- ensure_rowid_keyid(repo)
    save_repo(repo)
    admin_repo(repo)
    removeModal()
    
    showNotification(
      paste("Kept first row of", length(selected_groups), "selected duplicate group(s)."),
      type = "message"
    )
    
    session$userData$selected_groups_to_keep <- NULL
  })
  
  # Preview merge functionality
  observeEvent(input$preview_merge, {
    req(input$all_duplicates_table_rows_selected)
    duplicates <- find_all_duplicates(admin_repo())
    selected_groups <- unique(duplicates$duplicate_group[input$all_duplicates_table_rows_selected])
    
    if (length(selected_groups) == 0) {
      showNotification("Please select rows from the duplicate group to preview.", type = "warning")
      return(NULL)
    }
    
    repo <- admin_repo()
    preview_data <- list()
    
    for (group_id in selected_groups) {
      group_rows <- duplicates[duplicates$duplicate_group == group_id, ]
      group_key <- unique(group_rows$KEY_ID)[1]
      group_data <- repo[repo$KEY_ID == group_key, ]
      
      preview_data[[paste("Group", group_id)]] <- list(
        original = group_data,
        merged = merge_duplicate_rows(group_data, merge_strategy = input$merge_strategy)
      )
    }
    
    showModal(modalDialog(
      title = "Merge Preview",
      size = "l",
      uiOutput("preview_merge_content"),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_merge_from_preview", "Proceed with Merge", class = "btn-primary")
      )
    ))
    
    output$preview_merge_content <- renderUI({
      preview_ui <- list()
      for (group_name in names(preview_data)) {
        preview_ui[[group_name]] <- div(
          style = "margin-bottom: 20px;",
          h5(group_name),
          h6("Original rows:"),
          renderDT(datatable(preview_data[[group_name]]$original, options = list(pageLength = 5, scrollX = TRUE), class = "display compact")),
          h6("Merged result:"),
          renderDT(datatable(preview_data[[group_name]]$merged, options = list(pageLength = 1, scrollX = TRUE), class = "display compact")),
          hr()
        )
      }
      do.call(tagList, preview_ui)
    })
    
    session$userData$preview_groups <- selected_groups
  })
  
  # Edit selected duplicate row
  observeEvent(input$edit_selected_duplicate, {
    req(input$all_duplicates_table_rows_selected)
    duplicates <- find_all_duplicates(admin_repo())
    selected_row <- duplicates[input$all_duplicates_table_rows_selected[1], ]
    
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
    
    output$edit_row_ui <- renderUI({
      df_row <- selected_row
      edit_inputs <- list()
      
      important_cols <- c(duplicate_key_cols, "TotalNbrVaccPolio", "Total_Nbr_0doseVaccPolio_0_59M", 
                          "WastRPolio", "Doses.UsedPolio", "TotalDoses", "PopPolio")
      cols_to_show <- intersect(important_cols, names(df_row))
      
      for (col in cols_to_show) {
        if (col == "SIA_date") {
          edit_inputs[[col]] <- dateInput(paste0("edit_", col), col, value = df_row[[col]])
        } else if (is.numeric(df_row[[col]])) {
          edit_inputs[[col]] <- numericInput(paste0("edit_", col), col, value = df_row[[col]])
        } else {
          edit_inputs[[col]] <- textInput(paste0("edit_", col), col, value = as.character(df_row[[col]]))
        }
      }
      
      do.call(tagList, edit_inputs)
    })
    
    session$userData$editing_row <- selected_row
  })
  
  observeEvent(input$save_row_edit, {
    req(session$userData$editing_row)
    edited_row <- session$userData$editing_row
    repo <- admin_repo()
    
    for (col in names(edited_row)) {
      if (col %in% names(repo) && col != "ROW_ID" && col != "KEY_ID") {
        input_val <- input[[paste0("edit_", col)]]
        if (!is.null(input_val)) {
          row_idx <- which(repo$ROW_ID == edited_row$ROW_ID)
          if (length(row_idx) > 0) {
            if (col == "SIA_date") {
              repo[row_idx, col] <- as.Date(input_val)
            } else if (is.numeric(repo[[col]])) {
              repo[row_idx, col] <- as.numeric(input_val)
            } else {
              repo[row_idx, col] <- as.character(input_val)
            }
          }
        }
      }
    }
    
    repo <- normalize_admin_dates(repo)
    repo$KEY_ID <- create_unique_id_dt(repo)
    repo <- recalculate_percentages(repo)
    
    save_repo(repo)
    admin_repo(repo)
    removeModal()
    showNotification("Row updated successfully.", type = "message")
  })
  
  # Merge selected duplicate group
  observeEvent(input$merge_selected_group, {
    req(input$all_duplicates_table_rows_selected)
    duplicates <- find_all_duplicates(admin_repo())
    selected_groups <- unique(duplicates$duplicate_group[input$all_duplicates_table_rows_selected])
    
    if (length(selected_groups) == 0) {
      showNotification("Please select rows from the duplicate group to merge.", type = "warning")
      return(NULL)
    }
    
    showModal(modalDialog(
      title = "Merge Duplicate Group",
      paste("Are you sure you want to merge", length(selected_groups), "duplicate group(s)?"),
      "This will combine all rows in each group into a single row using the selected strategy.",
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_merge", "Confirm Merge", class = "btn-primary")
      )
    ))
    
    session$userData$groups_to_merge <- selected_groups
  })
  
  observeEvent(input$confirm_merge, {
    req(session$userData$groups_to_merge)
    groups_to_merge <- session$userData$groups_to_merge
    repo <- admin_repo()
    duplicates <- find_all_duplicates(repo)
    
    for (group_id in groups_to_merge) {
      group_rows <- duplicates[duplicates$duplicate_group == group_id, ]
      group_key <- unique(group_rows$KEY_ID)[1]
      group_data <- repo[repo$KEY_ID == group_key, ]
      
      merged_row <- merge_duplicate_rows(group_data, merge_strategy = input$merge_strategy)
      repo <- repo[repo$KEY_ID != group_key, ]
      repo <- bind_rows(repo, merged_row)
    }
    
    repo <- ensure_rowid_keyid(repo)
    save_repo(repo)
    admin_repo(repo)
    removeModal()
    showNotification(paste("Merged", length(groups_to_merge), "duplicate group(s)."), type = "message")
  })
  
  observeEvent(input$confirm_merge_from_preview, {
    req(session$userData$preview_groups)
    session$userData$groups_to_merge <- session$userData$preview_groups
    removeModal()
    showModal(modalDialog(
      title = "Confirm Merge",
      paste("Merge", length(session$userData$preview_groups), "duplicate group(s)?"),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_merge", "Confirm Merge", class = "btn-primary")
      )
    ))
  })
  
  # Keep selected rows, delete others in same group
  observeEvent(input$keep_selected_rows, {
    req(input$all_duplicates_table_rows_selected)
    duplicates <- find_all_duplicates(admin_repo())
    selected_rows <- duplicates[input$all_duplicates_table_rows_selected, ]
    
    if (nrow(selected_rows) == 0) {
      showNotification("Please select rows to keep.", type = "warning")
      return(NULL)
    }
    
    rows_to_keep_by_key <- split(selected_rows$ROW_ID, selected_rows$KEY_ID)
    
    showModal(modalDialog(
      title = "Keep Selected Rows",
      paste("This will keep", length(unlist(rows_to_keep_by_key)), "selected row(s) and delete all other rows in their duplicate groups."),
      "Are you sure?",
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_keep", "Confirm", class = "btn-warning")
      )
    ))
    
    session$userData$rows_to_keep <- rows_to_keep_by_key
  })
  
  observeEvent(input$confirm_keep, {
    req(session$userData$rows_to_keep)
    rows_to_keep_by_key <- session$userData$rows_to_keep
    repo <- admin_repo()
    
    for (key_id in names(rows_to_keep_by_key)) {
      rows_to_keep <- rows_to_keep_by_key[[key_id]]
      repo <- keep_selected_rows(repo, rows_to_keep, key_id)
    }
    
    repo <- ensure_rowid_keyid(repo)
    save_repo(repo)
    admin_repo(repo)
    removeModal()
    showNotification("Selected rows kept, others deleted.", type = "message")
  })
  
  # Delete selected rows
  observeEvent(input$delete_selected_rows, {
    req(input$all_duplicates_table_rows_selected)
    duplicates <- find_all_duplicates(admin_repo())
    selected_rows <- duplicates[input$all_duplicates_table_rows_selected, ]
    
    showModal(modalDialog(
      title = "Delete Rows",
      paste("Are you sure you want to delete", nrow(selected_rows), "selected row(s)?"),
      "This action cannot be undone.",
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_delete_duplicates", "Delete", class = "btn-danger")
      )
    ))
    
    session$userData$rows_to_delete <- selected_rows$ROW_ID
  })
  
  observeEvent(input$confirm_delete_duplicates, {
    req(session$userData$rows_to_delete)
    rows_to_delete <- session$userData$rows_to_delete
    repo <- admin_repo()
    repo <- repo[!(repo$ROW_ID %in% rows_to_delete), ]
    
    repo <- ensure_rowid_keyid(repo)
    save_repo(repo)
    admin_repo(repo)
    removeModal()
    showNotification(paste("Deleted", length(rows_to_delete), "row(s)."), type = "message")
  })
  
  # Merge all duplicate groups
  observeEvent(input$apply_merge_all, {
    all_duplicates <- find_all_duplicates(admin_repo())
    if (nrow(all_duplicates) == 0) {
      showNotification("No duplicates to merge.", type = "info")
      return(NULL)
    }
    
    group_count <- length(unique(all_duplicates$duplicate_group))
    showModal(modalDialog(
      title = "Merge ALL Duplicates",
      paste("This will merge", group_count, "duplicate group(s) into single rows using the selected strategy."),
      "This action cannot be undone.",
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_merge_all", "Merge All", class = "btn-danger")
      )
    ))
  })
  
  observeEvent(input$confirm_merge_all, {
    repo <- admin_repo()
    duplicates <- find_all_duplicates(repo)
    groups_to_merge <- unique(duplicates$duplicate_group)
    
    for (group_id in groups_to_merge) {
      group_rows <- duplicates[duplicates$duplicate_group == group_id, ]
      group_key <- unique(group_rows$KEY_ID)[1]
      group_data <- repo[repo$KEY_ID == group_key, ]
      
      merged_row <- merge_duplicate_rows(group_data, merge_strategy = input$merge_strategy)
      repo <- repo[repo$KEY_ID != group_key, ]
      repo <- bind_rows(repo, merged_row)
    }
    
    repo <- ensure_rowid_keyid(repo)
    save_repo(repo)
    admin_repo(repo)
    removeModal()
    showNotification(paste("Merged", length(groups_to_merge), "duplicate groups."), type = "message")
  })
  
  # Downloads
  output$download_repo_xlsx <- downloadHandler(
    filename = function() {
      if (isTRUE(user_role() == "admin")) "AFRO_admin_data_repository_ALL.xlsx"
      else paste0("AFRO_admin_data_repository_", gsub(" ", "_", user_country()), ".xlsx")
    },
    content = function(file) writexl::write_xlsx(repo_country(), file)
  )
  
  output$download_repo_rds <- downloadHandler(
    filename = function() {
      if (isTRUE(user_role() == "admin")) "AFRO_admin_data_repository_ALL.rds"
      else paste0("AFRO_admin_data_repository_", gsub(" ", "_", user_country()), ".rds")
    },
    content = function(file) saveRDS(repo_country(), file)
  )
  
  # Edit Repository tab with Excel-like editing
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
        dom = 'Bfrtip', 
        buttons = c('copy', 'csv', 'excel')
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
    } else {
      repo[info$row, col_name] <- info$value
    }
    
    repo <- normalize_admin_dates(repo)
    repo$KEY_ID <- create_unique_id_dt(repo)
    repo <- recalculate_percentages(repo)
    
    save_repo(repo)
    admin_repo(repo)
  })
  
  # Login
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
  
  output$app_body <- renderUI({
    if (is.null(user_country())) {
      fluidRow(
        column(width = 4, offset = 4,
               br(), br(),
               div(style = "background: white; border-radius: 8px; padding: 25px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); text-align: center;",
                   div(style = "margin-bottom: 20px;",
                       h3("WHO AFRO", style = "color: #0066b3; margin: 0;")),
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
    } else {
      sidebarLayout(
        sidebarPanel(
          style = "border-radius: 8px;",
          h5("Display Settings"),
          checkboxInput("dark_mode", "Dark Mode", value = FALSE),
          tags$hr(),
          h5("Session"),
          div(style = "background: #f0f7ff; padding: 8px; border-radius: 4px; margin-bottom: 15px; font-size: 13px;",
              tags$b("Role: "), textOutput("logged_role", inline = TRUE), br(),
              tags$b("Country: "), textOutput("logged_country", inline = TRUE)
          ),
          tags$hr(),
          h5("Template"),
          downloadButton("download_empty_template", "Download Empty Template", style = "width: 100%; margin-bottom: 10px; font-size: 12px;"),
          tags$hr(),
          h5("Manual Entry"),
          actionButton("add_manual_row", "Add Row", style = "width: 100%; margin-bottom: 5px; font-size: 12px;"),
          actionButton("delete_manual_row", "Delete Row", class = "btn-danger", style = "width: 100%; margin-bottom: 10px; font-size: 12px;"),
          actionButton("append_manual_rows", "Append to Repository", class = "btn-success", style = "width: 100%; font-size: 12px;"),
          tags$hr(),
          h5("Upload File"),
          fileInput("upload_file", "Choose Excel File", accept = ".xlsx"),
          actionButton("add_file", "Upload & Append", class = "btn-info", style = "width: 100%; font-size: 12px;"),
          tags$hr(),
          h5("Download Data"),
          downloadButton("download_repo_xlsx", "Download as Excel", style = "width: 100%; margin-bottom: 5px; font-size: 12px;"),
          downloadButton("download_repo_rds", "Download as RDS", style = "width: 100%; font-size: 12px;")
        ),
        
        mainPanel(
          tabsetPanel(
            tabPanel("Manual Entry", div(class = "excel-panel", DTOutput("manual_table"))),
            tabPanel("Edit Repository", div(class = "excel-panel", DTOutput("edit_table"))),
            tabPanel("Repository Preview", div(class = "excel-panel", DTOutput("repo_table"))),
            tabPanel("Column Information", div(class = "excel-panel", tableOutput("column_info"))),
            tabPanel("Manage Duplicates", uiOutput("duplicate_panel")),
            if (isTRUE(user_role() == "admin")) 
              tabPanel("Admin Tokens", div(class = "excel-panel", DTOutput("tokens_table")))
          )
        )
      )
    }
  })
  
  output$logged_country <- renderText({ user_country() })
  output$logged_role <- renderText({ user_role() })
}

shinyApp(ui, server)