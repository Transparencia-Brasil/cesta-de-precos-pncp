library(tidyverse)
library(here)
library(httr2)


# :: FILEPATHS -----------------------------------------------------------------

source(here("tasks/api-compras/src/R/utils.R"))

PATH_ITEM_HOMOLOGADO_SEM_RETORNO <- here("tasks/api-compras/inputs/item-homologado-compras-sem-retorno.rds")

ENDPOINT <- "2.1_consultarItensContratacoes_PNCP_14133_Id"

MODULO <- "modulo-contratacoes"

PATH_TMP <- here("tasks/api-compras/tmp/", ENDPOINT)

dir.create(PATH_TMP, recursive = TRUE, showWarnings = FALSE)


# :: LOAD-DATA -----------------------------------------------------------------

item_homologado_compras <- readRDS(PATH_ITEM_HOMOLOGADO_SEM_RETORNO) |>
  as_tibble()


# :: COLETA --------------------------------------------------------------------

residuais <- item_homologado_compras |>
  mutate(compras = map(
    numeroControlePNCP,
    ~ collect_endpoint_compras(
      modulo = MODULO,
      endpoint = ENDPOINT,
      params = list(
        tipo = "numeroControlePNCPCompra",
        codigo = .x
      )
    )
  ))

residuais <- residuais |>
  filter(map_int(compras, nrow) > 0) |>
  rename(idx = numeroItemPncp) |>
  select(-codFornecedor, -codItemCatalogoProducao, -usuarioNome) |>
  unnest(compras, names_sep = "_") |>
  unnest_wider(compras_resultado) |>
  normaliza_tipos_compras() |>
  filter(numeroItemPncp == idx) |>
  select(-idx) |>
  distinct() |>
  mutate(lot = 100)

# :: RESULTADO -----------------------------------------------------------------

arrow::write_parquet(residuais, file.path(PATH_TMP, "coleta_100.parquet"))
