# =============================================================
# WHO AFRO Admin Data Portal – Country Focal Point Interface
# WITH WORKING DUPLICATE DETECTION - FIXED VERSION
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

geo_columns <- c("Admin_1","Admin_2","Admin_3","Admin_4",
                 "Country","Region","District","Ward","Village")

# -----------------------------
# DATE + COLUMN NORMALIZATION (EXACTLY from working version)
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
# FAST KEY_ID (EXACTLY from working version)
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
# OTHER HELPERS (EXACTLY from working version)
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

# EXACT find_all_duplicates FROM WORKING VERSION
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
# UI (Simplified but with working duplicate detection)
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
  
  # Theme CSS
  output$theme_css <- renderUI({
    if (isTRUE(input$dark_mode)) {
      tags$style(HTML("
        body { background-color: #181a1f; color: #e5e5e5; }
        .well, .panel, .panel-body, .panel-default { background-color: #252a33 !important; border-color: #3a3f4b !important; color: #e5e5e5 !important; }
        .form-control, .selectize-input, .input-group-addon { background-color: #2b3039; border-color: #3a3f4b; color: #e5e5e5; }
        .excel-panel { background-color: #252a33; border: 1px solid #3a3f4b; border-radius: 6px; padding: 10px; margin-top: 10px; }
        .excel-title { font-weight: 600; color: #ffffff; margin-bottom: 5px; }
        .excel-subtitle { font-size: 0.9em; color: #c0c0c0; margin-bottom: 8px; }
      "))
    } else {
      tags$style(HTML("
        body { background-color: #f4f6f9; color: #222222; }
        .well, .panel, .panel-body, .panel-default { background-color: #ffffff !important; border-color: #d0d7e2 !important; }
        .excel-panel { background-color: #f8fbff; border: 1px solid #c5d5ea; border-radius: 6px; padding: 10px; margin-top: 10px; }
        .excel-title { font-weight: 600; color: #2f5597; margin-bottom: 5px; }
        .excel-subtitle { font-size: 0.9em; color: #555555; margin-bottom: 8px; }
      "))
    }
  })
  
  # -----------------------------
  # Repository load - PRESERVE existing data
  # -----------------------------
  admin_repo <- reactiveVal({
    if (file.exists(repo_rds_path)) {
      # Read existing repository - DON'T modify or recreate
      repo <- readRDS(repo_rds_path)
      
      # Only add ROW_ID and KEY_ID if missing, but preserve all data
      if (!"ROW_ID" %in% names(repo)) {
        repo$ROW_ID <- seq_len(nrow(repo))
      }
      if (!"KEY_ID" %in% names(repo)) {
        repo$KEY_ID <- create_unique_id_dt(repo)
      }
      
      repo
    } else {
      # Only create empty if no repository exists
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
  
  # -----------------------------
  # Download empty template
  # -----------------------------
  output$download_empty_template <- downloadHandler(
    filename = function() paste0("AFRO_admin_data_TEMPLATE_EMPTY_", Sys.Date(), ".xlsx"),
    content = function(file) {
      empty_df <- make_empty_df_from_schema(template_schema, n_rows = 0)
      writexl::write_xlsx(empty_df, path = file)
    }
  )
  
  # -----------------------------
  # Manual entry grid (simplified)
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
    
    datatable(
      df,
      editable = "cell",
      selection = "single",
      options = list(pageLength = 5, scrollX = TRUE)
    )
  }, server = TRUE)
  
  observeEvent(input$manual_table_cell_edit, {
    req(manual_data())
    info <- input$manual_table_cell_edit
    df <- manual_data()
    col_name <- names(df)[info$col]
    
    if (col_name == "SIA_date") {
      df[info$row, info$col] <- parse_sia_date(info$value)
    } else {
      df[info$row, info$col] <- info$value
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
  
  # -----------------------------
  # Repository preview
  # -----------------------------
  output$repo_table <- renderDT({
    req(user_country())
    datatable(
      repo_country(),
      options = list(pageLength = 20, scrollX = TRUE)
    )
  }, server = TRUE)
  
  output$column_info <- renderTable({
    ci <- tibble::tibble(
      column_name = template_schema$column_names,
      column_type = unname(template_schema$column_types[template_schema$column_names])
    )
    ci
  })
  
  output$tokens_table <- renderDT({
    req(isTRUE(user_role() == "admin"))
    datatable(tokens_tbl, options = list(pageLength = 20, scrollX = TRUE))
  }, server = TRUE)
  
  # -----------------------------
  # DUPLICATE DETECTION - This should work exactly like your working version
  # -----------------------------
  output$duplicate_panel <- renderUI({
    req(admin_repo())
    all_duplicates <- find_all_duplicates(admin_repo())
    
    if (nrow(all_duplicates) == 0) {
      return(div(class = "alert alert-success", 
                 style = "border-radius: 4px; padding: 15px;", 
                 "No duplicates found in the repository."))
    }
    
    div(
      class = "excel-panel",
      div(class = "excel-title", "Duplicate Detection"),
      div(
        class = "excel-subtitle",
        paste("Found", nrow(all_duplicates), "records in", length(unique(all_duplicates$duplicate_group)), "duplicate groups")
      ),
      div(class = "excel-table", DTOutput("all_duplicates_table"))
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
      options = list(
        pageLength = 10,
        scrollX = TRUE,
        scrollY = 520
      )
    )
  }, server = TRUE)
  
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
  
  # Edit Repository tab (simplified)
  output$edit_table <- renderDT({
    req(repo_country())
    datatable(
      repo_country(),
      editable = "cell",
      filter = "top",
      options = list(pageLength = 25, scrollX = TRUE, scrollY = 500)
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
          downloadButton("download_empty_template", "Download EMPTY Excel template"),
          tags$hr(),
          h4("Manual entry"),
          actionButton("add_manual_row", "Add empty row"),
          actionButton("delete_manual_row", "Delete row", class = "btn-danger"),
          br(), br(),
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
          tabsetPanel(
            tabPanel("Manual entry", div(class = "excel-panel", DTOutput("manual_table"))),
            tabPanel("Edit Repository", div(class = "excel-panel", DTOutput("edit_table"))),
            tabPanel("Repository preview", div(class = "excel-panel", DTOutput("repo_table"))),
            tabPanel("Template columns", tableOutput("column_info")),
            tabPanel("Manage Duplicates", uiOutput("duplicate_panel")),
            if (isTRUE(user_role() == "admin")) 
              tabPanel("Admin – Tokens", div(class = "excel-panel", DTOutput("tokens_table")))
          )
        )
      )
    }
  })
  
  output$logged_country <- renderText({ user_country() })
  output$logged_role <- renderText({ user_role() })
}

shinyApp(ui, server)