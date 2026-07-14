library(tidyverse)
library(here)
library(httr2)


# :: FILEPATHS -----------------------------------------------------------------

# Funções auxiliares
source(here("tasks/api-compras/src/R/utils.R"))

PATH_ITEM_HOMOLOGADO_COMPRAS <- here("tasks/api-compras/inputs/item-homologado-compras.rds")

PATH_ITEM_HOMOLOGADO_COMPRAS_COM_IDS <- here("tasks/api-compras/inputs/item-homologado-compras-com-ids.rds")

PATH_ITEM_HOMOLOGADO_SEM_RETORNO <- here("tasks/api-compras/inputs/item-homologado-compras-sem-retorno.rds")

CONTRATACOES_COMPRAS <- here("tasks/api-compras/tmp/2.1_consultarItensContratacoes_PNCP_14133_Id")


# :: LOAD-DATA -----------------------------------------------------------------

# Itens homologados (MT)
item_homologado_compras <- readRDS(PATH_ITEM_HOMOLOGADO_COMPRAS) |>
  as_tibble() |>
  rename(
    numeroControlePNCP = numeroControlePNCP,
    numeroItemPncp = numeroItem,
    codItemCatalogoProducao = codigoItemCatalogo,
    codFornecedor = ni_fornecedor
  )

# Contratações dos itens homologados (MT) coletadas no compras
contratacoes_compras <- arrow::open_dataset(CONTRATACOES_COMPRAS) |>
  select(
    numeroControlePNCP,
    idCompra,
    idCompraItem,
    codFornecedor,
    numeroItemPncp,
    numeroItemCompra,
    codItemCatalogo,
    descricaoResumida,
    descricaodetalhada,
    unidadeMedida
  ) |>
  collect() |>
  mutate(across(where(is.character), \(x) str_squish(x))) |>
  distinct()


# :: RESULTS -------------------------------------------------------------------

# Itens homologados com contratações no compras - resultado final
item_homologado_compras_com_ids <- contratacoes_compras |>
  inner_join(item_homologado_compras) |>
  distinct()

# Itens homologados sem contratações no compras - resultado final
sem_retorno <- anti_join(item_homologado_compras, item_homologado_compras_com_ids)


# :: SALVA ---------------------------------------------------------------------

saveRDS(item_homologado_compras_com_ids, PATH_ITEM_HOMOLOGADO_COMPRAS_COM_IDS)
saveRDS(sem_retorno, PATH_ITEM_HOMOLOGADO_SEM_RETORNO)
