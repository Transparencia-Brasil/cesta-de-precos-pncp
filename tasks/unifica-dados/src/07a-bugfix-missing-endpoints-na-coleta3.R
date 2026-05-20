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
#' Parte a (este script):
#' Passos realizados:
#' - Filtra os itens com `endpoint = NA`.
#' - Usa expressões regulares para limpar e corrigir os valores do campo `endpoint`.
#' - Atualiza o campo `status_code` removendo partes inconsistentes.
#' - Gera o campo `numeroControlePNCPCompra` com base no `endpoint` corrigido.
#'
#' @return Um arquivo CSV contendo os itens com endpoints corrigidos,
#'   salvo em "tasks/unifica-dados/output/itens-endpoint-recuperado.csv".
#'


library(tidyverse)
library(here)

# vou buscar a função `make_id()` aqui
source(here("tasks/unifica-dados/src/01-mapeamento.R"))


# :: FILEPATHS -----------------------------------------------------------------

# os arquivos de coleta foram baixados do google drive e salvos localmente com o script "download-de-dados.R"
INPUT_DIR <- "tasks/unifica-dados/input"

# os arquivos unificados ficarão salvos na pasta "output"
OUTPUT_DIR <- "tasks/unifica-dados/output"

# Arquivo: https://drive.google.com/file/d/1qUsnlRLyAafgCEYQcTzsU47Yw4nT-qqn
CAMINHO_ITENS_COLETA3 <- here(INPUT_DIR, "itens3.rds")


# :: DATASETS ------------------------------------------------------------------

# Problema: o campo de endpoint está inconsistente. Ele está vazio e seu conteúdo está armazenado na coluna status_code.
itens_sem_endpoint <- readRDS(CAMINHO_ITENS_COLETA3) %>%
  filter(is.na(endpoint))


# :: RECUPERA ENDPOINT ---------------------------------------------------------

# regex que remove partes inconsistentes do endpoint
hey_jude <- "^(NA,)+\"" # (entendores entenderão esse nome)
status <- "\",\\d+$"
not_status <- "^.+\","

itens_sem_endpoints <- itens_sem_endpoint %>%
  mutate(
    endpoint = status_code %>%
      str_remove_all(hey_jude) %>%
      str_remove_all(status),
    status_code = str_remove_all(status_code, not_status)
  )

# inclui numeroControlePNCPCompra
itens_sem_endpoints <- itens_sem_endpoints %>%
  mutate(numeroControlePNCPCompra = make_id(endpoint))


# :: SALVA ---------------------------------------------------------------------

write_csv(itens_sem_endpoints, here(OUTPUT_DIR, "itens-endpoint-recuperado.csv"))

# Agora precisamos gerar embeddings e classificar novamente esses dados que foram recuperados (parte 2)
