library(tidyverse)
library(here)
options(width = 150)


# :: FILEPATHS e SETUP ---------------------------------------------------------

# Dados de entradas ficam em /tmp
TMP_PATH <- "tasks/indicadores-MEL/tmp"

# ´Se /tmp estiver vazia ou desatualizada, set TRUE e rode o IF a seguir
RECARREGAR_DADOS_EM_TMP <- FALSE

if (RECARREGAR_DADOS_EM_TMP) {
  DOWNLOAD_DATA_PATH <- here("tasks/indicadores-MEL/src/R/00-download-data.R")
  source(DOWNLOAD_DATA_PATH, encoding = "UTF-8")
}

# Dados de saída ficam em /output
LOCAL_PATH <- "tasks/unifica-dados/output"

# Funções auxiliares
UTILS <- here("tasks/indicadores-MEL/src/R/utils.R")
source(UTILS, encoding = "UTF-8")


# :: DATA PATHS ----------------------------------------------------------------

DATA_PATHS <- TMP_PATH |>
  list.files(recursive = TRUE, full.names = TRUE) |>
  as_tibble_col("path") |>
  mutate(tipo = case_when(
    str_detect(path, "itens-medicamentos.csv") ~ "medicamentos",
    str_detect(path, "medicamentos.csv") ~ "medicamentos",
    str_detect(path, "contratacoes.csv") ~ "contratacoes",
    str_detect(path, "itens-medicamentos-resultados.csv") ~ "resultados-medicamentos",
    str_detect(path, "itens-resultados-medicamentos.csv") ~ "resultados-medicamentos",
    str_detect(path, "itens-medicamentos-resultados-recoleta.csv") ~ "resultados-medicamentos",
    str_detect(path, "itens-resultados.csv") ~ "resultados-itens",
    str_detect(path, "itens.csv") ~ "itens",
    TRUE ~ "outros"
  ))


# :: CHECK COLUNAS -------------------------------------------------------------

# As colunas serão checadas manualmente e o resultado será enviado para uma planilha no drive para facilitar a visualização. O objetivo é identificar colunas que estão presentes em algumas coletas mas não em outras, o que pode indicar mudanças na estrutura dos dados ao longo do tempo.
"https://docs.google.com/spreadsheets/d/15sBw_fmOHTq8co2NDME9hfO7EU4Xblieh9H5Fu4JOJo"

# id plan check
ID_PLAN_CHECK <- "15sBw_fmOHTq8co2NDME9hfO7EU4Xblieh9H5Fu4JOJo"


# CONTRATAÇÕES ---
col_contratacoes <- DATA_PATHS |>
  filter(tipo == "contratacoes") |>
  mutate(
    colnames = map(path, get_colnames),
    data_coleta = make_anomes_coleta(path) |>
      replace_na(ym("2024-12")),
    id_coleta = str_extract(path, "QUINZENA-[12]") |>
      str_remove("UINZENA-") |>
      replace_na("1ª COLETA") |>
      str_c(format(data_coleta, "%b/%y"), sep = "/"),
    data_coleta = if_else(str_detect(id_coleta, "^Q2"), data_coleta + days(15), data_coleta)
  )


col_contratacoes |>
  mutate(n_cols = map_int(colnames, length), flag = "X") |>
  unnest(colnames) |>
  pivot_wider(names_from = colnames, values_from = flag, values_fill = "-") |>
  mutate(id_coleta = fct_reorder(id_coleta, data_coleta)) |>
  arrange(id_coleta) |>
  googlesheets4::write_sheet(ss = ID_PLAN_CHECK, sheet = "contratacoes-wide")

col_contratacoes |>
  unnest(colnames) |>
  transmute(
    colnames,
    id_coleta = fct_reorder(id_coleta, data_coleta),
    flag = "X"
  ) |>
  arrange(id_coleta) |>
  pivot_wider(names_from = id_coleta, values_from = flag, values_fill = "-") |>
  googlesheets4::write_sheet(ss = ID_PLAN_CHECK, sheet = "contratacoes-long")


# ITENS ---
col_itens <- DATA_PATHS |>
  filter(tipo == "itens") |>
  mutate(
    colnames = map(path, get_colnames),
    data_coleta = make_anomes_coleta(path) |>
      replace_na(ym("2024-12")),
    id_coleta = str_extract(path, "QUINZENA-[12]") |>
      str_remove("UINZENA-") |>
      replace_na("1ª COLETA") |>
      str_c(format(data_coleta, "%b/%y"), sep = "/"),
    data_coleta = if_else(str_detect(id_coleta, "^Q2"), data_coleta + days(15), data_coleta)
  )

col_itens |>
  mutate(n_cols = map_int(colnames, length), flag = "X") |>
  unnest(colnames) |>
  pivot_wider(names_from = colnames, values_from = flag, values_fill = "-") |>
  mutate(id_coleta = fct_reorder(id_coleta, data_coleta)) |>
  arrange(id_coleta) |>
  googlesheets4::write_sheet(ss = ID_PLAN_CHECK, sheet = "itens-wide")

col_itens |>
  unnest(colnames) |>
  transmute(
    colnames,
    id_coleta = fct_reorder(id_coleta, data_coleta),
    flag = "X"
  ) |>
  arrange(id_coleta) |>
  pivot_wider(names_from = id_coleta, values_from = flag, values_fill = "-") |>
  googlesheets4::write_sheet(ss = ID_PLAN_CHECK, sheet = "itens-long")


# RESULTADOS ---
col_resultados <- DATA_PATHS |>
  filter(tipo == "resultados-medicamentos") |>
  mutate(
    colnames = map(path, get_colnames),
    data_coleta = make_anomes_coleta(path) |>
      replace_na(ym("2024-12")),
    id_coleta = str_extract(path, "QUINZENA-[12]") |>
      str_remove("UINZENA-") |>
      replace_na("1ª COLETA") |>
      str_c(format(data_coleta, "%b/%y"), sep = "/"),
    data_coleta = if_else(str_detect(id_coleta, "^Q2"), data_coleta + days(15), data_coleta)
  )

col_resultados |>
  mutate(n_cols = map_int(colnames, length), flag = "X") |>
  unnest(colnames) |>
  pivot_wider(names_from = colnames, values_from = flag, values_fill = "-") |>
  mutate(id_coleta = fct_reorder(id_coleta, data_coleta)) |>
  arrange(id_coleta) |>
  googlesheets4::write_sheet(ss = ID_PLAN_CHECK, sheet = "resultados-wide")

col_resultados |>
  unnest(colnames) |>
  transmute(
    colnames,
    id_coleta = fct_reorder(id_coleta, data_coleta),
    flag = "X"
  ) |>
  arrange(id_coleta) |>
  distinct() |>
  pivot_wider(names_from = id_coleta, values_from = flag) |>
  googlesheets4::write_sheet(ss = ID_PLAN_CHECK, sheet = "resultados-long")


# :: LOAD DATA -----------------------------------------------------------------

medicamentos <- TMP_PATH |>
  list.files(recursive = TRUE, full.names = TRUE, pattern = "medicamentos.csv") |>
  as_tibble_col("path") |>
  filter(!str_detect(path, "I-II-III")) |>
  mutate(
    dados = map(path, read_csv, col_types = cols(.default = "c")),
    colnames = map(dados, colnames),
    anomes_coleta = make_anomes_coleta(path)
  ) |>
  unnest(dados) |>
  mutate(data.numeroControlePNCP = make_id(endpoint))

contratacoes <- TMP_PATH |>
  list.files(recursive = TRUE, full.names = TRUE, pattern = "contratacoes.csv") |>
  here() |>
  as_tibble_col("path") |>
  filter(!str_detect(path, "I-II-III")) |>
   mutate(
    dados = map(path, read_csv, col_types = cols(.default = "c")),
    colnames = map(dados, colnames),
    anomes_coleta = make_anomes_coleta(path)
  ) |>
  unnest(dados)

resultados <- TMP_PATH |>
  list.files(recursive = TRUE, full.names = TRUE, pattern = "itens-medicamentos-resultados.csv") |>
  here() |>
  as_tibble_col("path") |>
  filter(!str_detect(path, "I-II-III")) |>
   mutate(
    dados = map(path, read_csv, col_types = cols(.default = "c")),
    colnames = map(dados, colnames),
    anomes_coleta = make_anomes_coleta(path)
  ) |>
  unnest(dados)

itens <- TMP_PATH |>
  list.files(recursive = TRUE, full.names = TRUE, pattern = "itens.csv") |>
  here() |>
  as_tibble_col("path") |>
  filter(!str_detect(path, "I-II-III")) |>
   mutate(
    dados = map(path, read_csv, col_types = cols(.default = "c")),
    colnames = map(dados, colnames),
    anomes_coleta = make_anomes_coleta(path)
  ) |>
  unnest(dados)


# :: CHECK COLUNAS -------------------------------------------------------------

# As colunas serão checadas manualmente e o resultado será enviado para uma planilha no drive para facilitar a visualização. O objetivo é identificar colunas que estão presentes em algumas coletas mas não em outras, o que pode indicar mudanças na estrutura dos dados ao longo do tempo.
"https://docs.google.com/spreadsheets/d/15sBw_fmOHTq8co2NDME9hfO7EU4Xblieh9H5Fu4JOJo"

# id plan check
ID_PLAN_CHECK <- "15sBw_fmOHTq8co2NDME9hfO7EU4Xblieh9H5Fu4JOJo"


col_itens <- itens |>
  distinct(path) |>
   mutate(
    dados = map(path, get_colnames),
    anomes_coleta = make_anomes_coleta(path)
  )

medicamentos |>
  distinct(path, anomes_coleta, colnames) |>
  mutate(
    colnames = map(colnames, sort),
    flag = "X"
  ) |>
  unnest(colnames) |>
  pivot_wider(names_from = colnames, values_from = flag, values_fill = "-") |>
  googlesheets4::write_sheet(ss = PLAN_CHECK)

ids_validos <- medicamentos |>
  distinct(data.numeroControlePNCP)

contratacoes <- inner_join(contratacoes, ids_validos)

saveRDS(medicamentos, file = here("tasks/indicadores-MEL/inputs/medicamentos.rds"))
saveRDS(contratacoes, file = here("tasks/indicadores-MEL/inputs/contratacoes.rds"))
saveRDS(resultados, file = here("tasks/indicadores-MEL/inputs/resultados.rds"))
