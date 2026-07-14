library(tidyverse)
library(here)

CONTRATACOES_PATH <- here("tasks/api-compras/inputs/contratacoes.rds")
ITEM_HOMOLOGADO_PATH <- here("tasks/api-compras/inputs/item-homologado.rds")

contratacoes <- readRDS(CONTRATACOES_PATH) |>
  select(-objetoCompra) |>
  filter(usuarioNome == "Compras.gov.br") |>
  distinct()

item_homologado <- readRDS(ITEM_HOMOLOGADO_PATH)

item_homologado_compras <- inner_join(item_homologado, contratacoes)

saveRDS(item_homologado_compras, here("tasks/api-compras/inputs/item-homologado-compras.rds"))
