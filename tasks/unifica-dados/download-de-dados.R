library(here)
library(googledrive)
library(dplyr)
library(purrr)
library(tidyverse)

input_dir <- "tasks/unifica-dados/input"

#' Baixa arquivos do Google Drive
#'
#' Esta função realiza o download de arquivos de uma pasta no Google Drive com base em um padrão especificado.
#'
#' @param drive_url URL da pasta no Google Drive onde os arquivos estão localizados.
#' @param pattern Um padrão (regex) para filtrar os arquivos que serão baixados.
#' @param path Caminho local onde os arquivos serão salvos.
#'
#' @return Um data frame contendo informações sobre os arquivos baixados.
#' @importFrom googledrive drive_ls drive_download
#' @importFrom dplyr transmute
#' @importFrom purrr pmap_df
#' @examples
#' \dontrun{
#' # Exemplo de uso:
#' download_from_googledrive(
#'   drive_url = "https://drive.google.com/drive/folders/EXEMPLO",
#'   pattern = ".*\\.csv$",
#'   path = "dados/"
#' )
#' }
download_from_googledrive <- function(drive_url, pattern, path) {
  files <- drive_ls(drive_url, pattern = pattern, recursive = TRUE) %>%
    transmute(file = id, path = path) %>%
    pmap_df(drive_download, overwrite = TRUE)
}


# COLETA II --------------------------------------------------------------------

coleta2_url <- "https://drive.google.com/drive/folders/1ZZ5ysQixMzT4srwCpirGhGsm9OpWeKy9"

coleta2_files <- c(
  "contratacoes2.rds" = "consultar-compra-2024-10-09.rds",
  "itens2.rds" = "medicamentos.rds",
  "itens2-resultados.rds" = "resultados-dos-itens (todas as coletas).rds"
)

coleta2_pattern <- coleta2_files %>%
  paste0(collapse = "|") %>%
  str_replace_all("\\(|\\)", ".")

coleta2_path <- here(input_dir, names(coleta2_files))

coleta2_dir <- download_from_googledrive(coleta2_url, coleta2_pattern, coleta2_path)


# COLETA III -------------------------------------------------------------------

coleta3_url <- "https://drive.google.com/drive/folders/13euL1rcl01dj3pQciLrMUj5yCnGf7ako"

coleta3_files <- c(
  "contratacoes3.csv" = "resultado.csv",
  "itens3.rds" = "itens-da-contratacao-2025-01-29.rds",
  "itens3-resultados.rds" = "resultados-itens-da-contratacao-2025-02-03.rds"
)

coleta3_pattern <- coleta3_files %>%
  paste0(collapse = "|")

coleta3_path <- here(input_dir, names(coleta3_files))

coleta3_dir <- download_from_googledrive(coleta3_url, coleta3_pattern, coleta3_path)

read_csv(here(input_dir, "contratacoes3.csv"), col_types = cols(.default = col_character())) %>%
  saveRDS(here(input_dir, "contratacoes3.rds"))
