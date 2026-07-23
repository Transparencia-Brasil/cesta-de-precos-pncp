# LIBRARY ----------------------------------------------------------------------
library(tidyverse)
library(here)


# INPUTS -----------------------------------------------------------------------

# dados do banco de dados
PATH_BD <- here("tasks/verifica-descontos/src/extrair-dados-do-banco.R")

# dados legados (onde estão as colunas de desconto)
PATH_RESULTADOS = here("tasks/indicadores-MEL/inputs/resultados.rds")


# OUTPUTS ----------------------------------------------------------------------
PATH_DESCONTOS_RESULTADOS <- here("tasks/verifica-descontos/outputs/item_homologado.csv")


# CARREGAR DADOS ---------------------------------------------------------------

# dados do banco de dados
source(PATH_BD)

# dados legados
resultados <- read_rds(PATH_RESULTADOS)


# SANITIZAÇÃO DE DADOS ---------------------------------------------------------

# seleciona colunas
descontos_legados <- resultados |>
  transmute(
    numero_controle_pncp = as.character(numeroControlePNCPCompra),
    numero_item = as.integer(numeroItem),
    aplicacao_beneficio_me_epp = aplicacaoBeneficioMeEpp,
    aplicacao_margem_preferencia = aplicacaoMargemPreferencia,
    amparo_legal_margem_preferencia_id = amparoLegalMargemPreferencia.id,
    amparo_legal_margem_preferencia_nome = amparoLegalMargemPreferencia.nome,
    amparo_legal_margem_preferencia_descricao = amparoLegalMargemPreferencia.descricao,
    aplicacao_criterio_desempate = aplicacaoCriterioDesempate,
    amparo_legal_criterio_desempate_id = amparoLegalCriterioDesempate.id,
    amparo_legal_criterio_desempate_nome = amparoLegalCriterioDesempate.nome,
    amparo_legal_criterio_desempate_descricao = amparoLegalCriterioDesempate.descricao,
    percentual_desconto = round(as.double(percentualDesconto), 2),
    sequencialResultado = as.integer(sequencialResultado),
    dataAtualizacao = as_datetime(dataAtualizacao)
  ) |>
  distinct()

# remove duplicadas pegando o sequencial mínimo (é o que o PNCP faz em seu site)
descontos_legados <- descontos_legados |>
  group_by(numero_controle_pncp, numero_item) |>
  filter(sequencialResultado == min(sequencialResultado)) |>
  ungroup() |>
  select(-sequencialResultado)

# remove duplicadas pegando a data de atualização mais recente (é o que o PNCP faz em seu site)
descontos_legados <- descontos_legados |>
  group_by(numero_controle_pncp, numero_item) |>
  filter(dataAtualizacao == max(dataAtualizacao)) |>
  ungroup() |>
  select(-dataAtualizacao) |>
  distinct()

# ids dos itens homologados no banco de dados
item_homologado_ids <- item_homologado |>
  distinct(numero_controle_pncp, numero_item)

# JOIN -------------------------------------------------------------------------

item_homologado_descontos <- item_homologado_ids |>
  left_join(descontos_legados)

# Zerou aí?
nrow(item_homologado_ids) - nrow(item_homologado_descontos) # 0, ok

# inspecionar os dados
item_homologado_descontos |>
  count(
    aplicacao_beneficio_me_epp,
    aplicacao_margem_preferencia,
    amparo_legal_margem_preferencia_id,
    amparo_legal_margem_preferencia_nome,
    amparo_legal_margem_preferencia_descricao,
    aplicacao_criterio_desempate,
    amparo_legal_criterio_desempate_id,
    amparo_legal_criterio_desempate_nome,
    amparo_legal_criterio_desempate_descricao,
    percentual_desconto
  ) |>
  View()


# SALVAR RESULTADOS ------------------------------------------------------------

write_csv(item_homologado_descontos, PATH_DESCONTOS_RESULTADOS)
