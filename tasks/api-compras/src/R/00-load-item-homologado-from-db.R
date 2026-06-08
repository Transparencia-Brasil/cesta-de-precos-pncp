
library(tidyverse)
library(here)
library(DBI)


source(here("src/ETL/loaders/utils.R"))

# CONECTA-SE  COM O BD ----------------------------------------------------

con <- conecta_bd_medicamentos_transparentes()

get_query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")

item_homologado <- get_query("
  select
  numero_controle_pncp,
  numero_item,
  codigo_item_catalogo
  from item_homologado
") |>
  rename(
    numeroControlePNCP = numero_controle_pncp,
    numeroItem = numero_item,
    codigoItemCatalogo = codigo_item_catalogo
  )

saveRDS(item_homologado, here("tasks/api-compras/inputs/item-homologado.rds"))
