
library(tidyverse)
library(here)
library(DBI)


source(here("src/ETL/loaders/utils.R"))

PATH_ITEM_HOMOLOGADO_COMPRAS_COM_IDS <- here("tasks/api-compras/inputs/item-homologado-compras-com-ids.rds")
PATH_CONSULTAR_MATERIAL <- here("tasks/api-compras/tmp/1_consultarMaterial/consultar-material.rds")

itens <- readRDS(PATH_ITEM_HOMOLOGADO_COMPRAS_COM_IDS)
marcas <- readRDS(PATH_CONSULTAR_MATERIAL)

itens <- itens |>
  rename(
    numero_controle_pncp = numeroControlePNCP,
    numero_item = numeroItemPncp,
    ni_fornecedor = codFornecedor,
    codigoItemCatalogo = codItemCatalogo
  )


marcas <- marcas |>
  transmute(
    idCompra,
    idCompraItem,
    ni_fornecedor = codFornecedor,
    codigoItemCatalogo,
    numeroItemCompra,
    marca,
    dataHoraAtualizacaoItem = as_datetime(dataHoraAtualizacaoItem)
  ) |>
  distinct() |>
  group_by(idCompra, idCompraItem, ni_fornecedor, numeroItemCompra, codigoItemCatalogo) |>
  filter(dataHoraAtualizacaoItem == max(dataHoraAtualizacaoItem)) |>
  glimpse()

itens |>
  left_join(marcas) |>
  distinct() |>
  add_count(idCompra, idCompraItem, ni_fornecedor, numeroItemCompra, codigoItemCatalogo) |>
  filter(n > 1)  |>
  View()
  glimpse()
