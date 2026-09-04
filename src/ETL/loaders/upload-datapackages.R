library(tidyverse)
library(googledrive)
library(here)

# :: ENV_VARS ------------------------------------------------------------------

# set drive auth email
DRIVE_AUTH_EMAIL <- here("drive-datapackage-upload.json")

# set drive dir
# "https://drive.google.com/drive/folders/1PnafST1QQo0k27MLX8hH9Wkt-EWVbEIi"
DRIVE_DIR <- as_id("1PnafST1QQo0k27MLX8hH9Wkt-EWVbEIi")

# set local dir target
LOCAL_DIR_TARGET <- here("coleta/data-package")

# :: SETUP GOOGLE DRIVE --------------------------------------------------------

# autentication
drive_auth(email = DRIVE_AUTH_EMAIL)
#drive_auth(path = DRIVE_AUTH_EMAIL)

# list existing drives
drives_existentes <- drive_ls(DRIVE_DIR) |>
  select(mes = name)


# :: LOCAL FILES TO UPLOAD -----------------------------------------------------

# list local files
arquivos <- list.files(LOCAL_DIR_TARGET, full.names = TRUE, recursive = TRUE)

# filter only the last month and quinzena
transfer <- tibble(arquivo = arquivos) |>
  mutate(
    ano = as.integer(str_extract(arquivo, "202[5-6]")),
    mes = str_extract(arquivo, "\\d{1,2} - \\w+"),
    mes_idx = as.integer(str_extract(mes, "\\d{1,2}")),
    quinzena = str_extract(arquivo, "QUINZENA-\\d"),
    dias = str_extract(arquivo, "DIAS?-\\d\\d-A(TE)?-\\d\\d"),
    dir = str_extract(arquivo, "DATA|LOG"),
    file = basename(arquivo)
  ) |>
  filter(ano == max(ano)) |>
  filter(mes_idx == max(mes_idx))


# remove drives that already exist
transfer <- transfer |>
  anti_join(drives_existentes, by = "mes")


# :: DRIVE FOLDERS CREATION ----------------------------------------------------

#' @description Cria um diretório no Google Drive para cada elemento de um vetor, dentro de um caminho específico
#' @param x Vetor de nomes dos diretórios a serem criados
#' @param caminho ID do diretório pai onde os novos diretórios serão criados
cria_diretorio <- function(x, caminho) {
  map2(x, caminho, \(nome, pai) drive_mkdir(nome, path = pai, overwrite = FALSE))
}

# cria diretório-mãe para o mês
transfer <- transfer |>
  nest(.by = mes) |>
  mutate(
    drive_dir_mes = cria_diretorio(mes, as_id(DRIVE_DIR)),
    drive_dir_mes = map_vec(drive_dir_mes, pluck, "id")
  ) |>
  unnest(data)

# cria diretório para quinzena
transfer <- transfer |>
  mutate(agregador = if_else(is.na(quinzena), dias, quinzena)) |>
  nest(.by = c(agregador, drive_dir_mes)) |>
  mutate(
    drive_dir_intervalo_dias = cria_diretorio(agregador, drive_dir_mes),
    drive_dir_intervalo_dias = map_vec(drive_dir_intervalo_dias, pluck, "id")
  ) |>
  unnest(data)

# cria diretório para tipo de arquivo (data ou log)
transfer <- transfer |>
  nest(.by = c(dir, drive_dir_intervalo_dias)) |>
  mutate(
    drive_dir_dir = map2_vec(dir, as_id(drive_dir_intervalo_dias), cria_diretorio),
    drive_dir_dir = map_vec(drive_dir_dir, pluck, "id")
  ) |>
  unnest(data)

# transfere arquivos nos diretórios criados
transfer <- transfer |>
  mutate(
    file_upload = pmap(list(media = arquivo, path = drive_dir_dir, name = file), drive_upload)
  )
