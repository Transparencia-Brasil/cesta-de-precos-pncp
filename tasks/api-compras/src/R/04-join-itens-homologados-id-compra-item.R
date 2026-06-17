options(width = 150)
library(tidyverse)
library(here)
library(httr2)


source(here("tasks/api-compras/src/R/utils.R"))
PATH_ITEM_HOMOLOGADO_COMPRAS <- here("tasks/api-compras/inputs/item-homologado-compras.rds")

ENDPOINT <- "1_consultarMaterial"

MODULO <- "modulo-pesquisa-preco"

PATH_TMP <- here("tasks/api-compras/tmp/", ENDPOINT)

dir.create(PATH_TMP, recursive = TRUE, showWarnings = FALSE)

CONTRATACOES_COMPRAS <- here("tasks/api-compras/tmp/2.1_consultarItensContratacoes_PNCP_124133_Id")

item_homologado_compras <- readRDS(PATH_ITEM_HOMOLOGADO_COMPRAS) |>
  as_tibble() |>
  rename(
    numeroControlePNCP = numeroControlePNCP,
    numeroItemPncp = numeroItem,
    codItemCatalogoProducao = codigoItemCatalogo
  )

contratacoes_compras <- arrow::open_dataset(CONTRATACOES_COMPRAS) |>
  select(
    numeroControlePNCP,
    idCompra,
    idCompraItem,
    numeroItemPncp,
    numeroItemCompra,
    codItemCatalogo
  ) |>
  collect()

item_homologado_compras_com_ids <- contratacoes_compras |>
  inner_join(item_homologado_compras) |>
  distinct()

saveRDS(item_homologado_compras_com_ids, here("tasks/api-compras/inputs/item-homologado-compras-com-ids.rds"))
