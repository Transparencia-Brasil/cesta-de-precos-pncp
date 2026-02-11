library(tidyverse)
library(here)
options(width = 150)

PATH_CONTRATACOES <- list.files(
  here("coleta/data-package/2025"),
  recursive = TRUE,
  full.names = TRUE,
  pattern = "contratacoes\\.csv$"
)

PATH_ITENS <- list.files(
  here("coleta/data-package/2025"),
  recursive = TRUE,
  full.names = TRUE,
  pattern = "itens\\.csv$"
)

read_inexigibilidade <- function(path) {
  df <- read_csv(path, col_types = cols(.default = "c"))
  df <- df |> filter(data.modalidadeId == "9")
  df
}

get_numero_controle_pncp <- function(endpoint) {
  cnpj <- str_extract(endpoint, "\\d{14}")
  sequencial <- str_extract(endpoint, "20\\d\\d\\/\\d+")
  ano <- str_remove(sequencial, "\\/\\d+")
  sequencial <- str_remove(sequencial, "20\\d\\d\\/")
  sequencial <- str_pad(sequencial, width = 6, pad = "0")
  str_glue("{cnpj}-1-{sequencial}/{ano}")
}

contratacoes <- tibble(path = PATH_CONTRATACOES) |>
  mutate(
    mes_coleta = month(ym(str_extract(path, "2025/\\d{1,2}"))),
    dados = map(path, read_inexigibilidade)
  ) |>
  unnest(dados)

itens <- tibble(path = PATH_ITENS) |>
  mutate(
    mes_coleta = month(ym(str_extract(path, "2025/\\d{1,2}"))),
    dados = map(path, read_csv, col_types = cols(.default = "c"))
  ) |>
  unnest(dados) |>
  filter(is.na(`...51`) | is.na(`...52`)) |>
  select(-c(`...51`, `...52`)) |>
  mutate(numeroContolePNCP = get_numero_controle_pncp(endpoint)) |>
  glimpse()

numero_controle_pncp_inexigibilidade <- contratacoes |>
  select(numeroContolePNCP = data.numeroControlePNCP) |>
  distinct()

itens <- itens |>
  inner_join(numero_controle_pncp_inexigibilidade, by = "numeroContolePNCP")

write_excel_csv2(
  itens,
  here("tasks/contratacoes-inexigibilidade/outputs/itens.csv")
)

write_excel_csv2(
  contratacoes,
  here("tasks/contratacoes-inexigibilidade/outputs/contratacoes.csv")
)
