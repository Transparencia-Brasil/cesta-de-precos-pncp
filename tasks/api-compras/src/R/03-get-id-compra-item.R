library(tidyverse)
library(here)
library(httr2)


# :: FILEPATHS -----------------------------------------------------------------

source(here("tasks/api-compras/src/R/utils.R"))
PATH_ITEM_HOMOLOGADO_COMPRAS <- here("tasks/api-compras/inputs/item-homologado-compras.rds")

ENDPOINT <- "2.1_consultarItensContratacoes_PNCP_14133_Id"

MODULO <- "modulo-contratacoes"

PATH_TMP <- here("tasks/api-compras/tmp/", ENDPOINT)

dir.create(PATH_TMP, recursive = TRUE, showWarnings = FALSE)


# :: LOAD-DATA -----------------------------------------------------------------

item_homologado_compras <- readRDS(PATH_ITEM_HOMOLOGADO_COMPRAS) |> as_tibble()


# :: CRIA LOTES ----------------------------------------------------------------

lotes_item_homologado_compras <- item_homologado_compras |>
  nest(.by = numeroControlePNCP) |>
  mutate(
    lot = ceiling(row_number() / 1000)
  ) |>
  nest(.by = lot)


# :: COLETA --------------------------------------------------------------------

walk(
  seq(from = 5, to = nrow(lotes_item_homologado_compras)),
  ~ coleta_em_lotes(.x, lotes_item_homologado_compras, ENDPOINT),
  .progress = TRUE
)


# :: RESULTADO -----------------------------------------------------------------

dt <- arrow::open_dataset(PATH_TMP) |>
  collect() |>
  glimpse()

"https://dadosabertos.compras.gov.br/modulo-contratacoes/2.1_consultarItensContratacoes_PNCP_14133_Id?tipo=idCompra&codigo=98549505900102024"

# EXEMPLO:
# idCompra: 98683505900092026
# idCompraItem: 9868350590009202600003
# numeroControlePNCP: 46189718000179-1-000038/2026
# numeroItem 3
