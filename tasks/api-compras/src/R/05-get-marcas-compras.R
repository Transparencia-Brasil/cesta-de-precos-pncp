library(tidyverse)
library(here)
library(httr2)


source(here("tasks/api-compras/src/R/utils.R"))
PATH_ITEM_HOMOLOGADO_COMPRAS_COM_IDS <- here("tasks/api-compras/inputs/item-homologado-compras-com-ids.rds")

ENDPOINT <- "1_consultarMaterial"

MODULO <- "modulo-pesquisa-preco"

PATH_TMP <- here("tasks/api-compras/tmp/", ENDPOINT)

dir.create(PATH_TMP, recursive = TRUE, showWarnings = FALSE)


item_homologado_compras_com_ids <- readRDS(PATH_ITEM_HOMOLOGADO_COMPRAS_COM_IDS) |>
  transmute(
    idCompra = idCompra,
    codItemCatalogo = coalesce(codItemCatalogo, codItemCatalogoProducao),
    numeroItemPncp = numeroItemPncp,
    numeroItemCompra = numeroItemCompra
  ) |>
  distinct()

lotes_item_homologado_compras_com_ids <- item_homologado_compras_com_ids |>
  nest(.by = c(idCompra, codItemCatalogo)) |>
  mutate(lot = ceiling(row_number() / 500)) |>
  nest(.by = lot)

coleta_em_lotes <- function(lote, df, endpoint, modulo) {

  msg <- sprintf("Coletando lote %s", lote)
  flush.console()
  cat(msg, "\r")

  df <- df |>
    filter(lot == lote)

  df <- df |>
    unnest(data)

  df <- df |>
    mutate(compras = map2(idCompra, codItemCatalogo,
      ~ collect_endpoint_compras(
        modulo = modulo,
        endpoint = endpoint,
        params = list(
          idCompra = .x,
          codigoItemCatalogo = .y
        )
    )))
  # Sys.sleep(60) # Pausa de 60 segundos entre os lotes para evitar sobrecarga na API
  df
}

coleta_em_lotes_safely <- safely(coleta_em_lotes)

res <- map(
  seq(from = 1, to = nrow(lotes_item_homologado_compras_com_ids[1,])),
  ~ coleta_em_lotes_safely(.x, lotes_item_homologado_compras_com_ids[1,], ENDPOINT, MODULO),
  .progress = TRUE
)

res

map_df(res, "result") |>
  filter(map_int(compras, nrow) > 0) |>
  unnest(compras, names_sep = "_") |>
  filter(compras_totalRegistros == 2) |>
  slice(1) |>
  # unnest(compras_resultado, names_sep = "_") |>
  glimpse()

map_df(res2, "result") |>
  filter(idCompra == "98765305900192024") |>
  unnest(compras, names_sep = "_") |>
  unnest(compras_resultado, names_sep = "_") |>
  distinct() |>
  glimpse()

options(width = 150)

dt <- arrow::open_dataset(PATH_TMP) |>
  collect() |>
  glimpse()

"https://dadosabertos.compras.gov.br/modulo-pesquisa-preco/1_consultarMaterial?pagina=1&tamanhoPagina=10&codigoItemCatalogo=463692&dataResultado=false"
