#' ---
#' Download de Dados
#' ---
#'
#' Este script realiza o download de dados necessários para a unificação de informações
#' relacionadas à cesta de preços do PNCP (Programa Nacional de Compras Públicas).
#' Ele utiliza bibliotecas para manipulação de arquivos, integração com o Google Drive,
#' e processamento de dados em R.
#'

# libs
library(here)
library(googledrive)
library(dplyr)
library(purrr)
library(stringr)

# os dados baixados serão guardados neste diretório
input_dir <- "tasks/unifica-dados/input"

#' Baixa arquivos do Google Drive
#'
#' @description Função para baixar arquivos de uma pasta no Google Drive para um diretório local.
#'
#' @param drive_url URL da pasta no Google Drive de onde os arquivos serão baixados.
#' @param pattern Padrão de correspondência para filtrar os arquivos a serem baixados.
#' @param input_dir Diretório local onde os arquivos serão salvos.
#' @param local_files Lista de arquivos locais para mapear os nomes dos arquivos baixados.
#'
#' @return Um data frame contendo informações sobre os arquivos baixados, incluindo seus IDs e caminhos locais.
#' @details Esta função utiliza a API do Google Drive para listar e baixar arquivos de uma pasta específica. Os arquivos são filtrados com base no padrão fornecido e salvos no diretório local especificado.
#'
download_from_googledrive <- function(drive_url, pattern, input_dir, local_files) {
  files <- drive_url %>%
    drive_ls(pattern = pattern, recursive = TRUE) %>%
    transmute(file = id, path = here(input_dir, local_files[name])) %>%
    pmap_df(drive_download, overwrite = TRUE)
  return(files)
}

# COLETA II --------------------------------------------------------------------

# URL da pasta no Google Drive para a coleta II
coleta2_url <- "https://drive.google.com/drive/folders/1ZZ5ysQixMzT4srwCpirGhGsm9OpWeKy9"

# Mapeamento dos arquivos a serem baixados e seus nomes locais
coleta2_files <- c(
  "consultar-compra-2024-10-09.rds" = "contratacoes2.rds",
  "medicamentos.rds" = "itens2.rds",
  "resultados-dos-itens (todas as coletas).rds" = "itens2-resultados.rds"
)

# Criação de um padrão regex para filtrar os arquivos no Google Drive
coleta2_pattern <- names(coleta2_files) %>%
  paste0(collapse = "|") %>%
  str_replace_all("\\(|\\)", ".")

# Realiza o download dos arquivos do Google Drive para o diretório local
coleta2_dir <- download_from_googledrive(
  drive_url = coleta2_url,
  pattern = coleta2_pattern,
  input_dir = input_dir,
  local_files = coleta2_files
)

# COLETA III -------------------------------------------------------------------

# URL da pasta no Google Drive para a coleta III
coleta3_url <- "https://drive.google.com/drive/folders/13euL1rcl01dj3pQciLrMUj5yCnGf7ako"

# Mapeamento dos arquivos a serem baixados e seus nomes locais
coleta3_files <- c(
  "resultado.csv" = "contratacoes3.csv",
  "medicamentos-pncp-2025-01-29.rds" = "itens3.rds",
  "resultados-itens-da-contratacao-2025-02-03.rds" = "itens3-resultados.rds"
)

# Criação de um padrão regex para filtrar os arquivos no Google Drive
coleta3_pattern <- names(coleta3_files) %>%
  paste0(collapse = "|")

# Realiza o download dos arquivos do Google Drive para o diretório local
coleta3_dir <- download_from_googledrive(
  drive_url = coleta3_url,
  pattern = coleta3_pattern,
  input_dir = input_dir,
  local_files = coleta3_files
)

# Lê o arquivo CSV baixado, converte todas as colunas para o tipo caractere e salva como RDS
here(input_dir, "contratacoes3.csv") %>%
  read_csv(col_types = cols(.default = col_character())) %>%
  saveRDS(here(input_dir, "contratacoes3.rds"))
