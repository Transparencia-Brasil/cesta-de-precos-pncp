library(tidyverse)
library(here)


file_info <- "coleta/itens" |>
  list.files(recursive = TRUE, full.names = TRUE, pattern = "dados.csv") |>
  here() |>
  as_tibble_col("path") |>
  filter(!str_detect(path, "_TESTE")) |>
  mutate(
    dados = map(path, file.info)
  ) |>
  unnest_wider(dados)  |>
  mutate(
    # campo `size` -> double: File size in bytes.
    size_mb = size / (1024 * 1024),
    size_gb = size / (1024 * 1024 * 1024)
  ) |>
  mutate(
    nrow = map_dbl(path, ~ read_csv(.x) |> nrow())
  ) |>
  glimpse()

glimpse(file_info)

mean(file_info$size_mb)
mean(file_info$size_gb)
mean(file_info$nrow)

sum(file_info$size_mb)
sum(file_info$size_gb)
sum(file_info$nrow)


file_info |>
  str_glue_data(
    "Com {sum(nrow)} itens já classificados no total, o dataset de itens possui um tamanho total de {round(sum(size_gb), 2)}. Como as coletas são feitas mensalmente, isso significa que a cada mês o dataset de itens cresce em média {round(mean(size_mb), 2) *2} MB com a adição de aproximadamente {round(mean(nrow) * 2)} itens novos."
  )

file_info_meds <- "coleta/itens" |>
  list.files(recursive = TRUE, full.names = TRUE, pattern = "medicamentos.csv") |>
  here() |>
  as_tibble_col("path") |>
  filter(!str_detect(path, "_TESTE")) |>
  mutate(
    dados = map(path, file.info)
  ) |>
  unnest_wider(dados)  |>
  mutate(
    # campo `size` -> double: File size in bytes.
    size_mb = size / (1024 * 1024),
    size_gb = size / (1024 * 1024 * 1024)
  ) |>
  mutate(
    nrow = map_dbl(path, ~ read_csv(.x) |> nrow())
  ) |>
  glimpse()

file_info_meds |>
  str_glue_data(
    "O dataset de medicamentos, resultante da filtragem e classificação dos itens, possui um tamanho total de {round(sum(size_mb), 2)} MB, com um total de {sum(nrow)} medicamentos classificados. A cada mês, o dataset de medicamentos cresce em média {round(mean(size_mb), 2) *2} MB, com a adição de aproximadamente {round(mean(nrow) * 2)} novos medicamentos."
  )
