
library(tidyverse)
library(here)
library(DBI)

source(here("src/ETL/loaders/utils.R"))


# :: FILE PATHS ----------------------------------------------------------------

PATH_ITEM_HOMOLOGADO <- here("tasks/api-compras/inputs/item-homologado.rds")
PATH_ITEM_HOMOLOGADO_COMPRAS_COM_IDS <- here("tasks/api-compras/inputs/item-homologado-compras-com-ids.rds")
PATH_CONSULTAR_MATERIAL <- here("tasks/api-compras/tmp/1_consultarMaterial/consultar-material.rds")

PATH_TABELA_MARCAS <- here("tasks/api-compras/outputs/tabela-marcas.rds")

# :: LOAD DATA -----------------------------------------------------------------

itens_bd <- readRDS(PATH_ITEM_HOMOLOGADO)
itens <- readRDS(PATH_ITEM_HOMOLOGADO_COMPRAS_COM_IDS)
marcas <- readRDS(PATH_CONSULTAR_MATERIAL)


# :: TABELA DE ITENS - BANCO DE DADOS MT ---------------------------------------

# somente com IDs PNCP
itens_bd <- itens_bd |>
  mutate(data_resultado = as_date(data_resultado)) |>
  rename(
    numero_controle_pncp = numeroControlePNCP,
    numero_item = numeroItem,
    codigo_item_catalogo = codigoItemCatalogo
  )


# :: TABELA DE ITENS - COM IDS DO COMPRAS.GOV ----------------------------------

# Com IDs do PNCP e IDs do compras.gov, mas sem marca
de_para <- itens |>
  select(
    numero_controle_pncp = numeroControlePNCP,
    numero_item = numeroItemPncp,
    codigo_item_catalogo = codItemCatalogoProducao,
    ni_fornecedor = codFornecedor,
    idCompra = idCompra,
    idCompraItem = idCompraItem,
    codigoItemCatalogo_itens = codItemCatalogo
  ) |>
  inner_join(itens_bd) |>
  mutate(
    valor_unitario_homologado = round(valor_unitario_homologado, 3),
    quantidade_homologada = round(quantidade_homologada, 3)
  )


# :: TABELA DE MARCAS - COM IDS DO COMPRAS.GOV ----------------------------------

# Somente IDs do compras.gov, com marca
marcas_de_para <- marcas |>
  transmute(
    idCompra = idCompra,
    idCompraItem = idCompraItem,
    ni_fornecedor = codFornecedor,
    codigoItemCatalogo_marcas = codigoItemCatalogo,
    quantidade_homologada = round(quantidade, 3),
    valor_unitario_homologado = round(precoUnitario, 3),
    marca = marca,
    data_resultado = as_date(dataResultado),
    descricaoDetalhadaItem = descricaoDetalhadaItem,
    siglaUnidadeFornecimento = siglaUnidadeFornecimento,
    nomeUnidadeFornecimento = nomeUnidadeFornecimento,
    siglaUnidadeMedida = siglaUnidadeMedida,
    nomeUnidadeMedida = nomeUnidadeMedida,
  ) |>
  distinct()

glimpse(marcas_de_para)


# :: JOIN DE TABELAS -----------------------------------------------------------

# JOIN FORTE: de_para + marcas_de_para
# Com o máximo de chaves possíveis
keys_join_forte <- c(
  "ni_fornecedor",
  "idCompra",
  "idCompraItem",
  "valor_unitario_homologado",
  "quantidade_homologada",
  "data_resultado"
)

# JOIN NÃO TÃO FORTE: de_para + marcas_de_para
# Com menos chaves, mas ainda assim com algumas chaves de valor unitário e quantidade
keys_join_nao_tao_forte <- c(
  "ni_fornecedor",
  "idCompra",
  "idCompraItem",
  "valor_unitario_homologado",
  "quantidade_homologada"
)

# JOIN MÉDIO: de_para + marcas_de_para
# Com menos chaves, sem chaves de valor unitário e quantidade
keys_join_medio <- c(
  "ni_fornecedor",
  "idCompra",
  "idCompraItem"
)

# Join mais forte

join_forte <- de_para |>
  left_join(marcas_de_para, by = keys_join_forte) |>
  filter(!is.na(marca))

# Join não tão forte

join_nao_tao_forte <- de_para |>
  anti_join(join_forte) |>
  left_join(
    select(marcas_de_para, -data_resultado),
    by = keys_join_nao_tao_forte
  ) |>
  filter(!is.na(marca))

# Bind rows dos dois joins anteriores

joins <- bind_rows(
  join_forte,
  join_nao_tao_forte
)

# Join médio

join_medio <- de_para |>
  anti_join(joins) |>
  left_join(
    select(marcas_de_para, -data_resultado, -valor_unitario_homologado, -quantidade_homologada),
    by = keys_join_medio
  ) |>
  filter(!is.na(marca)) |>
  distinct()

# Bind rows dos três joins anteriores
joins <- bind_rows(
  join_forte,
  join_nao_tao_forte,
  join_medio
)

tabela_marcas <- joins |>
  select(
    numero_controle_pncp,
    numero_item,
    ni_fornecedor,
    codigo_item_catalogo,
    id_compra = idCompra,
    id_compra_item = idCompraItem,
    codigo_item_catalogo_tbl_itens = codigoItemCatalogo_itens,
    codigo_item_catalogo_tbl_marcas = codigoItemCatalogo_marcas,
    quantidade_homologada,
    valor_unitario_homologado,
    marca,
    descricao_detalhada_item = descricaoDetalhadaItem,
    sigla_unidade_fornecimento = siglaUnidadeFornecimento,
    nome_unidade_fornecimento = nomeUnidadeFornecimento,
    sigla_unidade_medida = siglaUnidadeMedida,
    nome_unidade_medida = nomeUnidadeMedida,
  )

saveRDS(tabela_marcas, PATH_TABELA_MARCAS)
write_csv(tabela_marcas, here("tasks/api-compras/outputs/tabela-marcas.csv"))
