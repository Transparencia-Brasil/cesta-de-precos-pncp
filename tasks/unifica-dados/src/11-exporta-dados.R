# Este script irá exportar os dados para uma pasta no googledrive

library(tidyverse)
library(here)
library(googledrive)

# FILEPATHS --------------------------------------------------------------------

# origem dos dados para exportar
LOCAL_PATH <- "tasks/unifica-dados/output"

# Destino dos dados no googledrive
DEST_PATH <- "https://drive.google.com/drive/folders/1OHGfJ2Sz8YtwluLnkRzeIj2jaX-bJ0lK"

# ARQUIVOS ---------------------------------------------------------------------

files <- c(
  "contratacoes" = "contratacoes.csv",
  "medicamentos" = "medicamentos.csv",
  "itens.csv" = "itens.csv",
  "itens-resultados" = "itens-resultados.csv",
  "itens-resultados-medicamentos" = "itens-resultados-medicamentos.csv"
)

# UPLOAD -----------------------------------------------------------------------

upload <- map(files, ~ drive_upload(
  media = here(LOCAL_PATH, .x),
  path = as_id(DEST_PATH),
  type = "csv",
  overwrite = TRUE
))
