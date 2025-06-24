library(tidyverse)
library(here)

source(here("tasks/verifica-campos-com-catalogo-e-ncm/src/utils.R"))
source(here("setup/rsetup.R"))


# FILEPATHS --------------------------------------------------------------------

PATH_ITENS_2024 <- here("tasks/unifica-dados/output/itens.csv")

PATH_ITENS_2025 <- list.files(
  path = here("coleta/itens"),
  pattern = "dados.csv",
  recursive = TRUE,
  full.names = TRUE
)
PATH_ITENS_2025 <- PATH_ITENS_2025[!grepl("TESTE", PATH_ITENS_2025)]

PATH_INPUT <- "tasks/verifica-campos-com-catalogo-e-ncm/input"
PATH_USUARIO <- here(PATH_INPUT, "usuarios.rds")
PATH_ITENS <- here(PATH_INPUT, "itens-filtrados.rds")


# LINHA DO TEMPO DA COLETA -----------------------------------------------------

atual <- file.info(PATH_ITENS_2025) %>%
  rownames_to_column("file") %>%
  as_tibble() %>%
  transmute(
    file,
    coleta = str_remove(file, "^.+itens/"),
    coleta = str_remove(coleta, "\\/dados\\.csv$"),
    coleta = str_remove(coleta, ".Q.*[12]$"),
    data_coleta = ym(coleta),
    # aponta qual é o arquivo mais recente
    atual = data_coleta == max(data_coleta)
  )


# READ DATA --------------------------------------------------------------------

# 2024 ---

# read
itens_2024 <- read_csv(PATH_ITENS_2024, col_types = list(.default = col_character()))

# recode endpoint
itens_2024 <- itens_2024 %>%
  mutate(endpoint = sprintf("%s/%s", endpoint, numeroItem))

# select columns
itens_2024 <- itens_2024 %>%
  select(
    endpoint,
    numeroControlePNCPCompra, numeroItem,
    dataInclusao, dataAtualizacao,
    descricao, unidadeMedida, valorTotal, quantidade,
    informacaoComplementar,
    contains("atalogo"),
    starts_with("ncm")
  )

# create references
itens_2024 <- itens_2024 %>%
  mutate(
    file = PATH_ITENS_2024,
    coleta = "2024",
    data_coleta = ym("2024-12"),
    atual = FALSE
  )


# 2025 ---

# read multiple files
itens_2025 <- map(PATH_ITENS_2025, read_csv, col_types = list(.default = col_character())) %>%
  # creating references
  set_names(PATH_ITENS_2025) %>%
  enframe(name = "file", value = "data") %>%
  left_join(atual) %>%
  # unnest data
  unnest(cols = c(data))

# recode endpoint
itens_2025 <- itens_2025 %>%
  mutate(
    endpoint = sprintf("%s/%s", endpoint, numeroItem),
    numeroControlePNCPCompra = make_id(str_remove(endpoint, "\\/\\d+$")),
  )

# select columns
itens_2025 <- itens_2025 %>%
  select(
    endpoint,
    numeroControlePNCPCompra, numeroItem,
    dataInclusao, dataAtualizacao,
    descricao, unidadeMedida, valorTotal, quantidade,
    informacaoComplementar,
    contains("atalogo"),
    starts_with("ncm"),
    file, coleta, data_coleta, atual
  )


# ITENS ------------------------------------------------------------------------

# COMPLETA (SEM FILTRAR)
itens <- bind_rows(itens_2024, itens_2025)

# plot
contagem_de_itens_coletados(itens)


# FILTER -----------------------------------------------------------------------

rm(itens)

# So vamos analisar de outubro/2024 em diante

itens_2024_filtrado <- itens_2024 %>%
  filter(year(dataInclusao) == 2024) %>%
  filter(month(dataInclusao) >= 10) %>%
  mutate(id = "itens_2024")

itens_2025_filtrado <- itens_2025 %>%
  filter(
    (year(dataInclusao) >= 2024 & month(dataInclusao) %in% c(10, 11, 12)) |
      (year(dataInclusao) >= 2025)
  ) %>%
  mutate(id = "itens_2025")


# ITENS ------------------------------------------------------------------------

# APÓS FILTRAR
itens_filtrados <- bind_rows(itens_2024_filtrado, itens_2025_filtrado)

# SALVA ------------------------------------------------------------------------

saveRDS(itens_filtrados, PATH_ITENS)
