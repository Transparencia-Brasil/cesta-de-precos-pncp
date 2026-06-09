#' @title Identificar itens a recoletar
#' ---
#'
#' @description Este script identifica os itens que precisam ser recoletados devido a inconsistências no campo `endpoint` do arquivo `itens3.rds`.
#' O problema ocorre porque o campo `endpoint` está vazio e seu conteúdo foi armazenado
#' na coluna `status_code`. Este script compara os itens coletados com os medicamentos classificados para identificar quais itens precisam ser recoletados.
#'
#' @return Um arquivo CSV contendo os itens que precisam ser recoletados,
#'   salvo em "coleta/itens/medicamentos.csv".
#'

library(tidyverse)
library(here)

# os arquivos unificados ficarão salvos na pasta "output"
OUTPUT_DIR <- "tasks/unifica-dados/output"

resultados <- read_csv(here(OUTPUT_DIR, "itens-resultados.csv"))
medicamentos <- read_csv(here(OUTPUT_DIR, "medicamentos.csv"))

#' 'anti_join()' return all rows from 'x' with*out* a match in 'y'.
recoleta_resultados <- medicamentos %>%
  anti_join(resultados, by = c("numeroControlePNCPCompra", "numeroItem"))

recoleta_resultados %>%
  write_csv(here("coleta/itens/medicamentos.csv"))
