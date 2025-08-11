library(jsonlite)
library(here)
library(tidyverse)

# :: HELPERS -------------------------------------------------------------------

#' Lista arquivos que correspondem a um padrão
#'
#' @param dir Diretório onde buscar os arquivos.
#' @param file Padrão para nome de arquivos.
#' @return Vetor com caminhos completos dos arquivos encontrados.
#' @export
get_files <- \(dir, file) list.files(dir, pattern = file, recursive = TRUE, full.names = TRUE)

#' Lê arquivos CSV e estrutura os dados em tibble
#'
#' @param files Vetor de caminhos de arquivos CSV.
#' @return Tibble com coluna `mes_coleta` e dados concatenados.
#' @export
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

#' Wrapper seguro para `fromJSON`
#'
#' @return Função que retorna lista com resultado ou erro de `fromJSON`.
#' @export
fromJSON_safe <- safely(fromJSON)

# :: FILEPATHS -----------------------------------------------------------------

PATH_DATA_PACKAGE <- here("coleta/data-package/2025")

PATH_CONTRATACOES <- get_files(PATH_DATA_PACKAGE, "contratacoes.csv")
PATH_MEDICAMENTOS <- get_files(PATH_DATA_PACKAGE, "itens-medicamentos.csv")
PATH_MEDICAMENTOS_RESULTADOS <- get_files(PATH_DATA_PACKAGE, "itens-medicamentos-resultados.csv")

OUTPUT_DIR <- tempdir()

ZIP_INPUTS <- list.files(
  here("tasks/mapeamento-ocds/output"),
  pattern = "\\.zip$",
  recursive = TRUE,
  full.names = TRUE
)

ZIP_INPUTS <- ZIP_INPUTS[grep("2025-3old", ZIP_INPUTS, invert = TRUE)]


# :: DADO ORIGINAL -------------------------------------------------------------

contratacoes <- read_files(files = PATH_CONTRATACOES)
medicamentos <- read_files(files = PATH_MEDICAMENTOS)
medicamentos_resultados <- read_files(files = PATH_MEDICAMENTOS_RESULTADOS)


# :: JSONS ---------------------------------------------------------------------

# unzip
JSON_INPUTS <- map(ZIP_INPUTS, unzip, exdir = OUTPUT_DIR)
JSON_INPUTS <- unlist(JSON_INPUTS)


# :: READ DATA -----------------------------------------------------------------

json_parsed <- JSON_INPUTS |>
  map(fromJSON_safe, .progress = TRUE) |>
    set_names(basename(JSON_INPUTS))

jsons <- json_parsed |>
  enframe(name = "id_json") |>
  transmute(
    id_json = id_json,
    result = map(value, pluck, "result"),
    result = map(value, pluck, 1),
    error = map(value, pluck, "error")
  )

json_errors <- jsons |>
  filter(!map_lgl(error, is.null))

jsons <- jsons |>
  anti_join(json_errors) |>
  select(-error) |>
  mutate(result = map(result, enframe)) |>
  unnest(result) |>
  pivot_wider() |>
  unnest(cols = c(uri, publishedDate, version)) |>
  unnest_wider(publisher, names_sep = "_") |>
  mutate(releases = map(releases, as_tibble)) |>
  select(id_json, releases)

#' PROBLEMA 1: =================================================================
#'
#' Descarga de datos: Se encontraron 6 JSONs malformados que no
#' pudieron procesarse: 1, 2, 3, 4, 5, 6. Dado que contienen un campo del tipo {"name": NaN,
#'
#'
#' =============================================================================
#' JSON: go-2-2025.json
#' =============================================================================
#'
#' Falha conversão de unidade de medida `unit:name = NaN`. Campo ausente no dado original PNCP.
#'
#'
#' - linha: 11.444 (tender) e 11.827 (award)
#'
#' "ocid": "ocds-ye9ov3-11324516000108_2024_223"
#' "id": "11324516000108-1-000223/2024"
#'
#' item id: 6
#' Link API: https://pncp.gov.br/api/pncp/v1/orgaos/11324516000108/compras/2024/223/itens/6
#' -----------------------------------------------------------------------------
#'
#'
#' =============================================================================
#' JSON: go-3-2025.json
#' =============================================================================
#'
#' Falha conversão de unidade de medida `unit:name = NaN`. Campo ausente no dado original PNCP.
#'
#' -----------------------------------------------------------------------------
#' - linha: 13.595 (tender) e 11.952 (award)
#'
#' "ocid": "ocds-ye9ov3-3130778000103_2024_25",
#' "id": "03130778000103-1-000025/2024",
#'
#' item id: 6
#' Link API: https://pncp.gov.br/api/pncp/v1/orgaos/03130778000103/compras/2024/25/itens/6
#' -----------------------------------------------------------------------------
#'
#'
#' -----------------------------------------------------------------------------
#' linha: 86.781 (tender) e 86.968 (award)
#'
#' "ocid": "ocds-ye9ov3-10476288000129_2025_36",
#' "id": "10476288000129-1-000036/2025",
#'
#' item id: 10
#' Link API: https://pncp.gov.br/api/pncp/v1/orgaos/03130778000103/compras/2024/25/itens/6
#' -----------------------------------------------------------------------------
#'
#'
#' =============================================================================
#' JSON: go-4-2025.json
#' =============================================================================
#'
#' Falha conversão de unidade de medida `unit:name = NaN`. Campo ausente no dado original PNCP.
#'
#' -----------------------------------------------------------------------------
#' - linha: a partir de 16.850 até 16.973 (tender)
#'
#' "ocid": "ocds-ye9ov3-24810277000148_2025_26",
#' "id": "24810277000148-1-000026/2025",
#'
#' item id: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
#' Link API: https://pncp.gov.br/api/pncp/v1/orgaos/24810277000148/compras/2025/26/itens
#' -----------------------------------------------------------------------------
#'
#'
#' -----------------------------------------------------------------------------
#' - linha: a partir de 36.399 até 36.516 (tender) e 36.682 até 36.979 (awards)
#'
#' "ocid": "ocds-ye9ov3-24810277000148_2025_28",
#' "id": "24810277000148-1-000028/2025",
#'
#' item id: 1, 2, 3, 4, 5, 6, 7, 10
#' Link API: https://pncp.gov.br/api/pncp/v1/orgaos/24810277000148/compras/2025/28/itens
#' -----------------------------------------------------------------------------
#'
#'
#' =============================================================================
#' JSON: go-6-2025.json
#' =============================================================================
#'
#' Falha conversão de unidade de medida `unit:name = NaN`. Campo ausente no dado original PNCP.
#'
#' -----------------------------------------------------------------------------
#' - linha: 33.123 (tender) e 33.428 (award)
#'
#' "ocid": "ocds-ye9ov3-10476288000129_2025_188",
#' "id": "10476288000129-1-000188/2025",
#'
#' item id: 6
#' Link API: https://pncp.gov.br/api/pncp/v1/orgaos/10476288000129/compras/2025/188/itens/7
#' -----------------------------------------------------------------------------
#'
#'
#' =============================================================================
#' JSON: pi-3-2025.json
#' =============================================================================
#'
#' Falha conversão de unidade de medida `unit:name = NaN`. Campo ausente no dado original PNCP.
#'
#' -----------------------------------------------------------------------------
#' - linha: 21.384 (tender)
#'
#' "ocid": "ocds-ye9ov3-1612591000110_2025_14",
#' "id": "01612591000110-1-000014/2025",
#'
#' item id: 6
#' Link API: https://pncp.gov.br/api/pncp/v1/orgaos/01612591000110/compras/2025/14/itens/9
#' -----------------------------------------------------------------------------
#'
#'
#' =============================================================================
#' JSON: sp-2-2025-3.json
#' =============================================================================
#'
#' Falha conversão de unidade de medida `unit:name = NaN`. Campo ausente no dado original PNCP.
#'
#' -----------------------------------------------------------------------------
#' - linha: 5.485 (tender)
#'
#' "ocid": "ocds-ye9ov3-46578498000175_2025_50",
#' "id": "46578498000175-1-000050/2025",
#'
#' item id: 3
#' Link API: https://pncp.gov.br/api/pncp/v1/orgaos/46578498000175/compras/2025/50/itens/3
#' -----------------------------------------------------------------------------
#'
#'
#' FIM PROBLEMA 1 ==============================================================


#' PROBLEMA 2: =================================================================
#'
#'  ## Campo obrigatório `release.date` está ausente
#'
#' Los ocids ocds-ye9ov3-444232000139_2025_56, ocds-ye9ov3-4380507000179_2025_34,
#'  ocds-ye9ov3-18682930000138_2025_11 y ocds-ye9ov3-11360884000101_2025_5
#'  no tienen el campo obligatorio release.date
#'
# "ocds-ye9ov3-444232000139_2025_56" | 2 Fevereiro | mg-2-2025.json | "00444232000139-1-000056/2025"
# "ocds-ye9ov3-4380507000179_2025_34" | 2 Fevereiro | ro-2-2025.json |  "4380507000179-1-000034/2025"
# "ocds-ye9ov3-18682930000138_2025_11" | 2 Fevereiro | mg-2-2025.json |  "18682930000138-1-000011/2025"
# "ocds-ye9ov3-11360884000101_2025_5" | 2 Fevereiro | pe-2-2025.json | "11360884000101-1-000005/2025"
#'
#' Houve um problema na extração de dados de fevereiro: a API do PNCP incluiu campos e nos pegou de surpresa, desbalanceando o mapeamento de colunas de nosso coletor automatizado. Os dados desbalanceados não foram incluídos no banco de dados e, portanto, não afetamn a plataforma. Entretanto essa exclusão não foi realizada na geração dos Jsons OCDS. Como solução foi implementada a exclusão desses dados desbalanceados e os Jsons serão substituídos com dados corretos.
#'
#' FIM PROBLEMA 2 ==============================================================


#' PROBLEMA 3: =================================================================
#'
#' Algunos procesos tienen ids duplicados en tender.items, tender.lots y parties,
#' ejemplos ocds-ye9ov3-96291141000180_2025_2025, ocds-ye9ov3-10414835000141_2024_54,
#'  ocds-ye9ov3-10414835000141_2024_54.
#' Lista completa de errores:
# https://docs.google.com/spreadsheets/d/1ln8qD4TtGpV_07CzXeOcma-w6nKv1ynixTkCmL4eiKU
#'
gsheet <- "1ln8qD4TtGpV_07CzXeOcma-w6nKv1ynixTkCmL4eiKU"
errors_p3 <- googlesheets4::read_sheet(gsheet, col_types = "c")

errors_p3 |>
  # filter(error_type == "uniqueItems") |>
  count(error_type, field)

unique_itens <- errors_p3 |>
  filter(error_type == "uniqueItems") |>
  distinct(ocid, field)

jsons_itens <- jsons |>
  unnest_wider(releases, names_sep = "_") |>
  select(id_json, ocid = releases_ocid, id_pncp = releases_id, releases_tender) |>
  unnest(cols = c(ocid, id_pncp, releases_tender), names_sep = "_", keep_empty = TRUE) |>
  select(id_json, ocid, id_pncp, releases_tender_id, releases_tender_items) |>
  unnest(releases_tender_items, names_sep = "_") |>
  unnest(releases_tender_items_unit, names_sep = "_") |>
  unnest(releases_tender_items_unit_value, names_sep = "_")

jsons_itens |>
  filter(id_pncp == "46374500000194-1-002024/2024") |>
  count(id_json, ocid, id_pncp, releases_tender_items_id, sort = TRUE) |>
  filter(n > 1)

jsons_itens |>
  filter(id_pncp == "46374500000194-1-002024/2024") |>
  filter(releases_tender_items_id == 1)

non_unique_id_values |>
  filter(ocid == "ocds-ye9ov3-10414835000141_2024_54") |>
  googlesheets4::write_sheet(gsheet, sheet = "ocds-ye9ov3-10414835000141_2024_54")

contratacoes |>
  filter(data.numeroControlePNCP == "46374500000194-1-002024/2024") |>
  glimpse()

medicamentos_resultados |>
  filter(numeroControlePNCPCompra == "46374500000194-1-002024/2024")

medicamentos |>
  filter(endpoint == "https://pncp.gov.br/api/pncp/v1/orgaos/46374500000194/compras/2024/2024/itens")


"releases/date"
jsons_date <- jsons |>
  unnest_wider(releases, names_sep = "_") |>
  select(id_json, ocid = releases_ocid, id_pncp = releases_id, releases_date) |>
  unnest(cols = c(ocid, id_pncp, releases_date))

releases_sem_data <- jsons_date |>
  filter(is.na(releases_date))

releases_sem_data |>
  filter(ocid == "ocds-ye9ov3-10626896000172_2023_235")

jsons_date |>
  filter(!is.na(releases_date)) |>
  mutate(releases_date = as_datetime(releases_date)) |>
  filter(min(releases_date) < 2022 | year(releases_date) > 2025)

contratacoes |>
  filter(data.numeroControlePNCP %in% unique(releases_sem_data$id_pncp))


contratacoes |>
  filter(data.numeroControlePNCP == "10825373000155-1-000014/2023") |>
  glimpse()

source(here("src/ETL/loaders/utils.R"))

ids_pncp <- paste(unique(releases_sem_data$id_pncp), collapse = "', '")
qry <- str_glue("select * from contratacao where numero_controle_pncp in ('{ids_pncp}')")
qry <- str_glue("select * from contratacao where numero_controle_pncp in ('10825373000155-1-000014/2023')")
sem_datas_no_bd <- get_query(qry, conectar = FALSE)
sem_datas_no_bd
get_query(qry, conectar = FALSE) |> glimpse()
#' FIM PROBLEMA 3 ==============================================================