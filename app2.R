# =============================================================
# WHO AFRO Admin Data Portal – Country Focal Point Interface
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
admin_token <- "AFRO-ADMIN-2025"   # change if you want

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
  "Cameroon",                       "RAKOTOARIVOLOLONA, Tania",                "rakotoarivololonat@who.int",
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
  "Namibia",                        "data focal point",                        "muchabaiwat@who.int"
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
# Paths & Template (AUTO-DETECT filename in /input)
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
duplicate_key_cols <- c(
  "Country", "Province", "District", "SIA_date",
  "Round_Add", "Vaccine_type", "Response"
)

geo_columns <- c(
  "Admin_1","Admin_2","Admin_3","Admin_4",
  "Country","Region","District","Ward","Village"
)

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
# FAST KEY_ID
# -----------------------------
.clean_key_vec <- function(v) {
  v <- as.character(v)
  v[is.na(v) | v == ""] <- "NA"
  v <- toupper(trimws(v))
  v <- gsub("[[:space:]]+", "_", v)
  v <- gsub("[^A-Za-z0-9_\\-]", "", v)
  v[v == ""] <- "EMPTY"
  v
}

.format_sia_key <- function(v) {
  dv <- parse_sia_date(v)
  out <- format(dv, "%Y-%m-%d")
  out[is.na(dv)] <- "NA"
  out
}

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
  
  dt[, KEY_ID := do.call(paste, c(.SD, sep = "|")), .SDcols = available_cols]
  dt[["KEY_ID"]]
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
    errors$invalid_sia_date <- "Some SIA_date values could not be parsed (examples expected: 2020-09-18, 2020-09-18 00:00:00 UTC, 18-sept-20)."
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
        message = paste(length(overlap), "records already exist in repository (same key fields).")
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
# DUPLICATE RESOLUTION HELPERS
# -----------------------------
is_blank_value <- function(x) {
  is.na(x) | trimws(as.character(x)) == ""
}

first_non_blank <- function(x) {
  idx <- which(!is_blank_value(x))
  if (length(idx) == 0) return(NA)
  x[idx[1]]
}

collapse_unique_text <- function(x, sep = " | ") {
  x <- as.character(x)
  x <- trimws(x)
  x <- x[!is.na(x) & x != ""]
  x <- unique(x)
  if (length(x) == 0) return(NA_character_)
  paste(x, collapse = sep)
}

merge_duplicate_group <- function(group_df, schema_types, key_cols = duplicate_key_cols) {
  if (nrow(group_df) == 0) return(group_df)
  if (nrow(group_df) == 1) {
    out <- group_df
    out <- normalize_admin_dates(out)
    out$KEY_ID <- create_unique_id_dt(out)
    return(out)
  }
  
  out <- group_df[1, , drop = FALSE]
  
  for (col in names(group_df)) {
    vals <- group_df[[col]]
    
    if (col == "ROW_ID") {
      out[[col]] <- group_df$ROW_ID[1]
      next
    }
    
    if (col == "KEY_ID") {
      next
    }
    
    if (col %in% c("duplicate_group", "record_num")) {
      next
    }
    
    tp <- schema_types[[col]]
    
    if (col %in% key_cols) {
      out[[col]] <- first_non_blank(vals)
      next
    }
    
    if (!is.null(tp) && tp == "Date") {
      out[[col]] <- first_non_blank(vals)
      next
    }
    
    if (!is.null(tp) && tp == "numeric") {
      nums <- suppressWarnings(as.numeric(vals))
      if (all(is.na(nums))) {
        out[[col]] <- NA_real_
      } else {
        out[[col]] <- sum(nums, na.rm = TRUE)
      }
      next
    }
    
    out[[col]] <- collapse_unique_text(vals)
  }
  
  out <- out[, intersect(names(out), c(names(group_df), "ROW_ID", "KEY_ID")), drop = FALSE]
  out <- normalize_admin_dates(out)
  out$KEY_ID <- create_unique_id_dt(out)
  out
}

resolve_duplicates_by_method <- function(repo, method = c("keep_first", "merge_all"), schema_types) {
  method <- match.arg(method)
  repo <- ensure_rowid_keyid(repo)
  
  dup_df <- find_all_duplicates(repo)
  if (nrow(dup_df) == 0) return(repo)
  
  if (method == "keep_first") {
    rows_to_remove <- dup_df %>%
      arrange(KEY_ID, ROW_ID) %>%
      group_by(KEY_ID) %>%
      slice(-1) %>%
      ungroup() %>%
      pull(ROW_ID)
    
    repo <- repo[!(repo$ROW_ID %in% rows_to_remove), , drop = FALSE]
    repo <- ensure_rowid_keyid(repo)
    return(repo)
  }
  
  if (method == "merge_all") {
    merged_rows <- dup_df %>%
      split(.$KEY_ID) %>%
      purrr::map_dfr(~ merge_duplicate_group(.x, schema_types = schema_types))
    
    duplicate_row_ids <- dup_df$ROW_ID
    repo_non_dup <- repo[!(repo$ROW_ID %in% duplicate_row_ids), , drop = FALSE]
    
    repo_final <- bind_rows(repo_non_dup, merged_rows)
    repo_final <- ensure_rowid_keyid(repo_final)
    repo_final <- remove_duplicates_from_repo(repo_final)
    return(repo_final)
  }
  
  repo
}

# -----------------------------
# UI
# -----------------------------
ui <- fluidPage(
  useShinyjs(),
  
  div(
    id = "who-header",
    style = "
      position: sticky;
      top: 0;
      z-index: 999;
      background-color: #337ab7;
      padding: 6px 14px;
      border-bottom: 2px solid #007ab8;
      box-shadow: 0 1px 4px rgba(0,0,0,0.35);
      display: flex;
      align-items: center;
      gap: 10px;
    ",
    tags$img(src = "WHO_AFRO_logo.png", style = "height:38px; width:auto;"),
    div(
      style = "flex-grow: 1; text-align:center; background-color:#337ab7; padding:4px 10px;",
      h3("Administrative Data Portal – Country Focal Point Interface",
         style = "color:white; margin:0; font-weight:700; font-size:20px;"),
      div("Polio Eradication Program – WHO Regional Office for Africa",
          style = "color:#e6f4fb; margin-top:1px; font-size:11px; font-weight:300;"),
      div(textOutput("last_update"),
          style = "color:#cfe9f7; margin-top:1px; font-size:10px; font-weight:300;")
    )
  ),
  
  tags$head(uiOutput("theme_css")),
  uiOutput("app_body")
)

# -----------------------------
# SERVER
# -----------------------------
server <- function(input, output, session) {
  
  user_country <- reactiveVal(NULL)
  user_role    <- reactiveVal("user")
  
  duplicate_edit_data <- reactiveVal(NULL)
  duplicate_edit_key  <- reactiveVal(NULL)
  
  output$theme_css <- renderUI({
    if (isTRUE(input$dark_mode)) {
      tags$style(HTML("
        body { background-color: #181a1f; color: #e5e5e5; }
        .well, .panel, .panel-body, .panel-default { background-color: #252a33 !important; border-color: #3a3f4b !important; color: #e5e5e5 !important; }
        .form-control, .selectize-input, .input-group-addon { background-color: #2b3039; border-color: #3a3f4b; color: #e5e5e5; }
        .form-control:focus, .selectize-input.focus { border-color: #009FE3; box-shadow: 0 0 0 1px #009FE3; }
        .nav-tabs > li > a { background-color: #252a33; color: #e5e5e5; border-color: #3a3f4b; }
        .nav-tabs > li.active > a, .nav-tabs > li.active > a:focus, .nav-tabs > li.active > a:hover { background-color: #2f3640; color: #ffffff; border-color: #009FE3; }
        .tab-content { background-color: #181a1f; border-top: none; }

        .excel-panel { background-color: #252a33; border: 1px solid #3a3f4b; border-radius: 6px; padding: 10px 10px 5px 10px; margin-top: 10px; box-shadow: 0 1px 4px rgba(0,0,0,0.6); }
        .excel-title { font-weight: 600; color: #ffffff; margin-bottom: 5px; }
        .excel-subtitle { font-size: 0.9em; color: #c0c0c0; margin-bottom: 8px; }

        .excel-table table.dataTable { border-collapse: collapse !important; }
        .excel-table table.dataTable thead th { background-color: #337ab7 !important; color: #ffffff !important; font-weight: 600; border-bottom: 1px solid #1f3c6e !important; }
        .excel-table table.dataTable tbody td { border-right: 1px solid #3a3f4b !important; border-bottom: 1px solid #3a3f4b !important; color: #e5e5e5 !important; }
        .excel-table table.dataTable tbody tr:nth-child(odd) { background-color: #242831 !important; }
        .excel-table table.dataTable tbody tr:nth-child(even) { background-color: #2b3039 !important; }
        .excel-table table.dataTable tbody tr:hover { background-color: #3b4250 !important; }

        .excel-table table.dataTable tbody tr.selected,
        .excel-table table.dataTable tbody tr.selected:hover { background-color: #0b3a57 !important; }
        .excel-table table.dataTable tbody tr.selected td { background-color: #0b3a57 !important; color: #ffffff !important; }
        .excel-table table.dataTable tbody td:focus { outline: 2px solid #00b3ff !important; outline-offset: -2px; }

        .sidebarPanel h4 { color: #ffffff; }
        .help-block, .login-subtitle { color: #c0c0c0; }
      "))
    } else {
      tags$style(HTML("
        body { background-color: #f4f6f9; color: #222222; }
        .well, .panel, .panel-body, .panel-default { background-color: #ffffff !important; border-color: #d0d7e2 !important; color: #222222 !important; }
        .form-control, .selectize-input, .input-group-addon { background-color: #ffffff; border-color: #ced4da; color: #222222; }
        .form-control:focus, .selectize-input.focus { border-color: #009FE3; box-shadow: 0 0 0 1px #009FE3; }
        .nav-tabs > li > a { background-color: #e9edf5; color: #333333; border-color: #d0d7e2; }
        .nav-tabs > li.active > a, .nav-tabs > li.active > a:focus, .nav-tabs > li.active > a:hover { background-color: #ffffff; color: #000000; border-color: #009FE3; }
        .tab-content { background-color: #f4f6f9; border-top: none; }

        .excel-panel { background-color: #f8fbff; border: 1px solid #c5d5ea; border-radius: 6px; padding: 10px 10px 5px 10px; margin-top: 10px; box-shadow: 0 1px 3px rgba(0,0,0,0.05); }
        .excel-title { font-weight: 600; color: #2f5597; margin-bottom: 5px; }
        .excel-subtitle { font-size: 0.9em; color: #555555; margin-bottom: 8px; }

        .excel-table table.dataTable { border-collapse: collapse !important; }
        .excel-table table.dataTable thead th { background-color: #d9ead3 !important; color: #000000 !important; font-weight: 600; border-bottom: 1px solid #9bbb59 !important; }
        .excel-table table.dataTable tbody td { border-right: 1px solid #e0e0e0 !important; border-bottom: 1px solid #e0e0e0 !important; }
        .excel-table table.dataTable tbody tr:nth-child(odd) { background-color: #ffffff !important; }
        .excel-table table.dataTable tbody tr:nth-child(even) { background-color: #f7fbff !important; }
        .excel-table table.dataTable tbody tr:hover { background-color: #fff2cc !important; }

        .excel-table table.dataTable tbody tr.selected,
        .excel-table table.dataTable tbody tr.selected:hover { background-color: #cfe2ff !important; }
        .excel-table table.dataTable tbody tr.selected td { background-color: #cfe2ff !important; }
        .excel-table table.dataTable tbody td:focus { outline: 2px solid #009fe3 !important; outline-offset: -2px; }

        .sidebarPanel h4 { color: #222222; }
        .help-block, .login-subtitle { color: #666666; }
      "))
    }
  })
  
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
      paste0("Last update: ", format(t, "%Y-%m-%d %H:%M"), " | Template: ", basename(template_path))
    } else {
      paste0("Last update: repository not yet created | Template: ", basename(template_path))
    }
  })
  
  output$download_empty_template <- downloadHandler(
    filename = function() paste0("AFRO_admin_data_TEMPLATE_EMPTY_", Sys.Date(), ".xlsx"),
    content = function(file) {
      empty_df <- make_empty_df_from_schema(template_schema, n_rows = 0)
      writexl::write_xlsx(empty_df, path = file)
    }
  )
  
  # -----------------------------
  # Manual entry grid
  # -----------------------------
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
    
    country_col <- which(names(df) == "Country")
    editable_cfg <- if (length(country_col) > 0 && isTRUE(user_role() != "admin")) {
      list(target = "cell", disable = list(columns = country_col - 1))
    } else {
      "cell"
    }
    
    datatable(
      df,
      editable = editable_cfg,
      selection = "single",
      extensions = c("KeyTable"),
      options = list(
        pageLength = 5,
        scrollX = TRUE,
        processing = TRUE,
        keys = TRUE,
        deferRender = TRUE
      )
    )
  }, server = TRUE)
  
  observe({
    selected <- input$manual_table_rows_selected
    if (!is.null(selected) && length(selected) > 0) {
      runjs("
        document.getElementById('delete_manual_row').style.opacity = '1';
        document.getElementById('delete_manual_row').style.pointerEvents = 'auto';
      ")
    } else {
      runjs("
        document.getElementById('delete_manual_row').style.opacity = '0.4';
        document.getElementById('delete_manual_row').style.pointerEvents = 'none';
      ")
    }
  })
  
  observeEvent(input$manual_table_cell_edit, {
    req(manual_data())
    info <- input$manual_table_cell_edit
    df <- manual_data()
    
    col_index <- info$col + 1
    col_name <- names(df)[col_index]
    
    schema_types <- template_schema$column_types
    
    if (col_name == "SIA_date") {
      df[info$row, col_name] <- parse_sia_date(info$value)
    } else {
      tp <- schema_types[[col_name]]
      df[info$row, col_name] <- if (!is.null(tp) && tp == "numeric") {
        suppressWarnings(as.numeric(info$value))
      } else if (!is.null(tp) && tp == "Date") {
        suppressWarnings(as.Date(info$value))
      } else {
        as.character(info$value)
      }
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
  
  # -----------------------------
  # EDIT REPOSITORY
  # -----------------------------
  edit_history <- reactiveVal(list())
  current_edit_state <- reactiveVal(NULL)
  
  edit_filter_vals <- reactiveValues(
    country = "All",
    use_sia = FALSE,
    sia_from = Sys.Date() - 30,
    sia_to   = Sys.Date()
  )
  
  observeEvent(input$edit_apply_filter, {
    edit_filter_vals$country  <- input$edit_filter_country
    edit_filter_vals$use_sia  <- isTRUE(input$edit_use_sia_filter)
    edit_filter_vals$sia_from <- as.Date(input$edit_filter_sia_from)
    edit_filter_vals$sia_to   <- as.Date(input$edit_filter_sia_to)
    
    if (!is.null(user_country())) {
      current_edit_state(edit_filtered_data())
    }
    showNotification("Filters applied.", type = "message", duration = 2)
  })
  
  observeEvent(input$edit_clear_filter, {
    updateSelectInput(session, "edit_filter_country", selected = "All")
    updateCheckboxInput(session, "edit_use_sia_filter", value = FALSE)
    updateDateInput(session, "edit_filter_sia_from", value = Sys.Date() - 30)
    updateDateInput(session, "edit_filter_sia_to", value = Sys.Date())
    
    edit_filter_vals$country  <- "All"
    edit_filter_vals$use_sia  <- FALSE
    edit_filter_vals$sia_from <- Sys.Date() - 30
    edit_filter_vals$sia_to   <- Sys.Date()
    
    if (!is.null(user_country())) {
      current_edit_state(edit_filtered_data())
    }
    showNotification("Filters cleared.", type = "message", duration = 2)
  })
  
  edit_filtered_data <- reactive({
    req(admin_repo())
    df <- admin_repo()
    
    if (!is.null(edit_filter_vals$country) &&
        edit_filter_vals$country != "All" &&
        "Country" %in% names(df)) {
      df <- df[df$Country == edit_filter_vals$country, , drop = FALSE]
    }
    
    if (isTRUE(edit_filter_vals$use_sia) &&
        "SIA_date" %in% names(df)) {
      df <- df[!is.na(df$SIA_date) &
                 df$SIA_date >= edit_filter_vals$sia_from &
                 df$SIA_date <= edit_filter_vals$sia_to, , drop = FALSE]
    }
    
    if (!is.null(user_country()) &&
        isTRUE(user_role() != "admin") &&
        "Country" %in% names(df) &&
        nrow(df) > 0) {
      df <- df[df$Country == user_country(), , drop = FALSE]
    }
    
    df
  })
  
  observeEvent(edit_filtered_data(), {
    if (!is.null(user_country())) {
      current_edit_state(edit_filtered_data())
    }
  }, ignoreInit = FALSE)
  
  output$edit_table <- renderDT({
    req(current_edit_state())
    df <- current_edit_state()
    
    country_col <- which(names(df) == "Country")
    editable_cfg <- if (length(country_col) > 0 && isTRUE(user_role() != "admin")) {
      list(target = "cell", disable = list(columns = country_col - 1))
    } else {
      "cell"
    }
    
    datatable(
      df,
      editable = editable_cfg,
      selection = "multiple",
      filter = "top",
      extensions = c("Scroller", "KeyTable", "Buttons"),
      options = list(
        pageLength = 25,
        scrollX = TRUE,
        scrollY = 520,
        scroller = TRUE,
        deferRender = TRUE,
        processing = TRUE,
        keys = TRUE,
        dom = "Bfrtip",
        buttons = c("copy", "csv", "excel")
      )
    )
  }, server = TRUE)
  
  observeEvent(input$edit_table_cell_edit, {
    req(current_edit_state(), input$edit_table_cell_edit)
    
    info <- input$edit_table_cell_edit
    df <- current_edit_state()
    col_index <- info$col + 1
    col_name <- names(df)[col_index]
    
    prev_value <- df[info$row, col_name]
    row_id <- df$ROW_ID[info$row]
    
    new_value <- if (col_name == "SIA_date") {
      parse_sia_date(info$value)
    } else if (inherits(df[[col_name]], "Date")) {
      suppressWarnings(as.Date(info$value))
    } else if (is.numeric(df[[col_name]])) {
      suppressWarnings(as.numeric(info$value))
    } else {
      as.character(info$value)
    }
    
    df[info$row, col_name] <- new_value
    df <- normalize_admin_dates(df)
    
    if (col_name %in% duplicate_key_cols) {
      df$KEY_ID[info$row] <- create_unique_id_dt(df[info$row, , drop = FALSE])[1]
      current_id <- df$KEY_ID[info$row]
      if (current_id %in% df$KEY_ID[-info$row]) {
        dup_row <- which(df$KEY_ID == current_id & seq_len(nrow(df)) != info$row)[1]
        showModal(modalDialog(
          title = "Duplicate Detected",
          paste("This edit would create a duplicate (within filtered view) with row", dup_row, ". Please review key fields."),
          footer = modalButton("OK")
        ))
        df[info$row, col_name] <- prev_value
        df <- normalize_admin_dates(df)
        if (col_name %in% duplicate_key_cols) {
          df$KEY_ID[info$row] <- create_unique_id_dt(df[info$row, , drop = FALSE])[1]
        }
        current_edit_state(df)
        return(NULL)
      }
    }
    
    if (isTRUE(user_role() != "admin") && "Country" %in% names(df)) {
      df$Country <- user_country()
    }
    
    current_edit_state(df)
    
    hist <- edit_history()
    hist[[length(hist) + 1]] <- list(
      timestamp = Sys.time(),
      ROW_ID = row_id,
      row = info$row,
      col = col_name,
      previous = prev_value,
      new = df[info$row, col_name]
    )
    edit_history(hist)
  })
  
  observeEvent(input$edit_save, {
    req(current_edit_state(), admin_repo())
    
    edited_df <- current_edit_state()
    original_df <- edit_filtered_data()
    
    if (nrow(edited_df) != nrow(original_df)) {
      showNotification("Row structure changed unexpectedly. Please refresh the filter and try again.", type = "error")
      return(NULL)
    }
    
    common_cols <- intersect(names(edited_df), names(original_df))
    compare_cols <- setdiff(common_cols, c("duplicate_group", "record_num"))
    
    changed_rows <- which(!apply(
      edited_df[, compare_cols, drop = FALSE] == original_df[, compare_cols, drop = FALSE],
      1, all
    ))
    
    if (length(changed_rows) == 0) {
      showNotification("No changes to save.", type = "info")
      return(NULL)
    }
    
    full_repo <- admin_repo()
    changed_data <- edited_df[changed_rows, , drop = FALSE]
    rest_of_repo <- full_repo[!(full_repo$ROW_ID %in% changed_data$ROW_ID), , drop = FALSE]
    
    validation <- validate_admin_data(changed_data, rest_of_repo)
    if (length(validation) > 0) {
      if (!is.null(validation$existing_duplicates)) {
        showModal(modalDialog(
          title = "Duplicate Records Found",
          size = "l",
          div(
            p(validation$existing_duplicates$message),
            DTOutput("duplicate_details_table")
          ),
          footer = modalButton("OK")
        ))
        
        output$duplicate_details_table <- renderDT({
          datatable(
            validation$existing_duplicates$rows,
            options = list(pageLength = 5, scrollX = TRUE, processing = TRUE, deferRender = TRUE)
          )
        }, server = TRUE)
      } else {
        showNotification(
          paste("Validation errors:", paste(unlist(validation), collapse = "; ")),
          type = "error", duration = 10
        )
      }
      return(NULL)
    }
    
    updated_repo <- full_repo
    idx_map <- match(changed_data$ROW_ID, updated_repo$ROW_ID)
    
    for (i in seq_along(idx_map)) {
      ridx <- idx_map[i]
      if (is.na(ridx)) next
      for (col in names(changed_data)) {
        if (col %in% names(updated_repo)) {
          updated_repo[ridx, col] <- changed_data[i, col]
        }
      }
    }
    
    updated_repo <- ensure_rowid_keyid(updated_repo)
    save_repo(updated_repo)
    admin_repo(updated_repo)
    current_edit_state(edit_filtered_data())
    
    showNotification(paste("Successfully saved", length(changed_rows), "record(s)."), type = "success")
  })
  
  observeEvent(input$edit_delete, {
    req(input$edit_table_rows_selected, current_edit_state())
    selected_rows <- input$edit_table_rows_selected
    df <- current_edit_state()
    sel_ids <- df$ROW_ID[selected_rows]
    
    showModal(modalDialog(
      title = "Confirm Delete",
      paste("Are you sure you want to delete", length(sel_ids), "record(s)?"),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_delete", "Delete", class = "btn-danger")
      )
    ))
  })
  
  observeEvent(input$confirm_delete, {
    req(input$edit_table_rows_selected, current_edit_state())
    df <- current_edit_state()
    sel_ids <- df$ROW_ID[input$edit_table_rows_selected]
    
    full_repo <- admin_repo()
    full_repo <- full_repo[!(full_repo$ROW_ID %in% sel_ids), , drop = FALSE]
    
    save_repo(full_repo)
    admin_repo(full_repo)
    current_edit_state(edit_filtered_data())
    
    removeModal()
    showNotification(paste("Successfully deleted", length(sel_ids), "record(s)"), type = "success")
  })
  
  observeEvent(input$edit_undo, {
    hist <- edit_history()
    if (length(hist) == 0) {
      showNotification("Nothing to undo", type = "info")
      return(NULL)
    }
    
    last_change <- hist[[length(hist)]]
    df <- current_edit_state()
    if (is.null(df)) {
      showNotification("Nothing to undo.", type = "info")
      return(NULL)
    }
    
    row_match <- which(df$ROW_ID == last_change$ROW_ID)
    if (length(row_match) == 0) {
      showNotification("The edited row is not visible in the current filtered view.", type = "warning")
      return(NULL)
    }
    
    df[row_match[1], last_change$col] <- last_change$previous
    df <- normalize_admin_dates(df)
    if (last_change$col %in% duplicate_key_cols) {
      df$KEY_ID[row_match[1]] <- create_unique_id_dt(df[row_match[1], , drop = FALSE])[1]
    }
    
    current_edit_state(df)
    edit_history(hist[-length(hist)])
    showNotification("Undid last change (not yet saved).", type = "info")
  })
  
  output$edit_export_changes <- downloadHandler(
    filename = function() paste0("changes_log_", Sys.Date(), ".csv"),
    content = function(file) {
      hist <- edit_history()
      if (length(hist) == 0) {
        write.csv(data.frame(Message = "No changes recorded"), file, row.names = FALSE)
      } else {
        log_df <- rbindlist(lapply(hist, as.data.table), fill = TRUE)
        fwrite(log_df, file)
      }
    }
  )
  
  # -----------------------------
  # Append manual rows
  # -----------------------------
  reset_manual_grid <- function() {
    df_new <- make_empty_df_from_schema(template_schema, n_rows = 1)
    if ("Entry_Date" %in% names(df_new)) df_new$Entry_Date[1] <- Sys.Date()
    if (isTRUE(user_role() != "admin") && "Country" %in% names(df_new)) df_new$Country[1] <- user_country()
    df_new <- normalize_admin_dates(df_new)
    df_new <- convert_geo(df_new)
    manual_data(df_new)
  }
  
  append_new_data <- function(new_data, update_mode = FALSE) {
    repo <- admin_repo()
    new_data <- normalize_admin_dates(new_data)
    
    max_id <- suppressWarnings(max(repo$ROW_ID, na.rm = TRUE))
    if (!is.finite(max_id)) max_id <- 0
    new_data$ROW_ID <- seq(max_id + 1, max_id + nrow(new_data))
    new_data$KEY_ID <- create_unique_id_dt(new_data)
    
    if (update_mode) {
      repo <- ensure_rowid_keyid(repo)
      repo_map <- match(new_data$KEY_ID, repo$KEY_ID)
      
      to_update <- which(!is.na(repo_map))
      to_add <- which(is.na(repo_map))
      
      if (length(to_update) > 0) {
        for (i in to_update) {
          ridx <- repo_map[i]
          keep_rowid <- repo$ROW_ID[ridx]
          for (col in names(new_data)) {
            if (col %in% names(repo) && col != "ROW_ID") repo[ridx, col] <- new_data[i, col]
          }
          repo$ROW_ID[ridx] <- keep_rowid
        }
      }
      
      if (length(to_add) > 0) {
        repo <- bind_rows(repo, new_data[to_add, , drop = FALSE])
      }
      
      repo <- ensure_rowid_keyid(repo)
      repo <- remove_duplicates_from_repo(repo)
      
      save_repo(repo)
      admin_repo(repo)
      
      showNotification(
        paste("Updated", length(to_update), "record(s) and added", length(to_add), "new record(s)."),
        type = "success"
      )
    } else {
      repo <- bind_rows(repo, new_data)
      repo <- ensure_rowid_keyid(repo)
      repo <- remove_duplicates_from_repo(repo)
      
      save_repo(repo)
      admin_repo(repo)
      
      showNotification(paste("Added", nrow(new_data), "new record(s)."), type = "success")
    }
    
    reset_manual_grid()
  }
  
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
    
    validation <- validate_admin_data(non_empty, admin_repo())
    if (length(validation) > 0) {
      if (!is.null(validation$existing_duplicates)) {
        duplicate_info <- validation$existing_duplicates
        showModal(modalDialog(
          title = "Duplicate Records Found",
          size = "l",
          div(
            p(paste("Found", duplicate_info$count, "duplicate key(s).")),
            p("Duplicates share key: Country + Province + District + SIA_date + Round_Add + Vaccine_type + Response"),
            DTOutput("append_duplicate_table"),
            br(),
            p("Proceed?")
          ),
          footer = tagList(
            actionButton("append_update_all", "Update All (Replace Existing)", class = "btn-primary"),
            actionButton("append_skip_duplicates", "Skip Duplicates", class = "btn-info"),
            modalButton("Cancel")
          )
        ))
        
        output$append_duplicate_table <- renderDT({
          datatable(
            duplicate_info$rows,
            options = list(pageLength = 5, scrollX = TRUE, processing = TRUE, deferRender = TRUE)
          )
        }, server = TRUE)
        
        session$userData$pending_append <- list(data = non_empty, dup_ids = duplicate_info$ids)
      } else {
        showNotification(
          paste("Validation errors:", paste(unlist(validation), collapse = "; ")),
          type = "error", duration = 10
        )
      }
      return(NULL)
    }
    
    append_new_data(non_empty, update_mode = FALSE)
  })
  
  observeEvent(input$append_update_all, {
    req(session$userData$pending_append)
    pending <- session$userData$pending_append
    append_new_data(pending$data, update_mode = TRUE)
    removeModal()
  })
  
  observeEvent(input$append_skip_duplicates, {
    req(session$userData$pending_append)
    pending <- session$userData$pending_append
    new_data <- pending$data
    
    new_ids <- create_unique_id_dt(new_data)
    repo_ids <- if ("KEY_ID" %in% names(admin_repo())) admin_repo()$KEY_ID else create_unique_id_dt(admin_repo())
    keep_idx <- which(!new_ids %in% repo_ids)
    
    if (length(keep_idx) > 0) {
      append_new_data(new_data[keep_idx, , drop = FALSE], update_mode = FALSE)
      showNotification(paste("Skipped", nrow(new_data) - length(keep_idx), "duplicate record(s)."), type = "info")
    } else {
      showNotification("All records were duplicates. Nothing added.", type = "info")
    }
    
    removeModal()
  })
  
  # -----------------------------
  # File upload
  # -----------------------------
  observeEvent(input$add_file, {
    req(input$upload_file, user_country())
    
    new_data <- tryCatch(
      read_excel(input$upload_file$datapath),
      error = function(e) { showNotification(e$message, type = "error"); return(NULL) }
    )
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
        showNotification(
          paste0("Uploaded file contains rows for another country. Only '", user_country(), "' is allowed."),
          type = "error"
        )
        return(NULL)
      }
      new_data$Country <- user_country()
    }
    
    if ("Entry_Date" %in% names(new_data)) new_data$Entry_Date <- Sys.Date()
    new_data <- normalize_admin_dates(new_data)
    
    validation <- validate_admin_data(new_data, admin_repo())
    if (length(validation) > 0 && is.null(validation$existing_duplicates)) {
      showNotification(
        paste("Validation errors:", paste(unlist(validation), collapse = "; ")),
        type = "error", duration = 10
      )
      return(NULL)
    }
    
    append_new_data(new_data, update_mode = FALSE)
    showNotification("File data appended with entry timestamps.", type = "message")
  })
  
  # -----------------------------
  # Repository preview + columns + duplicates
  # -----------------------------
  output$repo_table <- renderDT({
    req(user_country())
    datatable(
      repo_country(),
      extensions = c("Scroller", "Buttons"),
      options = list(
        pageLength = 20,
        scrollX = TRUE,
        scrollY = 520,
        scroller = TRUE,
        deferRender = TRUE,
        processing = TRUE,
        dom = "Bfrtip",
        buttons = c("copy", "csv", "excel")
      )
    )
  }, server = TRUE)
  
  output$column_info <- renderTable({
    ci <- tibble::tibble(
      column_name = c(template_schema$column_names, setdiff(c("ROW_ID", "KEY_ID"), template_schema$column_names)),
      column_type = c(
        unname(template_schema$column_types[template_schema$column_names]),
        rep("system", length(setdiff(c("ROW_ID", "KEY_ID"), template_schema$column_names)))
      )
    )
    
    ci %>%
      mutate(
        Description = case_when(
          column_name == "Entry_Date" ~ "Audit date (auto-set on append; editable in Edit Repository if needed)",
          column_name == "SIA_date" ~ "KEY campaign date (used for filtering + duplicate detection)",
          column_name == "ROW_ID" ~ "Stable internal row identifier (do not edit)",
          column_name == "KEY_ID" ~ "Stable duplicate key computed from key columns (do not edit)",
          TRUE ~ ""
        )
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
        deferRender = TRUE,
        processing = TRUE,
        dom = "Bfrtip",
        buttons = c("copy", "csv", "excel")
      )
    )
  }, server = TRUE)
  
  output$duplicate_panel <- renderUI({
    req(admin_repo())
    all_duplicates <- find_all_duplicates(admin_repo())
    
    if (nrow(all_duplicates) == 0) {
      return(div(class = "alert alert-success", "No duplicates found in the repository."))
    }
    
    div(
      class = "excel-panel",
      div(class = "excel-title", "Duplicate Resolution Center"),
      div(
        class = "excel-subtitle",
        paste(
          "Found", nrow(all_duplicates), "records in",
          length(unique(all_duplicates$duplicate_group)), "duplicate groups."
        )
      ),
      
      div(
        style = "display:flex; gap:8px; flex-wrap:wrap; margin-bottom:10px;",
        actionButton("dup_edit_group", "Edit Selected Group", class = "btn-primary"),
        actionButton("dup_merge_selected_groups", "Merge Selected Group(s)", class = "btn-success"),
        actionButton("dup_keep_first_selected_groups", "Keep First in Selected Group(s)", class = "btn-warning"),
        actionButton("dup_delete_selected_rows", "Delete Selected Rows", class = "btn-danger"),
        downloadButton("download_duplicates_xlsx", "Download Duplicates")
      ),
      
      div(
        style = "display:flex; gap:8px; flex-wrap:wrap; margin-bottom:10px;",
        actionButton("dup_merge_all_groups", "Apply Merge to ALL Duplicates", class = "btn-success"),
        actionButton("dup_keep_first_all_groups", "Apply Keep-First to ALL Duplicates", class = "btn-warning")
      ),
      
      div(
        style = "margin-bottom:8px; font-size:12px; color:#999;",
        "Tip: select rows from one duplicate group to edit or merge that group. For typing errors, use 'Edit Selected Group'."
      ),
      
      div(class = "excel-table", DTOutput("all_duplicates_table")),
      br(),
      uiOutput("duplicate_group_editor_ui")
    )
  })
  
  output$all_duplicates_table <- renderDT({
    req(admin_repo())
    duplicates <- find_all_duplicates(admin_repo())
    if (nrow(duplicates) == 0) return(datatable(data.frame(Message = "No duplicates found")))
    
    datatable(
      duplicates,
      selection = "multiple",
      filter = "top",
      extensions = c("Scroller", "KeyTable", "Buttons"),
      options = list(
        pageLength = 10,
        scrollX = TRUE,
        scrollY = 520,
        scroller = TRUE,
        deferRender = TRUE,
        processing = TRUE,
        keys = TRUE,
        dom = "Bfrtip",
        buttons = c("copy", "csv", "excel")
      )
    )
  }, server = TRUE)
  
  output$duplicate_group_editor_ui <- renderUI({
    req(duplicate_edit_data())
    
    div(
      class = "excel-panel",
      div(class = "excel-title", paste("Editing Duplicate Group:", duplicate_edit_key())),
      div(class = "excel-subtitle", "Correct typing issues directly, then save the group or merge it."),
      div(class = "excel-table", DTOutput("duplicate_group_edit_table")),
      br(),
      div(
        style = "display:flex; gap:8px; flex-wrap:wrap;",
        actionButton("dup_group_add_row", "Add Row", class = "btn-default"),
        actionButton("dup_group_delete_row", "Delete Selected Row", class = "btn-danger"),
        actionButton("dup_group_save_edits", "Save Group Edits", class = "btn-primary"),
        actionButton("dup_group_merge_now", "Merge This Group Now", class = "btn-success"),
        actionButton("dup_group_close_editor", "Close Editor", class = "btn-default")
      )
    )
  })
  
  output$duplicate_group_edit_table <- renderDT({
    req(duplicate_edit_data())
    
    datatable(
      duplicate_edit_data(),
      editable = "cell",
      selection = "single",
      extensions = c("KeyTable"),
      options = list(
        pageLength = 10,
        scrollX = TRUE,
        processing = TRUE,
        keys = TRUE,
        deferRender = TRUE
      )
    )
  }, server = TRUE)
  
  observeEvent(input$dup_edit_group, {
    req(admin_repo())
    
    duplicates <- find_all_duplicates(admin_repo())
    selected <- input$all_duplicates_table_rows_selected
    
    if (is.null(selected) || length(selected) == 0) {
      showNotification("Please select at least one duplicate row.", type = "warning")
      return(NULL)
    }
    
    selected_keys <- unique(duplicates$KEY_ID[selected])
    
    if (length(selected_keys) != 1) {
      showNotification("Please select rows from only one duplicate group to edit.", type = "warning")
      return(NULL)
    }
    
    group_df <- duplicates[duplicates$KEY_ID == selected_keys, , drop = FALSE]
    duplicate_edit_data(group_df)
    duplicate_edit_key(selected_keys)
    showNotification("Duplicate group loaded into editor.", type = "message")
  })
  
  observeEvent(input$duplicate_group_edit_table_cell_edit, {
    req(duplicate_edit_data())
    
    info <- input$duplicate_group_edit_table_cell_edit
    df <- duplicate_edit_data()
    
    col_index <- info$col + 1
    col_name <- names(df)[col_index]
    schema_types <- template_schema$column_types
    
    if (col_name == "ROW_ID") {
      showNotification("ROW_ID cannot be edited.", type = "warning")
      return(NULL)
    }
    
    if (col_name == "KEY_ID") {
      showNotification("KEY_ID is computed automatically.", type = "warning")
      return(NULL)
    }
    
    if (col_name %in% c("duplicate_group", "record_num")) {
      showNotification(paste(col_name, "is informational and cannot be edited."), type = "warning")
      return(NULL)
    }
    
    if (col_name == "SIA_date") {
      df[info$row, col_name] <- parse_sia_date(info$value)
    } else {
      tp <- schema_types[[col_name]]
      df[info$row, col_name] <- if (!is.null(tp) && tp == "numeric") {
        suppressWarnings(as.numeric(info$value))
      } else if (!is.null(tp) && tp == "Date") {
        suppressWarnings(as.Date(info$value))
      } else {
        as.character(info$value)
      }
    }
    
    df <- normalize_admin_dates(df)
    df$KEY_ID <- create_unique_id_dt(df)
    duplicate_edit_data(df)
  })
  
  observeEvent(input$dup_group_add_row, {
    req(duplicate_edit_data())
    
    df <- duplicate_edit_data()
    new_row <- df[1, , drop = FALSE]
    new_row[,] <- NA
    
    for (k in duplicate_key_cols) {
      if (k %in% names(df)) new_row[[k]] <- df[[k]][1]
    }
    
    max_id <- suppressWarnings(max(admin_repo()$ROW_ID, na.rm = TRUE))
    if (!is.finite(max_id)) max_id <- 0
    new_row$ROW_ID <- max_id + 1
    if ("Entry_Date" %in% names(new_row)) new_row$Entry_Date <- Sys.Date()
    if ("duplicate_group" %in% names(new_row)) new_row$duplicate_group <- NA
    if ("record_num" %in% names(new_row)) new_row$record_num <- NA
    new_row$KEY_ID <- create_unique_id_dt(new_row)
    
    df <- bind_rows(df, new_row)
    duplicate_edit_data(df)
  })
  
  observeEvent(input$dup_group_delete_row, {
    req(duplicate_edit_data())
    
    selected <- input$duplicate_group_edit_table_rows_selected
    if (is.null(selected) || length(selected) == 0) {
      showNotification("Select a row to delete from the duplicate group.", type = "warning")
      return(NULL)
    }
    
    df <- duplicate_edit_data()
    df <- df[-selected, , drop = FALSE]
    duplicate_edit_data(df)
  })
  
  observeEvent(input$dup_group_save_edits, {
    req(duplicate_edit_data(), admin_repo())
    
    edited_group <- duplicate_edit_data()
    full_repo <- admin_repo()
    
    original_row_ids <- full_repo$ROW_ID[full_repo$KEY_ID == duplicate_edit_key()]
    full_repo <- full_repo[!(full_repo$ROW_ID %in% original_row_ids), , drop = FALSE]
    
    edited_group <- edited_group[, setdiff(names(edited_group), c("duplicate_group", "record_num")), drop = FALSE]
    edited_group <- ensure_rowid_keyid(edited_group)
    
    validation <- validate_admin_data(edited_group, full_repo)
    if (length(validation) > 0 && is.null(validation$existing_duplicates)) {
      showNotification(
        paste("Validation errors:", paste(unlist(validation), collapse = "; ")),
        type = "error",
        duration = 10
      )
      return(NULL)
    }
    
    updated_repo <- bind_rows(full_repo, edited_group)
    updated_repo <- ensure_rowid_keyid(updated_repo)
    
    save_repo(updated_repo)
    admin_repo(updated_repo)
    
    duplicate_edit_data(NULL)
    duplicate_edit_key(NULL)
    
    showNotification("Duplicate group edits saved to repository.", type = "success")
  })
  
  observeEvent(input$dup_group_merge_now, {
    req(duplicate_edit_data(), admin_repo())
    
    group_df <- duplicate_edit_data()
    group_df_clean <- group_df[, setdiff(names(group_df), c("duplicate_group", "record_num")), drop = FALSE]
    merged_row <- merge_duplicate_group(group_df_clean, schema_types = template_schema$column_types)
    
    full_repo <- admin_repo()
    remove_ids <- group_df$ROW_ID
    full_repo <- full_repo[!(full_repo$ROW_ID %in% remove_ids), , drop = FALSE]
    
    updated_repo <- bind_rows(full_repo, merged_row)
    updated_repo <- ensure_rowid_keyid(updated_repo)
    updated_repo <- remove_duplicates_from_repo(updated_repo)
    
    save_repo(updated_repo)
    admin_repo(updated_repo)
    
    duplicate_edit_data(NULL)
    duplicate_edit_key(NULL)
    
    showNotification("Duplicate group merged successfully.", type = "success")
  })
  
  observeEvent(input$dup_group_close_editor, {
    duplicate_edit_data(NULL)
    duplicate_edit_key(NULL)
  })
  
  observeEvent(input$dup_merge_selected_groups, {
    req(admin_repo())
    
    duplicates <- find_all_duplicates(admin_repo())
    selected <- input$all_duplicates_table_rows_selected
    
    if (is.null(selected) || length(selected) == 0) {
      showNotification("Please select duplicate rows.", type = "warning")
      return(NULL)
    }
    
    selected_keys <- unique(duplicates$KEY_ID[selected])
    
    full_repo <- admin_repo()
    dup_subset <- duplicates[duplicates$KEY_ID %in% selected_keys, , drop = FALSE]
    dup_subset_clean <- dup_subset[, setdiff(names(dup_subset), c("duplicate_group", "record_num")), drop = FALSE]
    
    merged_rows <- dup_subset_clean %>%
      split(.$KEY_ID) %>%
      purrr::map_dfr(~ merge_duplicate_group(.x, schema_types = template_schema$column_types))
    
    full_repo <- full_repo[!(full_repo$ROW_ID %in% dup_subset$ROW_ID), , drop = FALSE]
    updated_repo <- bind_rows(full_repo, merged_rows)
    updated_repo <- ensure_rowid_keyid(updated_repo)
    updated_repo <- remove_duplicates_from_repo(updated_repo)
    
    save_repo(updated_repo)
    admin_repo(updated_repo)
    
    showNotification(
      paste("Merged", length(selected_keys), "duplicate group(s)."),
      type = "success"
    )
  })
  
  observeEvent(input$dup_keep_first_selected_groups, {
    req(admin_repo())
    
    duplicates <- find_all_duplicates(admin_repo())
    selected <- input$all_duplicates_table_rows_selected
    
    if (is.null(selected) || length(selected) == 0) {
      showNotification("Please select duplicate rows.", type = "warning")
      return(NULL)
    }
    
    selected_keys <- unique(duplicates$KEY_ID[selected])
    
    rows_to_remove <- duplicates %>%
      filter(KEY_ID %in% selected_keys) %>%
      arrange(KEY_ID, ROW_ID) %>%
      group_by(KEY_ID) %>%
      slice(-1) %>%
      ungroup() %>%
      pull(ROW_ID)
    
    full_repo <- admin_repo()
    full_repo <- full_repo[!(full_repo$ROW_ID %in% rows_to_remove), , drop = FALSE]
    full_repo <- ensure_rowid_keyid(full_repo)
    
    save_repo(full_repo)
    admin_repo(full_repo)
    
    showNotification(
      paste("Applied keep-first to", length(selected_keys), "duplicate group(s)."),
      type = "success"
    )
  })
  
  observeEvent(input$dup_delete_selected_rows, {
    req(admin_repo())
    
    duplicates <- find_all_duplicates(admin_repo())
    selected <- input$all_duplicates_table_rows_selected
    
    if (is.null(selected) || length(selected) == 0) {
      showNotification("Please select duplicate row(s) to delete.", type = "warning")
      return(NULL)
    }
    
    sel_ids <- duplicates$ROW_ID[selected]
    
    showModal(modalDialog(
      title = "Delete Selected Duplicate Rows",
      paste("Are you sure you want to delete", length(sel_ids), "selected duplicate row(s)?"),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_dup_delete_selected", "Delete Selected", class = "btn-danger")
      )
    ))
  })
  
  observeEvent(input$confirm_dup_delete_selected, {
    req(admin_repo())
    
    duplicates <- find_all_duplicates(admin_repo())
    selected <- input$all_duplicates_table_rows_selected
    
    if (is.null(selected) || length(selected) == 0) {
      removeModal()
      showNotification("No rows selected.", type = "warning")
      return(NULL)
    }
    
    sel_ids <- duplicates$ROW_ID[selected]
    
    full_repo <- admin_repo()
    full_repo <- full_repo[!(full_repo$ROW_ID %in% sel_ids), , drop = FALSE]
    full_repo <- ensure_rowid_keyid(full_repo)
    
    save_repo(full_repo)
    admin_repo(full_repo)
    
    removeModal()
    showNotification(
      paste("Deleted", length(sel_ids), "selected duplicate row(s)."),
      type = "success"
    )
  })
  
  observeEvent(input$dup_merge_all_groups, {
    req(admin_repo())
    
    showModal(modalDialog(
      title = "Apply Merge to All Duplicates",
      "This will merge every duplicate group in the repository: numeric columns will be summed, character columns preserved, and one merged row kept per group.",
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_dup_merge_all", "Merge ALL", class = "btn-success")
      )
    ))
  })
  
  observeEvent(input$confirm_dup_merge_all, {
    req(admin_repo())
    
    updated_repo <- resolve_duplicates_by_method(
      repo = admin_repo(),
      method = "merge_all",
      schema_types = template_schema$column_types
    )
    
    save_repo(updated_repo)
    admin_repo(updated_repo)
    removeModal()
    
    showNotification("Applied MERGE to all duplicate groups.", type = "success")
  })
  
  observeEvent(input$dup_keep_first_all_groups, {
    req(admin_repo())
    
    showModal(modalDialog(
      title = "Apply Keep-First to All Duplicates",
      "This will keep the first row in each duplicate group and remove all others.",
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_dup_keep_first_all", "Keep First for ALL", class = "btn-warning")
      )
    ))
  })
  
  observeEvent(input$confirm_dup_keep_first_all, {
    req(admin_repo())
    
    updated_repo <- resolve_duplicates_by_method(
      repo = admin_repo(),
      method = "keep_first",
      schema_types = template_schema$column_types
    )
    
    save_repo(updated_repo)
    admin_repo(updated_repo)
    removeModal()
    
    showNotification("Applied KEEP-FIRST to all duplicate groups.", type = "success")
  })
  
  output$download_duplicates_xlsx <- downloadHandler(
    filename = function() paste0("AFRO_admin_duplicates_", Sys.Date(), ".xlsx"),
    content = function(file) {
      duplicates <- find_all_duplicates(admin_repo())
      writexl::write_xlsx(duplicates, file)
    }
  )
  
  # -----------------------------
  # Downloads (repo)
  # -----------------------------
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
  
  # -----------------------------
  # LOGIN + APP BODY
  # -----------------------------
  observeEvent(input$login_btn, {
    token <- trimws(input$access_token)
    
    if (identical(token, admin_token)) {
      user_role("admin")
      user_country("ALL")
      current_edit_state(edit_filtered_data())
      showNotification("Admin login successful – full repository access.", type = "message")
    } else if (token %in% names(country_tokens)) {
      user_role("user")
      user_country(country_tokens[[token]])
      current_edit_state(edit_filtered_data())
      showNotification(paste("Login successful – country:", country_tokens[[token]]), type = "message")
    } else {
      showNotification("Invalid token. Please check your access code.", type = "error")
    }
  })
  
  output$app_body <- renderUI({
    if (is.null(user_country())) {
      fluidRow(
        column(
          width = 4, offset = 4,
          br(), br(),
          div(
            style = "background-color:#ffffff; border-radius:8px; padding:18px; box-shadow:0 2px 6px rgba(0,0,0,0.15);",
            h4("AFRO Admin Data Portal – Login", style = "margin-top:0;"),
            div(
              "Please enter your access token. Each country focal point has a dedicated token.",
              class = "login-subtitle",
              style = "font-size:0.9em; margin-bottom:10px;"
            ),
            passwordInput("access_token", "Access token"),
            actionButton("login_btn", "Login", class = "btn-primary", style = "width:100%;"),
            br(), br(),
            tags$small("If you do not have a token, please contact the regional admin.")
          )
        )
      )
    } else {
      sidebarLayout(
        sidebarPanel(
          h4("Display"),
          checkboxInput("dark_mode", "Dark / Night mode", value = TRUE),
          tags$hr(),
          
          h4("Session"),
          tags$b("Role: "), textOutput("logged_role", inline = TRUE), br(),
          tags$b("Country: "), textOutput("logged_country", inline = TRUE),
          tags$hr(),
          
          h4("Template"),
          helpText("Download the empty template, populate it, then upload to update the repository."),
          downloadButton("download_empty_template", "Download EMPTY Excel template"),
          tags$hr(),
          
          h4("Manual entry"),
          helpText("Edit cells directly in the table. Select a row to delete it. Add rows, then append them to the repository."),
          div(
            style = "display:flex; gap:6px; align-items:center; flex-wrap:wrap;",
            actionButton("add_manual_row", "Add empty row"),
            actionButton("delete_manual_row", "Delete row", class = "btn-danger",
                         style = "opacity:0.4; pointer-events:none;")
          ),
          br(),
          actionButton("append_manual_rows", "Append manual rows to repository", class = "btn-primary"),
          
          tags$hr(),
          
          h4("Upload Excel file"),
          fileInput("upload_file", "Upload country admin data (.xlsx)", accept = ".xlsx"),
          actionButton("add_file", "Append uploaded data", class = "btn-success"),
          
          tags$hr(),
          
          h4("Download repository"),
          downloadButton("download_repo_xlsx", "Download Excel"),
          br(), br(),
          downloadButton("download_repo_rds", "Download RDS")
        ),
        
        mainPanel(
          {
            tabs <- list(
              tabPanel(
                "Manual entry",
                div(
                  class = "excel-panel",
                  div(class = "excel-title", "Manual entry grid"),
                  div(class = "excel-subtitle", "Use this like Excel: type directly into the cells."),
                  div(class = "excel-table", DTOutput("manual_table"))
                )
              ),
              tabPanel(
                "Edit Repository",
                div(
                  class = "excel-panel",
                  div(class = "excel-title", "Edit Existing Data"),
                  div(class = "excel-subtitle",
                      "Filter is based on SIA_date (campaign date). Click Apply Filter to execute."),
                  
                  fluidRow(
                    column(3, selectInput(
                      "edit_filter_country", "Country",
                      choices = c("All", sort(unique(admin_repo()$Country)))
                    )),
                    column(3, checkboxInput("edit_use_sia_filter", "Use SIA_date filter", value = FALSE)),
                    column(3, dateInput("edit_filter_sia_from", "SIA Date From",
                                        value = Sys.Date() - 30, format = "yyyy-mm-dd")),
                    column(3, dateInput("edit_filter_sia_to", "SIA Date To",
                                        value = Sys.Date(), format = "yyyy-mm-dd")),
                    column(12, br(),
                           div(style = "display:flex; gap:6px;",
                               actionButton("edit_apply_filter", "Apply Filter", class = "btn-primary btn-sm"),
                               actionButton("edit_clear_filter", "Clear", class = "btn-default btn-sm")
                           ))
                  ),
                  
                  div(class = "excel-table", DTOutput("edit_table")),
                  
                  br(),
                  div(
                    style = "display:flex; gap:6px;",
                    actionButton("edit_save", "Save Changes", class = "btn-success"),
                    actionButton("edit_delete", "Delete Selected", class = "btn-danger"),
                    actionButton("edit_undo", "Undo Last Change", class = "btn-warning"),
                    downloadButton("edit_export_changes", "Export Changes Log")
                  )
                )
              ),
              tabPanel(
                "Repository preview",
                div(
                  class = "excel-panel",
                  div(class = "excel-title", "Current repository"),
                  div(class = "excel-subtitle", "Filtered by your session (country or admin)."),
                  div(class = "excel-table", DTOutput("repo_table"))
                )
              ),
              tabPanel("Template columns", tableOutput("column_info")),
              tabPanel("Manage Duplicates", uiOutput("duplicate_panel"))
            )
            
            if (isTRUE(user_role() == "admin")) {
              tabs <- c(
                tabs,
                list(
                  tabPanel(
                    "Admin – Tokens",
                    div(
                      class = "excel-panel",
                      div(class = "excel-title", "Focal points & tokens"),
                      div(class = "excel-subtitle", "For internal/admin use only – do not share publicly."),
                      div(class = "excel-table", DTOutput("tokens_table"))
                    )
                  )
                )
              )
            }
            
            do.call(tabsetPanel, tabs)
          }
        )
      )
    }
  })
  
  output$logged_country <- renderText({ user_country() })
  output$logged_role <- renderText({ user_role() })
}

shinyApp(ui, server)