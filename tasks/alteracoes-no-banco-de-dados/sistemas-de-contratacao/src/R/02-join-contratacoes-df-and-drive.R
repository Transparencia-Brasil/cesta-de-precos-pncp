
library(here)
library(tidyverse)

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

contratacoes |>
  count(usuario_nome, sort = TRUE, name = "qtde_contratacoes_no_pncp") |>


contratacoes_drive |>
  filter(numero_controle_pncp == "00000368000150-1-000044/2024")


get_query("select * from contratacao where numero_controle_pncp = '00000368000150-1-000065/2024'") |> glimpse()
