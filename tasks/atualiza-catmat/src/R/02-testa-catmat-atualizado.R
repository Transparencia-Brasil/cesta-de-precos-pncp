#' Este script SIMULA a inserção dos dados do catálogo de itens no banco de dados configurado.
#'
#' O parâmetro de entrada obrigatório é o caminho para o arquivo do catálogo em
#' formato .rds.
#'
#' O catálogo foi obtido a partir da seguinte API:
#' https://cnbs.estaleiro.serpro.gov.br/cnbs-api/swagger-ui/index.html#/
#'
#' Utilizando o seguinte script:
#' https://github.com/Transparencia-Brasil/cesta-de-precos-pncp/tasks/atualiza-catmat/src/R/00-coleta-catmat-com-cnbs.R
#'

library(tidyverse)
library(here)
library(jsonlite)
library(DBI)

source(here("tasks/atualiza-catmat/src/R/utils.R"))


# LÊ ARQUIVOS  ------------------------------------------------------------

# Lê os argumentos
CAMINHO_CATALOGO <- here("tasks/atualiza-catmat/outputs/catalogo-atualizado.rds")

# Lê os arquivos de dados
catalogo <- readRDS(CAMINHO_CATALOGO) |>
  mutate(codigo_br = as.character(codigo_br))

mapeamento_caracteristicas_ocds <- le_mapeamento_caracteristicas_ocds()


# SELECIONA CARACTERÍSTICAS DOS MEDICAMENTOS ------------------------------

# Número máximo de características a manter por medicamento (por PDM)
MAX_CARACTERISTICAS = 3

# Desaninha a coluna "buscaItemCaracteristica"
catalogo <- catalogo %>% unnest(buscaItemCaracteristica)

# Cria um  dataframe com as caracteristicas que serão mantidas para cada medicamento
caracteristicas <- catalogo %>%
  # Agrupa por PDM e codigoCaracteristica
  group_by(codigo_pdm, codigoCaracteristica) %>%
  # Conta valores únicos para cada característica dentro de cada PDM
  summarise(n_valores_unicos = n_distinct(nomeValorCaracteristica),
            .groups = "drop") %>%
  # Agrupa por PDM
  group_by(codigo_pdm) %>%
  # Seleciona as (MAX_CARACTERISTICAS) características com mais valores distintos
  slice_max(n = MAX_CARACTERISTICAS,
            order_by = n_valores_unicos,
            with_ties = FALSE) %>%
  # remove características com apenas 1 valor distinto
  filter(n_valores_unicos > 1) %>%
  # Adiciona uma flag: Devemos manter essa caracteristica?
  mutate(manter = TRUE) %>%
  select(-n_valores_unicos)

# Marca no catálogo as caracteristicas que serão utilizadas (manter == TRUE)
catalogo <- catalogo %>%
  left_join(caracteristicas, by = c("codigo_pdm", "codigoCaracteristica"))


# Reaninha as características dentro do catálogo
# Reaninha antes de excluir as características para não correr o risco de excluir
# medicamentos que possuam apenas uma característica com um único valor.
# Exemplo: Hidróxido De Alumínio, Indicação:300mg (codigo br: 267271)
catalogo <- catalogo %>%
  group_by(codigo_br) %>%
  nest(
    buscaItemCaracteristica = c(
      codigoCaracteristica,
      codigoValorCaracteristica,
      nomeCaracteristica,
      caracteristicaObrigatoria,
      statusCaracteristica,
      numeroCaracteristica,
      nomeValorCaracteristica,
      siglaUnidadeMedida,
      statusValorCaracteristica,
      manter
    )
  ) %>%
  ungroup()

# Filtra as características dentro do dataframe aninhado
catalogo <- catalogo %>%
  mutate(buscaItemCaracteristica = map(buscaItemCaracteristica, ~ filter(.x, manter == TRUE)))

# Integra as características OCDS por codigo_br = codigo_item
catalogo <- adiciona_caracteristicas_ocds(catalogo, mapeamento_caracteristicas_ocds)


# TRANSFORMA A TABELA -----------------------------------------------------

tb_catalogo <- catalogo %>%
  select(all_of(COLUNAS_CATALOGO)) %>%
  mutate( # Seleciona atributos de interesse
    caracteristicas = map(buscaItemCaracteristica, ~ select(.x, nomeCaracteristica, nomeValorCaracteristica))
  ) %>%
  mutate( # transforma as características em um JSON
    caracteristicas = map(caracteristicas, ~ toJSON(.x, auto_unbox = TRUE)),
    unidade_fornecimento = map(unidadeFornecimento, ~ toJSON(.x, auto_unbox = TRUE))
  ) %>%
  mutate( # transforma o JSON em character (string)
    caracteristicas = as.character(caracteristicas),
    unidade_fornecimento = as.character(unidade_fornecimento)
  ) %>%
  select(-buscaItemCaracteristica, -unidadeFornecimento)

# inspeciona a tabela final
tb_catalogo
