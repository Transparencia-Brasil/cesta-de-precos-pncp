#' ---
#' Unifica coletas de contratações
#' ---
#'
#' Este script une os dados de contratações de medicamentos.
#' Esta unificação busca facilitar a análise de variação de preços de medicamentos.
#'
#' - Coleta 2: https://drive.google.com/drive/folders/1ZZ5ysQixMzT4srwCpirGhGsm9OpWeKy9
#' - Coleta 3: https://drive.google.com/drive/folders/13euL1rcl01dj3pQciLrMUj5yCnGf7ako
#'
#' Nota: Baixe os arquivos com o script `download-de-dados.R`, eles não serão enviados ao github, pois são grandes demais.

library(readr)
library(dplyr)
library(purrr)
library(here)

source(here("tasks/unifica-dados/src/mapeamento.R"))

# :: FILEPATHS --------------------------------------------------------------------

# os arquivos de coleta foram baixados do google drive e salvos localmente com o script "download-de-dados.R"
INPUT_DIR <- "tasks/unifica-dados/input"

# os arquivos unificados ficarão salvos na pasta "output"
OUTPUT_DIR <- "tasks/unifica-dados/output"

# Arquivo: https://drive.google.com/file/d/1Al2pfTFfa_ODGgHlq7ApiyfAnpJpbuEK
CAMINHO_CONTRATACOES_COLETA2 <- here(INPUT_DIR, "contratacoes2.rds")
# Arquivo: https://drive.google.com/file/d/1VfrLyZoGOoc9ugF2lvLeKwcBbiReVpZm
CAMINHO_CONTRATACOES_COLETA3 <- here(INPUT_DIR, "contratacoes3.rds")

# CARREGA COLETAS --------------------------------------------------------------
contratacoes_coleta2 <- readRDS(CAMINHO_CONTRATACOES_COLETA2)
contratacoes_coleta3 <- readRDS(CAMINHO_CONTRATACOES_COLETA3)

# :: MAPPING -------------------------------------------------------------------

# Renomeia as colunas e seleciona somente as necessárias
contratacoes_coleta2 <- contratacoes_coleta2 %>%
  rename(all_of(mapeamento_colunas_contratacoes)) %>%
    select(names(mapeamento_colunas_contratacoes))

contratacoes_coleta3 <- contratacoes_coleta3 %>%
  rename(all_of(mapeamento_colunas_contratacoes)) %>%
    select(names(mapeamento_colunas_contratacoes))

# Certifica-se que os dataframes possuem colunas de mesmo tipo (para uní-los)
contratacoes_coleta3 <- map2_dfr(contratacoes_coleta3, contratacoes_coleta2, ~ as(.x, class(.y)))

# :: UNIFICA COLETAS -----------------------------------------------------------

# Une os dados de contratações de todas as coletas.
contratacoes <- bind_rows(contratacoes_coleta2, contratacoes_coleta3)

# Salva o arquivo em formato rds
dir.create(here(OUTPUT_DIR))
saveRDS(contratacoes, here(OUTPUT_DIR, "contratacoes.csv"))
