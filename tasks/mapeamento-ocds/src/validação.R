library(jsonlite)
library(here)
library(tidyverse)

# :: HELPERS -------------------------------------------------------------------

get_files <- \(dir, file) list.files(dir, pattern = file, recursive = TRUE, full.names = TRUE)

read_files <- \(files) {
  tibble(path = files) |>
    transmute(
      mes_coleta = path |>
        str_remove("^.+2025\\/") |>
        str_remove("\\/Q.+$"),
      data = map(path, read_csv, col_types = cols(.default = col_character()))
    ) |>
    unnest(data)
}


# :: DADO ORIGINAL -------------------------------------------------------------

PATH_DATA_PACKAGE <- here("coleta/data-package/2025")

PATH_CONTRATACOES <- get_files(PATH_DATA_PACKAGE, "contratacoes\\.csv")
PATH_MEDICAMENTOS <- get_files(PATH_DATA_PACKAGE, "itens-medicamentos.csv")
PATH_MEDICAMENTOS_RESULTADOS <- get_files(PATH_DATA_PACKAGE, "itens-medicamentos-resultados.csv")

contratacoes <- read_files(files = PATH_CONTRATACOES)
medicamentos <- read_files(files = PATH_MEDICAMENTOS)
medicamentos_resultados <- read_files(files = PATH_MEDICAMENTOS_RESULTADOS)

# :: JSONS ---------------------------------------------------------------------

OUTPUT_DIR <- tempdir()

ZIP_INPUTS <- here("tasks/mapeamento-ocds/output") |>
  list.files(pattern = "\\.zip$", recursive = TRUE, full.names = TRUE)

walk(ZIP_INPUTS, unzip, exdir = OUTPUT_DIR)

JSON_INPUTS <- list.files(OUTPUT_DIR, pattern = "\\.json", full.names = TRUE)
JSON_IDS <- list.files(OUTPUT_DIR, pattern = "\\.json")

## Descarga de datos: Se encontraron 6 JSONs malformados que no pudieron procesarse: 1, 2, 3, 4, 5, 6. Dado que contienen un campo del tipo {"name": NaN,

# read and register errors
fromJSON_safe <- safely(fromJSON)

json_parsed <- JSON_INPUTS |>
  map(fromJSON_safe) |>
  set_names(JSON_IDS)

tst <- json_parsed |>
  enframe(name = "id") |>
  transmute(
    id = id,
    result = map(value, pluck, "result"),
    result = map(value, pluck, 1),
    error = map(value, pluck, "error")
  )

tst |>
  filter(!map_lgl(error, is.null))

contratacoes |>
  filter(data.numeroControlePNCP == "11324516000108-1-000223/2024") |>
  glimpse()

medicamentos |>
  filter(endpoint == "https://pncp.gov.br/api/pncp/v1/orgaos/11324516000108/compras/2024/223/itens") |>
  filter(numeroItem == "6") |>
  glimpse()


# ==============================================================================
# JSON: go-2-2025.json
# ==============================================================================
#
# Falha conversão de unidade de medida `unit:name = NaN`. Campo ausente no dado original PNCP.
#
# ------------------------------------------------------------------------------
# - linha: 11.444 (tender) e 11.827 (award)
#
# "ocid": "ocds-ye9ov3-11324516000108_2024_223"
# "id": "11324516000108-1-000223/2024"
#
# item id: 6
# Link API: https://pncp.gov.br/api/pncp/v1/orgaos/11324516000108/compras/2024/223/itens/6
# ------------------------------------------------------------------------------


# ==============================================================================
# JSON: go-3-2025.json
# ==============================================================================
#
# Falha conversão de unidade de medida `unit:name = NaN`. Campo ausente no dado original PNCP.
#
# ------------------------------------------------------------------------------
# - linha: 13.595 (tender) e 11.952 (award)
#
# "ocid": "ocds-ye9ov3-3130778000103_2024_25",
# "id": "03130778000103-1-000025/2024",
#
# item id: 6
# Link API: https://pncp.gov.br/api/pncp/v1/orgaos/03130778000103/compras/2024/25/itens/6
# ------------------------------------------------------------------------------
#
# ------------------------------------------------------------------------------
# linha: 86.781 (tender) e 86.968 (award)
#
# "ocid": "ocds-ye9ov3-10476288000129_2025_36",
# "id": "10476288000129-1-000036/2025",
#
# item id: 10
# Link API: https://pncp.gov.br/api/pncp/v1/orgaos/03130778000103/compras/2024/25/itens/6
# ------------------------------------------------------------------------------


# ==============================================================================
# JSON: go-4-2025.json
# ==============================================================================
#
# Falha conversão de unidade de medida `unit:name = NaN`. Campo ausente no dado original PNCP.
#
# ------------------------------------------------------------------------------
# - linha: a partir de 16.850 até 16.973 (tender)
#
# "ocid": "ocds-ye9ov3-24810277000148_2025_26",
# "id": "24810277000148-1-000026/2025",
#
# item id: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
# Link API: https://pncp.gov.br/api/pncp/v1/orgaos/24810277000148/compras/2025/26/itens
# ------------------------------------------------------------------------------
#
# ------------------------------------------------------------------------------
# - linha: a partir de 36.399 até 36.516 (tender) e 36.682 até 36.979 (awards)
#
# "ocid": "ocds-ye9ov3-24810277000148_2025_28",
# "id": "24810277000148-1-000028/2025",
#
# item id: 1, 2, 3, 4, 5, 6, 7, 10
# Link API: https://pncp.gov.br/api/pncp/v1/orgaos/24810277000148/compras/2025/28/itens
# ------------------------------------------------------------------------------


# ==============================================================================
# JSON: go-6-2025.json
# ==============================================================================
#
# Falha conversão de unidade de medida `unit:name = NaN`. Campo ausente no dado original PNCP.
#
# ------------------------------------------------------------------------------
# - linha: 33.123 (tender) e 33.428 (award)
#
# "ocid": "ocds-ye9ov3-10476288000129_2025_188",
# "id": "10476288000129-1-000188/2025",
#
# item id: 6
# Link API: https://pncp.gov.br/api/pncp/v1/orgaos/10476288000129/compras/2025/188/itens/7
# ------------------------------------------------------------------------------


# ==============================================================================
# JSON: pi-3-2025.json
# ==============================================================================
#
# Falha conversão de unidade de medida `unit:name = NaN`. Campo ausente no dado original PNCP.
#
# ------------------------------------------------------------------------------
# - linha: 21.384 (tender)
#
# "ocid": "ocds-ye9ov3-1612591000110_2025_14",
# "id": "01612591000110-1-000014/2025",
#
# item id: 6
# Link API: https://pncp.gov.br/api/pncp/v1/orgaos/01612591000110/compras/2025/14/itens/9
# ------------------------------------------------------------------------------


# ==============================================================================
# JSON: sp-2-2025-3.json
# ==============================================================================
#
# Falha conversão de unidade de medida `unit:name = NaN`. Campo ausente no dado original PNCP.
#
# ------------------------------------------------------------------------------
# - linha: 5.485 (tender)
#
# "ocid": "ocds-ye9ov3-46578498000175_2025_50",
# "id": "46578498000175-1-000050/2025",
#
# item id: 3
# Link API: https://pncp.gov.br/api/pncp/v1/orgaos/46578498000175/compras/2025/50/itens/3
# ------------------------------------------------------------------------------


glimpse(json_parsed[1])


full_data <- JSON_INPUTS[1:3] %>%
  map(fromJSON) %>%
  map(enframe) %>%
  map_df(pivot_wider) %>%
  unnest(cols = c(uri, publishedDate, version, extensions)) %>%
  unnest_wider(publisher, names_sep = "_") %>%
  mutate(releases = map(releases, as_tibble))

full_data %>%
  unnest_wider(releases, names_sep = "_") %>%
  unnest(cols = c(
    releases_ocid, releases_id, releases_date, releases_tag,
    releases_initiationType, releases_language, releases_parties,
    releases_awards
  )) %>%
  unnest(releases_tag) %>%
  unnest_wider(releases_buyer, names_sep = "_") %>%
  unnest(c(releases_buyer_id, releases_buyer_name)) %>%
  unnest_wider(releases_parties, names_sep = "_") %>%
  glimpse()
