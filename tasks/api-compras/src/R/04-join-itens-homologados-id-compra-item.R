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



contratacoes_compras |>
  glimpse()




"https://dadosabertos.compras.gov.br/modulo-pesquisa-preco/1_consultarMaterial?pagina=1&tamanhoPagina=10&codigoItemCatalogo=436169&dataResultado=true&idCompra=98683505900092026"
