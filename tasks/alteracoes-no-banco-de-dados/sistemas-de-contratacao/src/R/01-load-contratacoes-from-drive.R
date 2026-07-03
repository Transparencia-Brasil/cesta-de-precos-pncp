library(tidyverse)
library(here)


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


# :: LOAD CONTRATACOES ---------------------------------------------------------

contratacoes_drive <- TMP_PATH |>
  list.files(recursive = TRUE, full.names = TRUE, pattern = "contratacoes.csv") |>
  here() |>
  as_tibble_col("path") |>
  # filter(!str_detect(path, "I-II-III")) |>
   mutate(
    dados = map(path, read_csv, col_types = cols(.default = "c")),
    colnames = map(dados, colnames),
    anomes_coleta = make_anomes_coleta(path)
  ) |>
  unnest(dados)

contratacoes_drive |>
filter(is.na(data.usuarioNome)) |>
glimpse()

contratacoes_drive <- contratacoes_drive |>
  distinct(
    numero_controle_pncp = data.numeroControlePNCP,
    usuario_nome = data.usuarioNome
  )


# :: OUTPUTS -------------------------------------------------------------------

PATH_CONTRATACOES_DRIVE <- here("tasks/alteracoes-no-banco-de-dados/sistemas-de-contratacao/inputs/contratacoes-drive.rds")
saveRDS(contratacoes_drive, PATH_CONTRATACOES_DRIVE)
