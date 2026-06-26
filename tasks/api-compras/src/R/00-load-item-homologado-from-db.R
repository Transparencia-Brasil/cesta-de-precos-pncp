
library(tidyverse)
library(here)
library(DBI)


source(here("src/ETL/loaders/utils.R"))

PATH_ITEM_HOMOLOGADO <- here("tasks/api-compras/inputs/item-homologado.rds")

# CONECTA-SE  COM O BD ----------------------------------------------------

con <- conecta_bd_medicamentos_transparentes()

get_query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")

item_homologado <- get_query("
  select
  numero_controle_pncp,
  numero_item,
  codigo_item_catalogo,
  ni_fornecedor,
  valor_unitario_homologado,
  quantidade_homologada,
  from item_homologado
") |>
  rename(
    numeroControlePNCP = numero_controle_pncp,
    numeroItem = numero_item,
    codigoItemCatalogo = codigo_item_catalogo
  )

saveRDS(item_homologado, PATH_ITEM_HOMOLOGADO)
readRDS(PATH_ITEM_HOMOLOGADO)
