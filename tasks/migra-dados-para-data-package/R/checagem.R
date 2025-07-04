# cria data_packages dirs
library(tidyverse)
library(here)

# Cria chave de cruzamento
make_id <- \(endpoint) {
  cnpj <- endpoint %>%
    str_remove("^.+orgaos\\/") %>%
    str_remove("\\/compras.+")

  ano <- endpoint %>%
    str_remove("^.+compras\\/") %>%
    str_extract("^\\d+")

  sequencial <- endpoint %>%
    str_remove(str_glue("^.+compras\\/{ano}\\/")) %>%
    str_remove(str_glue("\\/itens")) %>%
    str_pad(width = 6, pad = "0")

  numeroControlePNCP <- str_glue("{cnpj}-1-{sequencial}/{ano}")

  return(numeroControlePNCP)
}

# ARQUIVOS PADRÂO PACOTE - CONTRATACOES ----------------------------------------

contratacoes <- tibble(dir = here("coleta/contratacoes")) %>%
  mutate(
    files = map(dir, list.files, recursive = TRUE)
  ) %>%
  unnest(files) %>%
  mutate(
    subdir = dirname(files),
    files = basename(files),
    files_to = case_when(
      files == "dados.csv" ~ "contratacoes.csv",
      files == "erros.csv" ~ "contratacoes-erros.csv",
      files == "monitoramento.csv" ~ "contratacoes-monitoramento.csv",
      .default = files
    ),
    quinzena = if_else(str_detect(subdir, "Q.*1$"), "QUINZENA-1", "QUINZENA-2"),
    ano_int = as.integer(str_extract(subdir, "^202[4,5]")),
    mes_int = as.integer(str_extract(subdir, "(?<=-)[0,1][1-9]")),
    .after = dir
  ) %>%
  filter(subdir != "TESTE")


# ARQUIVOS PADRÂO PACOTE - ITENS -----------------------------------------------

itens <- tibble(dir = here("coleta/itens")) %>%
  mutate(
    files = map(dir, list.files, recursive = TRUE)
  ) %>%
  unnest(files) %>%
  mutate(
    subdir = dirname(files),
    files = basename(files),
    files_to = case_when(
      files == "dados.csv" ~ "itens.csv",
      files == "erros.csv" ~ "itens-erros.csv",
      files == "monitoramento.csv" ~ "itens-monitoramento.csv",
      files == "medicamentos.csv" ~ "itens-medicamentos.csv",
      .default = files
    ),
    quinzena = if_else(str_detect(subdir, "Q.*1$"), "QUINZENA-1", "QUINZENA-2"),
    ano_int = as.integer(str_extract(subdir, "^202[4,5]")),
    mes_int = as.integer(str_extract(subdir, "(?<=-)[0,1][1-9]")),
    .after = dir
  ) %>%
  filter(subdir != "TESTE")


# ARQUIVOS PADRÂO PACOTE - RESULTADOS ------------------------------------------

resultados <- tibble(dir = here("coleta/resultados")) %>%
  mutate(
    files = map(dir, list.files, recursive = TRUE)
  ) %>%
  unnest(files) %>%
  mutate(
    subdir = dirname(files),
    files = basename(files),
    files_to = case_when(
      files == "dados.csv" ~ "itens-medicamentos-resultados.csv",
      files == "erros.csv" ~ "itens-medicamentos-erros.csv",
      files == "monitoramento.csv" ~ "itens-medicamentos-monitoramento.csv",
      .default = files
    ),
    quinzena = if_else(str_detect(subdir, "Q.*1$"), "QUINZENA-1", "QUINZENA-2"),
    ano_int = as.integer(str_extract(subdir, "^202[4,5]")),
    mes_int = as.integer(str_extract(subdir, "(?<=-)[0,1][1-9]")),
    .after = dir
  ) %>%
  filter(subdir != "TESTE")


# FROM -------------------------------------------------------------------------

from <- bind_rows(contratacoes, itens, resultados) %>%
  transmute(
    ano_int, mes_int, quinzena,
    files_to,
    files = sprintf("%s/%s/%s", dir, subdir, files)
  )

from <- from %>%
  filter(files_to %in% c("contratacoes.csv", "itens.csv", "itens-medicamentos.csv", "itens-medicamentos-resultados.csv")) %>%
  arrange(files_to, mes_int, quinzena)

from <- from %>%
  mutate(data = map(files, read_csv, col_types = cols(.default = col_character())))

from %>%
  select(-files) %>%
  mutate(
    ncol = map_int(data, ncol),
    nrow = map_int(data, nrow)
  ) %>%
  print(n = Inf)

from %>%
  select(-files) %>%
  filter(files_to == "contratacoes.csv") %>%
  mutate(data = map(data, ~ select(.x, data.dataInclusao))) %>%
  unnest(data) %>%
  mutate(data.dataInclusao = as_datetime(data.dataInclusao)) %>%
  count(ano_int, mes_int, quinzena, year(data.dataInclusao)) %>%
  print(n = Inf)


from %>%
  select(-files) %>%
  filter(files_to == "contratacoes.csv") %>%
  filter(mes_int == 2L) %>%
  filter(quinzena == "QUINZENA-2") %>%
  unnest(data) %>%
  filter(data.numeroControlePNCP %in% ids_med$numeroControlePNCP) %>%
  mutate(data.dataInclusao = as_datetime(data.dataInclusao)) %>%
  filter(!is.na(data.dataInclusao)) %>%
  View()



ids_med <- from %>%
  filter(files_to == "itens-medicamentos.csv") %>%
  filter(mes_int == 2L) %>%
  filter(quinzena == "QUINZENA-2") %>%
  unnest(data) %>%
  transmute(numeroControlePNCP = make_id(endpoint)) %>%
  distinct(numeroControlePNCP)
