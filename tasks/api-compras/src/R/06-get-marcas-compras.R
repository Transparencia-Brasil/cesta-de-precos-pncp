library(tidyverse)
library(here)
library(httr2)


source(here("tasks/api-compras/src/R/utils.R"))
PATH_ITEM_HOMOLOGADO_COMPRAS_COM_IDS <- here("tasks/api-compras/inputs/item-homologado-compras-com-ids.rds")

ENDPOINT <- "1_consultarMaterial"

MODULO <- "modulo-pesquisa-preco"

PATH_TMP <- here("tasks/api-compras/tmp/", ENDPOINT)

dir.create(PATH_TMP, recursive = TRUE, showWarnings = FALSE)

PATH_CONSULTAR_MATERIAL <-  file.path(PATH_TMP, "consultar-material.rds")


# :: LOAD DATA -----------------------------------------------------------------

item_homologado_compras_com_ids <- readRDS(PATH_ITEM_HOMOLOGADO_COMPRAS_COM_IDS) |>
  transmute(
    idCompra = idCompra,
    codItemCatalogo = coalesce(codItemCatalogo, codItemCatalogoProducao),
    numeroItemPncp = numeroItemPncp,
    numeroItemCompra = numeroItemCompra,
    codFornecedor = codFornecedor,
  ) |>
  distinct()


# :: CRIA LOTES ----------------------------------------------------------------

lotes_item_homologado_compras_com_ids <- item_homologado_compras_com_ids |>
  nest(.by = c(idCompra, codItemCatalogo)) |>
  mutate(lot = ceiling(row_number() / 1000)) |>
  nest(.by = lot)


# :: COLETA --------------------------------------------------------------------

res <- map(
  seq(from = 1, nrow(lotes_item_homologado_compras_com_ids)),
  ~ coleta_compras_em_lotes_safely(.x, lotes_item_homologado_compras_com_ids, ENDPOINT, MODULO),
  .progress = TRUE
)


# :: CHECKPOINT ----------------------------------------------------------------

# baixou - salva!
saveRDS(res, file.path(PATH_TMP, "resultado.rds"))

# salvou - carrega!
res <- readRDS(file.path(PATH_TMP, "resultado.rds"))


# :: DESANINHA DADOS COLETADOS -------------------------------------------------

res <- res |>
  map(enframe) |>
  map(pivot_wider) |>
  map(unnest, cols = c(error, status_lote, mensagem_erro_lote), keep_empty = TRUE) |>
  enframe() |>
  unnest(cols = c(value), keep_empty = TRUE) |>
  unnest(result, keep_empty = TRUE)

res <- res |>
  select(idCompra_char = idCompra, compras) |>
  unnest(compras) |>
  unnest(resultado) |>
  mutate(idCompra = idCompra_char) |>
  select(-idCompra_char) |>
  glimpse()


# :: RETORNO -------------------------------------------------------------------

res_final <- item_homologado_compras_com_ids |>
  mutate(flag = "mt") |>
  inner_join(res) |>
  glimpse()

saveRDS(res_final, PATH_CONSULTAR_MATERIAL)
readRDS(PATH_CONSULTAR_MATERIAL)


# :: E OS DADOS NÃO COLETADOS? -------------------------------------------------

residuais <- anti_join(item_homologado_compras_com_ids, res_final)

# recoleta
lote_residual <- residuais |>
  nest(.by = c(idCompra, codItemCatalogo)) |>
  mutate(lot = ceiling(row_number() / 1000)) |>
  nest(.by = lot)

lote_residual <- map(
  seq(from = 1, nrow(lote_residual)),
  ~ coleta_compras_em_lotes_safely(.x, lote_residual, ENDPOINT, MODULO),
  .progress = TRUE
)


# :: CHECKPOINT ----------------------------------------------------------------

PATH_LOTE_RESIDUAL <- here("tasks/api-compras/inputs/item-homologado-compras-com-ids-lote-residual.rds")

saveRDS(lote_residual, PATH_LOTE_RESIDUAL)
readRDS(PATH_LOTE_RESIDUAL)


# :: REPOSIÇÃO DE DADOS RECOLETADOS --------------------------------------------

lote_residual <- readRDS(PATH_LOTE_RESIDUAL)

consulta_material <- readRDS(PATH_CONSULTAR_MATERIAL)

lote_residual <- lote_residual |>
  map(enframe) |>
  map(pivot_wider) |>
  map(unnest, cols = c(
    result, error, status_lote, mensagem_erro_lote
  )) |>
  map_df(unnest, compras, keep_empty = TRUE)

sucesso <- lote_residual |>
  filter(status_lote == "sucesso") |>
  select(idCompra_char = idCompra, data, resultado, totalRegistros, totalPaginas, paginasRestantes) |>
  unnest(resultado) |>
  filter(!is.na(idCompra)) |>
  mutate(idCompra = idCompra_char) |>
  select(-idCompra_char) |>
  mutate(data = map(data, ~select(.x, -numeroItemCompra))) |>
  unnest(data) |>
  mutate(flag = "mt-recoleta") |>
  distinct()

consulta_material <- consulta_material |>
  bind_rows(sucesso)

consulta_material |>
  filter(numeroItemPncp == numeroItemCompra)

saveRDS(consulta_material, PATH_CONSULTAR_MATERIAL)
readRDS(PATH_CONSULTAR_MATERIAL)
