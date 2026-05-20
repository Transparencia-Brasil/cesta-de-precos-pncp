#' @title Unifica coletas de itens das contratações
#' ---
#'
#' @description Este script une os dados de itens das contratações de medicamentos.
#' Esta unificação busca facilitar a análise de variação de preços de medicamentos.
#'
#' - Coleta 1: https://drive.google.com/drive/folders/1A9mNmKapHchsy9qqXCdg2xAh9pnnOWaJ
#' - Coleta 2: https://drive.google.com/drive/folders/1ZZ5ysQixMzT4srwCpirGhGsm9OpWeKy9
#' - Coleta 3: https://drive.google.com/drive/folders/13euL1rcl01dj3pQciLrMUj5yCnGf7ako
#'
#' @note Baixe os arquivos com o script `download-de-dados.R`, eles não serão enviados ao github, pois são grandes demais.
#'
#' A união dos datasets é feita com base no arquivo src/ETL/dados-de-teste/amostra_medicamentos.csv
#' Serve como referência para preencher nome de colunas e garantir que os dataframes possuem colunas de mesmo tipo
#'
#' @return Um arquivo CSV unificado contendo os dados de itens das contratações de medicamentos,
#' salvo em "tasks/unifica-dados/output/itens.csv".
#'


library(readr)
library(dplyr)
library(purrr)
library(here)
library(tidyverse)

source(here("tasks/unifica-dados/src/01-mapeamento.R"))


# :: FILEPATHS -----------------------------------------------------------------

# os arquivos de coleta foram baixados do google drive e salvos localmente com o script "download-de-dados.R"
INPUT_DIR <- "tasks/unifica-dados/input"

# os arquivos unificados ficarão salvos na pasta "output"
OUTPUT_DIR <- "tasks/unifica-dados/output"

# dados de teste
# Serve como referência para preencher nome de colunas e garantir que os dataframes possuem colunas de mesmo tipo
CAMINHO_DADOS_DE_TESTE <- here("src/ETL/dados-de-teste/amostra_medicamentos.csv")

# Arquivo: https://drive.google.com/file/d/1JxG_TQh9CMTdVykG0_gJk3YdengNF69V
CAMINHO_ITENS_COLETA1 <- here(INPUT_DIR, "itens1.rds")

# Arquivo: https://drive.google.com/file/d/1YttE9nGYI5NRzFe2VSNqDSPcpSqZoWU7
CAMINHO_ITENS_COLETA2 <- here(INPUT_DIR, "itens2.rds")

# Arquivo: https://drive.google.com/file/d/1qUsnlRLyAafgCEYQcTzsU47Yw4nT-qqn
CAMINHO_ITENS_COLETA3 <- here(INPUT_DIR, "itens3.rds")


# :: CARREGA COLETAS -----------------------------------------------------------

itens_coleta1 <- readRDS(CAMINHO_ITENS_COLETA1) |> filter(is.na(error)) # remove linhas com erro de coleta
itens_coleta2 <- readRDS(CAMINHO_ITENS_COLETA2)
itens_coleta3 <- readRDS(CAMINHO_ITENS_COLETA3)


# :: CARREGA TEMPLATE ----------------------------------------------------------

# dados de teste:
# Serve como referência para preencher nome de colunas e garantir que os dataframes possuem colunas de mesmo tipo
template <-  read_csv(CAMINHO_DADOS_DE_TESTEcol_types = cols(.default = "c"))[1:5, 1:32] |>
  mutate(endpoint = NA_character_)


# :: MAPPING -------------------------------------------------------------------

# executa rotina de mapeamento
# compara colunas com template ->> expected: `faltando` e `extras`` vazios e `comuns` com 33 elementos


# :: COLETA I ------------------------------------------------------------------

itens_coleta1 <- mapeamento_colunas_itens_coleta1(itens_coleta1)
comparar_colunas(itens_coleta1, template)


# :: COLETA II -----------------------------------------------------------------

itens_coleta2 <- mapeamento_colunas_itens_coleta2(itens_coleta2)
comparar_colunas(itens_coleta2, template)


# :: COLETA III ----------------------------------------------------------------

itens_coleta3 <- mapeamento_colunas_itens_coleta3(itens_coleta3)
comparar_colunas(itens_coleta3, template)


# :: ORDENAR COLUNA ------------------------------------------------------------

# Alinhar perfeitamente as colunas
ordenar_colunas <- \(coleta, template) select(coleta, names(template))

itens_coleta1 <- ordenar_colunas(itens_coleta1, template)
itens_coleta2 <- ordenar_colunas(itens_coleta2, template)
itens_coleta3 <- ordenar_colunas(itens_coleta3, template)


# :: FORÇA TIPO DE TEMPLATE ----------------------------------------------------

# Certifica-se que os dataframes possuem colunas de mesmo tipo (para uní-los)
coerce_class <- \(coleta) mutate(coleta, across(everything(), \(x) as.character(x)))

itens_coleta1 <- coerce_class(itens_coleta1)
itens_coleta2 <- coerce_class(itens_coleta2)
itens_coleta3 <- coerce_class(itens_coleta3)


# :: UNIFICA COLETAS -----------------------------------------------------------

# Une os dados de contratações de todas as coletas.
itens <- bind_rows(itens_coleta1, itens_coleta2, itens_coleta3)

# inclui numeroControlePNCPCompra
itens <- itens %>%
  mutate(numeroControlePNCPCompra = make_id(endpoint))

# Salva o arquivo em formato rds
write_csv(itens, here(OUTPUT_DIR, "itens.csv"))
