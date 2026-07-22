# LIBRARY ----------------------------------------------------------------------
library(tidyverse)
library(here)


# INPUTS -----------------------------------------------------------------------

# dados do banco de dados
PATH_BD <- here("tasks/verifica-descontos/src/extrair-dados-do-banco.R")

# dados legados (onde estão as colunas de desconto)
PATH_MEDICAMENTOS = here("tasks/indicadores-MEL/inputs/medicamentos.rds")


# OUTPUTS ----------------------------------------------------------------------
PATH_DESCONTOS_MEDICAMENTOS <- here("tasks/verifica-descontos/outputs/item_licitado.csv")


# CARREGAR DADOS ---------------------------------------------------------------

# dados do banco de dados
source(PATH_BD)

# dados legados
medicamentos <- read_rds(PATH_MEDICAMENTOS)


# SANITIZAÇÃO DE DADOS ---------------------------------------------------------

# seleciona colunas
descontos_legados <- medicamentos |>
  transmute(
    numero_controle_pncp = as.character(data.numeroControlePNCP),
    numero_item = as.integer(numeroItem),
    # tipo_beneficio = tipoBeneficio,
    # tipo_beneficio_nome = tipoBeneficioNome,
    incentivo_produtivo_basico = as.character(incentivoProdutivoBasico), #*
    exigencia_conteudo_nacional = as.character(exigenciaConteudoNacional), #*
    aplicabilidade_margem_preferencia_normal = as.character(aplicabilidadeMargemPreferenciaNormal), #*
    aplicabilidade_margem_preferencia_adicional = as.character(aplicabilidadeMargemPreferenciaAdicional), #*
    percentual_margem_preferencia_normal = as.character(percentualMargemPreferenciaNormal), #*
    percentual_margem_preferencia_adicional = as.character(percentualMargemPreferenciaAdicional), #*
    # tipo_margem_preferencia = as.character(tipoMargemPreferencia), #*
    tipo_margem_preferencia_codigo = as.integer(tipoMargemPreferencia.codigo), #*
    tipo_margem_preferencia_nome = as.character(tipoMargemPreferencia.nome) #*
  ) |>
  distinct()

# normaliza colunas booleanas
vars_bool <- c(
  "incentivo_produtivo_basico",
  "exigencia_conteudo_nacional",
  "aplicabilidade_margem_preferencia_normal",
  "aplicabilidade_margem_preferencia_adicional"
)

# normalização geral das colunas booleanas
descontos_legados <- descontos_legados |>
  mutate(across(all_of(vars_bool), ~ str_remove(.x, "[:punct:]+"))) |>
  mutate(across(all_of(vars_bool), ~ str_to_sentence(.x))) |>
  mutate(across(all_of(vars_bool), ~ str_squish(.x))) |>
  mutate(across(all_of(vars_bool), ~ na_if(.x, "")))

# normalização específica das colunas:
# - exigencia_conteudo_nacional
# - tipo_margem_preferencia_codigo
# - tipo_margem_preferencia_nome
descontos_legados <- descontos_legados |>
  mutate(
    pivot = exigencia_conteudo_nacional,
    exigencia_conteudo_nacional = case_when(
      # pivot == ",\"2\",\"resolução cics\"" ~ "False",
      pivot == "2\",\"resolução cics\"" ~ "False",
      pivot == "False1,resolução ciia-pac" ~ "False",
      pivot == "False2,resolução ciia-pac" ~ "False",
      pivot == "False1,resolução cics" ~ "False",
      pivot == "False2,resolução cics" ~ "False",
      pivot == "True1,resolução ciia-pac" ~ "True",
      pivot == "True2,resolução ciia-pac" ~ "True",
      pivot == "True1,resolução cics" ~ "True",
      pivot == "True2,resolução cics" ~ "True",
      .default = exigencia_conteudo_nacional
    ),
    tipo_margem_preferencia_codigo = case_when(
      pivot == "2\",\"resolução cics\"" ~ 2L,
      pivot == "False1,resolução ciia-pac" ~ 1L,
      pivot == "False2,resolução ciia-pac" ~ 2L,
      pivot == "False1,resolução cics" ~ 1L,
      pivot == "False2,resolução cics" ~ 2L,
      pivot == "True1,resolução ciia-pac" ~ 1L,
      pivot == "True2,resolução ciia-pac" ~ 2L,
      pivot == "True1,resolução cics" ~ 1L,
      pivot == "True2,resolução cics" ~ 2L,
      .default = tipo_margem_preferencia_codigo
    ),
    tipo_margem_preferencia_nome = case_when(
      pivot == "2\",\"resolução cics\"" ~ "Resolução CICS",
      pivot == "False1,resolução cics" ~ "Resolução CICS",
      pivot == "False2,resolução cics" ~ "Resolução CICS",
      pivot == "False1,resolução ciia-pac" ~ "Resolução CIIA-PAC",
      pivot == "False2,resolução ciia-pac" ~ "Resolução CIIA-PAC",
      pivot == "True1,resolução cics" ~ "Resolução CICS",
      pivot == "True2,resolução cics" ~ "Resolução CICS",
      pivot == "True1,resolução ciia-pac" ~ "Resolução CIIA-PAC",
      pivot == "True2,resolução ciia-pac" ~ "Resolução CIIA-PAC",
      .default = tipo_margem_preferencia_nome
    )
  )


# ids dos itens homologados no banco de dados
item_homologado_ids <- item_homologado |>
  distinct(numero_controle_pncp, numero_item)


# JOIN -------------------------------------------------------------------------

item_homologado_descontos <- left_join(item_homologado_ids, descontos_legados)

# remove pivot e duplicadas
item_homologado_descontos <- item_homologado_descontos |>
  select(-pivot) |>
  distinct()

# Outras duplicadas precisam de "fill" para serem removidas
item_homologado_descontos <- item_homologado_descontos |>
  group_by(numero_controle_pncp, numero_item) |>
  fill(everything(), .direction = "downup") |>
  ungroup() |>
  distinct()

# Uma específica precisa sair à fórceps
item_homologado_descontos <- item_homologado_descontos |>
  filter(!(
    numero_controle_pncp == "04005179000120-1-000021/2025" &
      aplicabilidade_margem_preferencia_normal == "False"
  ))

# Zerou aí?
nrow(item_homologado_ids) - nrow(item_homologado_descontos) # 0, ok

# inspecionar os dados
item_homologado_descontos |>
  count(
    incentivo_produtivo_basico,
    exigencia_conteudo_nacional,
    aplicabilidade_margem_preferencia_normal,
    aplicabilidade_margem_preferencia_adicional,
    percentual_margem_preferencia_normal,
    percentual_margem_preferencia_adicional,
    tipo_margem_preferencia_codigo,
    tipo_margem_preferencia_nome
  ) |>
  View()


# SALVAR RESULTADOS ------------------------------------------------------------

write_csv(item_homologado_descontos, PATH_DESCONTOS_MEDICAMENTOS)
