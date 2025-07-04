# cria data_packages dirs
library(tidyverse)
library(here)


# LISTA DE ARQUIVOS ------------------------------------------------------------

data_files <- c(
  "contratacoes-erros.csv",
  "contratacoes-monitoramento.csv",
  "contratacoes.csv",
  "itens-erros.csv",
  "itens-medicamentos-resultados-erros.csv",
  "itens-medicamentos-resultados-monitoramento.csv",
  "itens-medicamentos-resultados.csv",
  "itens-medicamentos.csv",
  "itens-monitoramento.csv",
  "itens.csv"
)

log_files <- c(
  "run-classificador",
  "run-coletor-contratacoes",
  "run-coletor-itens",
  "run-coletor-resultados",
  "run-coletores"
)


# ARQUIVOS PADRÃO PACOTE -------------------------------------------------------

arquivos <- tibble(
  dia = seq.Date(dmy("01-01-2025"), dmy("31-12-2025"), by = "day"),
  dia_int = day(dia),
  mes = str_to_title(format(ISOdate(2000, 1:12, 1), "%B")[month(dia)]),
  mes_int = month(dia),
  ano = year(dia)
) %>%
  mutate(
    mes = sprintf("%s - %s", month(dia), str_to_title(mes)),
    quinzena = if_else(dia_int <= 15, "QUINZENA-1", "QUINZENA-2")
  ) %>%
  group_by(ano, mes, quinzena) %>%
  filter(dia_int == min(dia_int) | dia_int == max(dia_int)) %>%
  mutate(
    data = "DATA",
    log = "LOG"
  ) %>%
  pivot_longer(c(data, log), names_to = "names", values_to = "dir") %>%
  select(-names) %>%
  group_by(ano, mes, quinzena) %>%
  mutate(ref = if_else(dia_int == min(dia_int), "data_inicio", "data_fim")) %>%
  ungroup() %>%
  select(-dia_int) %>%
  pivot_wider(id_cols = c(mes, mes_int, ano, quinzena, dir), names_from = ref, values_from = dia) %>%
  mutate(files = if_else(dir == "DATA", list(data_files), list(log_files))) %>%
  unnest(files) %>%
  mutate(
    data_inicio = if_else(data_inicio == dmy("16-01-2025"), dmy("15-01-2025"), data_inicio),
    files = case_when(
      files == "run-coletores" ~ sprintf("%s-%s-%s-%s.log", files, ano, mes_int, quinzena),
      dir == "LOG" ~ sprintf("%s-%s-ate-%s.log", files, data_inicio, data_fim),
      .default = files
    )
  ) %>%
  mutate(dest_dir = sprintf("coleta/data-package/%s/%s/%s/%s", ano, mes, quinzena, dir))


# ARQUIVOS PADRÂO COLETOR - CONTRATACOES ---------------------------------------

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


# ARQUIVOS PADRÂO COLETOR - ITENS ----------------------------------------------

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


# ARQUIVOS PADRÂO COLETOR - RESULTADOS -----------------------------------------

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


# TO ---------------------------------------------------------------------------

to <- arquivos %>%
  transmute(
    ano_int = as.integer(ano), mes_int, quinzena,
    dest_dir,
    files_to = files
  )

# TABELA DE TRANSPORTE ---------------------------------------------------------

tabela_de_transporte <- inner_join(to, from) %>%
  transmute(
    from = files,
    to = sprintf("%s/%s", here(dest_dir), files_to)
  )

TABELA_DE_TRANSPORTE_PATH <- here("tasks/migra-dados-para-data-package/inputs/tabela-de-arquivos-coletados.rds")

saveRDS(tabela_de_transporte, TABELA_DE_TRANSPORTE_PATH)

# CRIA DIRETÒRIOS DESTINO ------------------------------------------------------

walk(unique(dirname(tabela_de_transporte$to)), dir.create, recursive = TRUE)


# COPIA ARQUIVOS PARA PACOTE ---------------------------------------------------

map2(tabela_de_transporte$from, tabela_de_transporte$to, file.copy, recursive = TRUE)
