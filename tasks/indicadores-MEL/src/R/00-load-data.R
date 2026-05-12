options(width = 150)

library(tidyverse)
library(here)

UTILS <- here("tasks/indicadores-MEL/src/R/utils.R")
source(UTILS, encoding = "UTF-8")

medicamentos <- "coleta/itens" |>
  list.files(recursive = TRUE, full.names = TRUE, pattern = "medicamentos.csv") |>
  here() |>
  as_tibble_col("path") |>
  filter(!str_detect(path, "_TESTE")) |>
  mutate(
    dados = map(path, read_csv, col_types = cols(.default = "c")),
    anomes_coleta = make_anomes_coleta(path)
  ) |>
  unnest(dados) |>
  mutate(data.numeroControlePNCP = make_id(endpoint))

contratacoes <- "coleta/contratacoes" |>
  list.files(recursive = TRUE, full.names = TRUE, pattern = "dados.csv") |>
  here() |>
  as_tibble_col("path") |>
  filter(!str_detect(path, "_TESTE")) |>
   mutate(
    dados = map(path, read_csv, col_types = cols(.default = "c")),
    path = basename(dirname(path))
  ) |>
  unnest(dados)

resultados <- "coleta/resultados" |>
  list.files(recursive = TRUE, full.names = TRUE, pattern = "dados.csv") |>
  here() |>
  as_tibble_col("path") |>
  filter(!str_detect(path, "_TESTE")) |>
   mutate(
    dados = map(path, read_csv, col_types = cols(.default = "c")),
    anomes_coleta = make_anomes_coleta(path)
  ) |>
  unnest(dados)

ids_validos <- medicamentos |>
  distinct(data.numeroControlePNCP)

contratacoes <- inner_join(contratacoes, ids_validos)

saveRDS(medicamentos, file = here("tasks/indicadores-MEL/inputs/medicamentos.rds"))
saveRDS(contratacoes, file = here("tasks/indicadores-MEL/inputs/contratacoes.rds"))
saveRDS(resultados, file = here("tasks/indicadores-MEL/inputs/resultados.rds"))
