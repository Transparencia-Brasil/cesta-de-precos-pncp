options(width = 150)

library(tidyverse)
library(here)
library(googledrive)


# :: FILEPATHS -----------------------------------------------------------------

# origem dos dados para exportar
LOCAL_PATH <- "tasks/unifica-dados/output"
TMP_PATH <- "tasks/indicadores-MEL/tmp"

# Destino dos dados no googledrive
DEST_PATH <- "https://drive.google.com/drive/folders/1lTEahEebtKeGG2Zjn7tn0Iu1pRkxi4OY"

# lista diretórios de coletas do drive
# 🔓 : pra fazer o login basta rodar o comando abaixo e seguir as instruções no navegador
all_files <- drive_ls(DEST_PATH)


# :: LOAD - COLETAS I-II-III ---------------------------------------------------

message("Listando dados das coletas I, II e III no drive...")

# seleciona arquivos das coletas I, II e III no drive
# precisa ir descendo a hierarquia de pastas para chegar nos arquivos csv
coletas_i_ii_iii <- all_files |>
  filter(str_detect(name, "III$")) |>
  select(coleta = name, coleta_id = id) |>
  mutate(files = map(coleta_id, drive_ls)) |>
  unnest(files) |>
  select(-drive_resource) |>
  transmute(
    # coleta I-II-III/arquivo.csv
    path = here(TMP_PATH, coleta),
    file = name,
    file_id = id
  )


## :: LOAD - COLETAS 2025-2026 ----*--------------------------------------------

message("Listando dados das coletas 2025-2026 no drive...")

# seleciona arquivos das coletas 2025-2026 no drive
# precisa ir descendo a hierarquia de pastas para chegar nos arquivos csv
coletas_25_26 <- all_files |>
  filter(!str_detect(name, "III$")) |>
  # coleta ano/
  select(coleta = name, coleta_id = id) |>
  mutate(files = map(coleta_id, drive_ls)) |>
  unnest(files) |>
  select(-drive_resource) |>
  # coleta ano/mes/
  rename(mesdir = name, mesdir_id = id) |>
  filter(mesdir != "old") |>
  mutate(files = map(mesdir_id, drive_ls)) |>
  unnest(files) |>
  select(-drive_resource) |>
  # coleta ano/mes/quinzena/
  rename(quinzena = name, quinzena_id = id) |>
  mutate(files = map(quinzena_id, drive_ls)) |>
  unnest(files) |>
  select(-drive_resource) |>
  # coleta ano/mes/quinzena/data
  filter(name == "DATA") |>
  rename(datadir_id = id, datadir = name) |>
  mutate(files = map(datadir_id, drive_ls)) |>
  unnest(files) |>
  select(-drive_resource) |>
  # coleta ano/mes/quinzena/arquivo.csv
  transmute(
    path = here(TMP_PATH, coleta, mesdir, quinzena),
    file = name,
    file_id = id
  ) |>
  filter(!str_detect(file, "monitoramento|erros"))


# :: TEMP DIRS -----------------------------------------------------------------

message("Criando diretórios temporários para download dos dados...")

# cria temp dir para receber dados do drive
dir.create(unique(coletas_i_ii_iii$path))

# cria temp dir para receber dados do drive
walk(
  unique(coletas_25_26$path),
  dir.create,
  recursive = TRUE
)


# :: DOWNLOAD ------------------------------------------------------------------

message("Realizando download dos dados do drive em /tmp...")

# realiza o donwload - COLETAS I-II-III
coletas_i_ii_iii <- coletas_i_ii_iii |>
  mutate(files = map2(file_id, here(path, file),
    ~ drive_download(
      file = .x,
      path = .y,
      overwrite = TRUE
  )))

# realiza o donwload - COLETAS 2025-2026
coletas_25_26 <- coletas_25_26 |>
  mutate(files = map2(
    file_id, here(path, file),
    ~ drive_download(
      file = .x,
      path = .y,
      overwrite = TRUE
    )
  ))

message("Fim =)")
