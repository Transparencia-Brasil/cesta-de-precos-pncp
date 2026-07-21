
library(here)
library(tidyverse)

# ' Esse script realiza o join entre os dados de contratações do banco de dados e do Google Drive.
PLAN_GSHEETS <- "https://docs.google.com/spreadsheets/d/1Mj_HUHC2wwWCaxhcSn5cZIQXXajkfY5sI2oTODhXTvM"

#' Esse script aproveita o resultado do código legado a seguir:
#' defina LOAD_SOURCE como TRUE para rodar o código legado e gerar o arquivo de saída
LOAD_SOURCE <- FALSE
LOAD_CONTRATACOES_FROM_DRIVE <- here("tasks/alteracoes-no-banco-de-dados/sistemas-de-contratacao/src/R/01-load-contratacoes-from-drive.R")
#'

PATH_CONTRATACOES_DB <- here("tasks/alteracoes-no-banco-de-dados/sistemas-de-contratacao/inputs/contratacoes-db.rds")
PATH_CONTRATACOES_DRIVE <- here("tasks/alteracoes-no-banco-de-dados/sistemas-de-contratacao/inputs/contratacoes-drive.rds")

if (LOAD_SOURCE) {
  message("Rodando código legado para carregar as contratações do Drive...")
  source(LOAD_CONTRATACOES_FROM_DRIVE, encoding = "UTF-8")
} else {
  message("Carregando contratações do arquivo RDS...")
  contratacoes_drive <- readRDS(PATH_CONTRATACOES_DRIVE)
}

contratacoes_drive <- contratacoes_drive |>
  filter(!is.na(usuario_nome)) |>
  filter(!str_detect(usuario_nome, "^\\d.+$"))

contratacoes_db <- readRDS(PATH_CONTRATACOES_DB)

contratacoes <- inner_join(contratacoes_db, contratacoes_drive, by = "numero_controle_pncp")

count_contratacoes <- contratacoes |>
  count(usuario_nome, sort = TRUE, name = "qtde_contratacoes_no_pncp")

count_contratacoes |>
  googlesheets4::sheet_write(ss = PLAN_GSHEETS, sheet = "[JUL-2026] ATUALIZADO - COUNT")

top_10 <- count_contratacoes |>
  slice(2:10)

contratacoes |>
  filter(usuario_nome %in% top_10$usuario_nome) |>
  arrange(usuario_nome) |>
  googlesheets4::sheet_write(ss = PLAN_GSHEETS, sheet = "[JUL-2026] ATUALIZADO - DETALHES")
