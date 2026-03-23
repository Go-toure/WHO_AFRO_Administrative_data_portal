

#Create a list of focal points and countries
focal_points <- tibble::tibble(
  country      = c("Senegal", "Mali", "Nigeria"),
  focal_point  = c("Name SEN", "Name MLI", "Name NGA"),
  email        = c("sen.fp@who.int", "mli.fp@who.int", "nga.fp@who.int")
)

#function to generate tokens:
generate_token <- function(country, year = format(Sys.Date(), "%Y"), len = 6) {
  # prefix = 3-letter country code
  prefix <- toupper(substr(country, 1, 3))
  
  # random part (len chars)
  chars <- c(LETTERS, 0:9)
  rand_part <- paste0(sample(chars, len, replace = TRUE), collapse = "")
  
  paste0(prefix, "-", year, "-", rand_part)
}

# one token per focal point
set.seed(2025)  # so you can reproduce if needed

tokens_tbl <- focal_points %>%
  dplyr::mutate(
    token = generate_token(country)
  )

tokens_tbl

##########################################################""
# Tokens funtion
##########################################################

library(tibble)
library(dplyr)
library(readr)

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
  "Cameroon",                       "Lele parfait",                            "lelec@who.int",
  "Cameroon",                       "RAKOTOARIVOLOLONA, Tania",                "rakotoarivololonat@who.int",
  "Central African Republic",       "M. OUEDRAOGO Salfo",                      "ouedsalfo@gmail.com",
  "Central African Republic",       "MBARY DABA Régis",                        "mbarydabar@who.int",
  "Chad",                           "Mr NGADJADOUM Emmanuel",                  "ngadjadoummb@who.int",
  "Chad",                           "CHOUANGMO WABO Yannick Franck",           "chouangmoy@who.int",
  "Cod'vore (CIV)",                 "KOUADIO, Sie Kabran",                     "kouadios@who.int",
  "Cod'vore (CIV)",                 "Bohoussou, Philibert Kouakou",            "bohoussoup@who.int",
  "Democratic Republic of the Congo","NSEYA MUTOMBO, Claudine",                "nseyac@who.int",
  "Democratic Republic of the Congo","Albert Mbule",                            "mbulea@who.int",
  "Eritrea",                        "GEBRESLASSIE ASFEHA, Azmera",             "gebreslassiea@who.int",
  "Eritrea",                        "EJIOFOR EPHRAIM, Nonso Ejiofor",          "ejioforn@who.int",
  "Eswatini",                       "DLAMINI, Makhoselive",                    "dlaminim@who.int",
  "Eswatini",                       "Nqaba NHLEBELA",                          "nqaba.nhle@gmail.com",
  "Ethiopia",                       "Mr. Fasil Teshager",                      "teshagerf@who.int",
  "Ethiopia",                       "Zewde Dinku",                             "dinkuz@who.int",
  "Ethiopia",                       "AYANA, Wondimu",                          "ayanaw@who.int",
  "Gabon",                          "AMALET Brice",                            "amaletb@who.int",
  "Gabon",                          "OBIANG MBA Régis Maurin",                 "obiang@who.int",
  "Gabon",                          "BARRO MOUSSAVOU, Lloyd Eric",             "barrol@who.int",
  "Gambia",                         "Mustapha Sanyang",                        "sanyangm@who.int",
  "Ghana",                          "TAMAL, Christopher",                      "tamalc@who.int",
  "Ghana",                          "ADJEI, Michael Rockson",                  "adjeim@who.int",
  "Guinea",                         "Sylla Mohamed",                           "mosylla@who.int",
  "Guinea",                         "Sekou SOLANO",                            "solanos@who.int",
  "Guinea",                         "Ettienne kouame KOUADJO",                 "ettienne9@hotmail.com",
  "Guinea",                         "ADAMA KOTE",                              "adama.kote@yahoo.fr",
  "Guinea Bissau (GNB)",            "Mamadou DIAW",                            "diawm2000@yahoo.fr",
  "Kenya",                          "MAINA, Stephen Karuru",                   "mainas@who.int",
  "Kenya",                          "MUITHERERO, Charles Mbugua",              "muithereroc@who.int",
  "Kenya",                          "Magige James",                            "jamesmagige24@gmail.com",
  "Lesotho",                        "Maepe SELLEANO",                          "maepes@who.int",
  "Liberia",                        "Roland N. O. Tuopileyi, II",              "tuopileyiiir@who.int",
  "Liberia",                        "SESAY, Jeremy S.",                        "sesayj@who.int",
  "Malawi",                         "GALANDI, Albert Mandala",                 "galandia@who.int",
  "Malawi",                         "Gareth Nyirenda",                         "nyirendag@who.int",
  "Mali",                           "YAYA COULIBALY",                          "coulibalyy@who.int",
  "Mali",                           "ALOU DEMBELE",                            "adembele@who.int",
  "Mali",                           "SOULEYMANE TRAORE",                       "stleyhm8@yahoo.fr",
  "Mali",                           "Drissa SANOGO",                           "sanogod@who.int",
  "Mali",                           "Moussa Coulibaly",                        "coulibalymo@who.int",
  "Mali",                           "Dolo Mathias",                            "doloa@who.int",
  "Mali",                           "Drissa SANOGO",                           "sanogod@who.int",
  "Mozambique",                     "Antonio Alfredo Nhambombe",               "anhambombe@hotmail.com",
  "Mozambique",                     "ODALLAH, Anita Aunda Pedro",              "odallaha@who.int",
  "Namibia",                        "NASHIPILI, Japhet",                       "nashipilij@who.int",
  "Niger",                          "HALADOU, Moussa",                         "haladoum@who.int",
  "Niger",                          "TOMBOKOYE, Harouna",                      "tombokoyeh@who.int",
  "Niger",                          "Hamadou Moussa Seyni",                    "hmoussa852@gmail.com",
  "Niger",                          "HAMADOU MOUSSA Seyni",                    "hamadous@who.int",
  "Niger",                          "SAWADOGO Roger",                          "sawadogor@who.int",
  "Niger",                          "TOLNO Faya Kitio",                        "tolnof@who.int",
  "Nigeria",                        "GERLONG, Yohanna George",                 "gerlongg@who.int",
  "Nigeria",                        "SOLOMON, Jason Praise",                   "solomonj@who.int",
  "Nigeria",                        "CHUKWUJI, Martin",                        "chukwujim@who.int",
  "Nigeria",                        "Ahmed Ibrahim",                           "ibrahimah@who.int",
  "Nigeria",                        "Davies Adedamola",                        "daviesa@who.int",
  "Nigeria",                        "MAMUDU, Aishatu Laminde",                 "mamudua@who.int",
  "Nigeria",                        "DEMPOUO NGUELEFACK EP DJOMASS",           "dempouol@who.int",
  "Republic of Congo",              "Da DOMANFOULE",                           "da_domanfoul@yahoo.com",
  "Republic of Congo",              "ELENGA GARBA, Serge Francis",             "elengaf@who.int",
  "Republic of Congo",              "KABORE, Salifou",                         "kaboresa@who.int",
  "Rwanda",                         "DUSHIMIMANA JEAN DE DIEU",                "dushimimanaj@who.int",
  "Senegal",                        "Daba NDOUR",                              "dabandour@yahoo.fr",
  "Senegal",                        "Dr Alassane Ndiaye",                      "ndiayea@who.int",
  "Seychelles",                     "Edwin OGANDI",                            "ogendie@who.int",
  "Sierra Leone",                   "Linda Samuels",                           "samuelsl@who.int",
  "Sierra Leone",                   "SESAY, Abdul Regis Stephen",              "sesays@who.int",
  "South Africa",                   "BUTHELEZI, Thulasizwe John",              "buthelezit@who.int",
  "South Sudan",                    "David Taban KILO OCHAN",                  "ochant@who.int",
  "Tanzania",                       "Naimi Mbogo",                             "nmmazzuki@gmail.com",
  "The Gambia",                     "Mustapha Sanyang",                        "mustapha.sanyang88@gmail.com",
  "Togo",                           "Ouattara Massanguié",                     "massanguie@yahoo.fr",
  "Togo",                           "Dzidzino Richard",                        "dzidzinyok@who.int",
  "Uganda",                         "Samuel Ofori",                            "soforigyasi1@gmail.com",
  "Uganda",                         "Emmanuel TENYWA",                         "tenywaem@who.int",
  "Zimbabwe",                       "Trevor Muchabaiwa",                       "muchabaiwat@who.int",
  "Zimbabwe",                       "Batanai Moyo",                            "moyob@who.int",
  "Zimbzbwe",                       "MASVIKENI, Brine",                        "masvikenib@who.int"
)

# -----------------------------
# 2. Token generator
# -----------------------------
generate_token <- function(country, year = format(Sys.Date(), "%Y"), len = 6) {
  # prefix = first 3 letters (uppercased, no spaces)
  prefix <- toupper(gsub("\\s+", "", substr(country, 1, 3)))
  
  chars <- c(LETTERS, 0:9)
  rand_part <- paste0(sample(chars, len, replace = TRUE), collapse = "")
  
  paste0(prefix, "-", year, "-", rand_part)
}

set.seed(2025)  # for reproducibility

tokens_tbl <- focal_points %>%
  mutate(token = generate_token(country))

tokens_tbl




