#' Consulta catálogo CATMAT para PDM específico
#'
#' @param catalogo DataFrame com catálogo CATMAT
#' @param pdm String com nome do PDM a ser filtrado
#' @return Lista com catálogo filtrado e dicionário de características
consulta_catalogo <- function(catalogo, pdm) {
  catalogo <- catalogo %>%
    filter(nome_pdm == pdm) %>%
    unnest(buscaItemCaracteristica)

  dicionario_caracteristica <- catalogo %>%
    distinct(nomeCaracteristica, codigoCaracteristica)

  return(list(catalogo = catalogo, dicionario_caracteristica = dicionario_caracteristica))
}

#' Concatena características múltiplas de cada CATMAT
#'
#' @param med_catalogo Dataframe com características dos medicamentos
#' @return Dataframe com características concatenadas
concatena_caracteristicas_multiplas <- function(med_catalogo) {
  med_catalogo %>%
    group_nest(codigo_br) %>%
    mutate(
      data = map(data, ~ mutate(.x,
        .by = nomeCaracteristica,
        nomeValorCaracteristica = paste0(nomeValorCaracteristica, collapse = ", ")
      )),
      data = map(data, distinct, nomeValorCaracteristica, .keep_all = TRUE)
    ) %>%
    unnest(data)
}

#' Agrupa características de medicamentos do catálogo
#'
#' @param med_catalogo data.frame com dados de medicamentos do catálogo
#' @return data.frame com características agrupadas e filtradas
agrupa_caracteristicas <- function(med_catalogo) {
  med_catalogo %>%
    summarise(
      # Agrupa por PDM e nomeCaracteristica (corrigido manualmente)
      .by = c(codigo_pdm, codigoCaracteristica),
      n_valores_unicos = n_distinct(nomeValorCaracteristica),
    ) %>%
    group_by(codigo_pdm) %>%
    slice_max(n = MAX_CARACTERISTICAS, order_by = n_valores_unicos, with_ties = FALSE) %>%
    # filter(n_valores_unicos > 1) %>%
    mutate(manter = TRUE) %>%
    ungroup()
}

#' Reaninha características dentro do catálogo
#'
#' @description Agrupa características por código_br antes de remover duplicatas para
#' preservar medicamentos com característica única. Reaninha antes de excluir as
#' características para não correr o risco de excluir medicamentos que possuam
#' apenas uma característica com um único valor.
#' Exemplo: Hidróxido De Alumínio, Indicação:300mg (codigo br: 267271)
#'
#' @param med_catalogo Data frame contendo catálogo de medicamentos
#' @return Data frame agrupado por código_br com características aninhadas
reaninha_caracteristicas <- function(med_catalogo) {
  med_catalogo %>%
    select(-n_valores_unicos) %>%
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
}

#' Transforma dados do catálogo para formato compatível com PostgreSQL
#' @param med_catalogo Tabela de catálogo CATMAT
#' @return Tabela processada com características em JSON
transform_catalogo_to_db <- function(med_catalogo) {
  med_catalogo %>%
    select(all_of(COLUNAS_CATALOGO)) %>%
    mutate( # Seleciona atributos de interesse
      características = map(buscaItemCaracteristica, ~ select(.x, nomeCaracteristica, nomeValorCaracteristica))
    ) %>%
    mutate( # transforma as características em um JSON
      características = map(características, ~ toJSON(.x, auto_unbox = TRUE)),
      unidade_fornecimento = map(unidadeFornecimento, ~ toJSON(.x, auto_unbox = TRUE))
    ) %>%
    mutate( # transforma o JSON em character (string)
      características = as.character(características),
      unidade_fornecimento = as.character(unidade_fornecimento)
    ) %>%
    select(-buscaItemCaracteristica, -unidadeFornecimento)
}
