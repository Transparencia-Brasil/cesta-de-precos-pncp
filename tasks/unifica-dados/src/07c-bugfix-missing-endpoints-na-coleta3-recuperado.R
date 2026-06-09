#' @title Bugfix: consertar ids de endpoints = NA
#' ---
#'
#' @description Este script corrige inconsistências no campo `endpoint` do arquivo `itens3.rds`.
#' O problema ocorre porque o campo `endpoint` está vazio e seu conteúdo foi armazenado na coluna `status_code`.
#'
#' - Parte a: Separa endpoints missings e faz a sanitização de dados afetados
#' - Parte b: gerar embeddings deses endpoints restaurados (com script python)
#' - Parte c: remover linhas inconsistes e incluir sanitizadas no dataset final
#'
#' Parte c (este script):
#' Passos realizados:
#' - Carrega dataset final (com linhas inconsistentes no campo `endpoint`)
#' - Carrega dataset com endpoints recuperados
#' - remove linhas inconsistentes e inclui linhas sanitizadas no dataset final
#' - cria um backup do dataset original (renomeia)
#' - salva o dataset final com campos corrigidos
#'
#' @return
#' "output/itens.csv" e "output/medicamentos.csv" atualizados com os endpoints corrigidos.
#' "output/itens.csv.old" e "output/medicamentos.csv.old" contendo os backups dos arquivos originais antes da correção.
#'
library(tidyverse)
library(here)

# os arquivos unificados ficarão salvos na pasta "output"
OUTPUT_DIR <- "tasks/unifica-dados/output"


# :: DATASETS ------------------------------------------------------------------

# - dados a recuperar:

# Itens já coletados e unificados deverão ser sanitizados
itens_coletados <- read_csv(here(OUTPUT_DIR, "itens.csv"))

# Medicamentos deverão ser sanitizados
medicamentos_classificados <- read_csv(here(OUTPUT_DIR, "medicamentos.csv"))

# - dados com endpoints recuperados:

# Os itens recuperados
itens_recuperados <- read_csv(here(OUTPUT_DIR, "itens-endpoint-recuperado.csv"))

# os medicamentos recuperados, já classificados e com embeddings
medicamentos_recuperados <- read_csv(here(OUTPUT_DIR, "medicamentos-endpoint-recuperado.csv"))


# :: RECUPERA ENDPOINT ---------------------------------------------------------

itens_fixed <- itens_coletados %>%
  filter(!is.na(endpoint)) %>%
  bind_rows(itens_recuperados)

medicamentos_fixed <- medicamentos_classificados %>%
  filter(!is.na(endpoint)) %>%
  bind_rows(medicamentos_recuperados)


# :: DEPRECATE FILES -----------------------------------------------------------
file.rename(CAMINHO_ITENS_COLETADOS_UNIFICADOS, here(OUTPUT_DIR, "itens.csv.old"))
file.rename(CAMINHO_MEDICAMENTOS_CLASSIFICADOS, here(OUTPUT_DIR, "medicamentos.csv.old"))


# :: SALVA ---------------------------------------------------------------------
write_csv(itens_fixed, here(OUTPUT_DIR, "itens.csv"))
write_csv(medicamentos_fixed, here(OUTPUT_DIR, "medicamentos.csv"))
