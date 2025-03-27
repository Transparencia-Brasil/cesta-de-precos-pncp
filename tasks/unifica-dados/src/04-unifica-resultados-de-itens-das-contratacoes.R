#' Unifica coletas de resultados de itens das contratações
#' ---
#'
#' Este script une os dados de resultados de itens das contratações de medicamentos.
#' Esta unificação busca facilitar a análise de variação de preços de medicamentos.
#'
#' - Coleta 2: https://drive.google.com/drive/folders/1ZZ5ysQixMzT4srwCpirGhGsm9OpWeKy9
#' - Coleta 3: https://drive.google.com/drive/folders/13euL1rcl01dj3pQciLrMUj5yCnGf7ako
#'
#' Nota: Baixe os arquivos com o script `download-de-dados.R`, eles não serão enviados ao github, pois são grandes demais.
#'
#' A união dos datasets é feita com base no arquivo src/ETL/dados-de-teste/amostra_resultados.csv
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
CAMINHO_DADOS_DE_TESTE <- here("src/ETL/dados-de-teste/amostra_resultados.csv")

# Arquivo: https://drive.google.com/file/d/1s9BE9pp6o3BN40QpfcqisfrSQhtLvl0q
CAMINHO_RESULTADOS_COLETA2 <- here(INPUT_DIR, "itens2-resultados.rds")

# Arquivo: https://drive.google.com/file/d/1DN5BoUQmIarPzwn-BcqWvNzE-P-kpgga
CAMINHO_RESULTADOS_COLETA3 <- here(INPUT_DIR, "itens3-resultados.rds")

# :: CARREGA COLETAS -----------------------------------------------------------

resultado_coleta2 <- readRDS(CAMINHO_RESULTADOS_COLETA2)
resultado_coleta3 <- readRDS(CAMINHO_RESULTADOS_COLETA3)

# dados de teste:
# Serve como referência para preencher nome de colunas e garantir que os dataframes possuem colunas de mesmo tipo
template <- read_csv(CAMINHO_DADOS_DE_TESTE, col_types = cols(.default = col_character()))[1:5, ] %>%
  mutate(endpoint = NA_character_)

# :: MAPPING -------------------------------------------------------------------

# executa rotina de mapeamento
# compara colunas com template ->> expected: `faltando` e `extras`` vazios e `comuns` com 39 elementos

resultado_coleta2 <- mapeamento_colunas_resultado_coleta2(resultado_coleta2)
comparar_colunas(resultado_coleta2, template)

resultado_coleta3 <- mapeamento_colunas_resultado_coleta3(resultado_coleta3)
comparar_colunas(resultado_coleta3, template)

# :: ORDENAR COLUNA ------------------------------------------------------------

# Alinhar perfeitamente as colunas
ordenar_colunas <- \(coleta, template) select(coleta, names(template))

resultado_coleta2 <- ordenar_colunas(resultado_coleta2, template)
resultado_coleta3 <- ordenar_colunas(resultado_coleta3, template)

# :: FORÇA TIPO DE TEMPLATE ----------------------------------------------------

# Certifica-se que os dataframes possuem colunas de mesmo tipo (para uní-los)
coerce_class <- \(coleta) mutate(coleta, across(everything(), \(x) as.character(x)))

resultado_coleta2 <- coerce_class(resultado_coleta2)
resultado_coleta3 <- coerce_class(resultado_coleta3)

# :: UNIFICA COLETAS -----------------------------------------------------------

# Une os dados de contratações de todas as coletas.
itens_resultados <- bind_rows(resultado_coleta2, resultado_coleta3)

# Salva o arquivo em formato rds
write_csv(itens_resultados, here(OUTPUT_DIR, "itens-resultados.csv"))
