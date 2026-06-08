#' Monta uma requisição para a API do Compras no módulo de contratações.
#'
#' Módulo de contratações: https://dadosabertos.compras.gov.br/swagger-ui/index.html#/07%20-%20CONTRATA%C3%87%C3%95ES
#'
#' @param host URL base da API(host).
#' @param basepath Caminho base do módulo da API (modulo-contratacoes).
#' @param endpoint Endpoint específico a ser acessado.
#' @param params Lista de parâmetros de consulta.
#'
#' @return Um objeto de requisição (`httr2_request`).
#'
request_modulo_compras <- function(host = "https://dadosabertos.compras.gov.br",
                                   modulo,
                                   endpoint,
                                   params = list()) {
  req <- request(host) |>
    req_url_path_append(modulo) |>
    req_url_path_append(endpoint)

  if (length(params) <= 0) stop("A lista de parâmetros de consulta deve ser fornecida como uma lista nomeada.")

  req <- req_url_query(req, !!!params)

  Sys.sleep(.15)

  return(req)
}


#' Coleta dados paginados da API do Compras
#'
#' @param ... Argumentos passados para `request_modulo_compras()`.
#'
#' @return Um `tibble` com os dados coletados.
#'
collect_endpoint_compras <- function(...) {
  tryCatch({

    # requisição e coleta dinâmica dos dados da API
    request_modulo_compras(...) |>
      req_retry(max_tries = 3) |>
      req_throttle(capacity = 100, fill_time_s = 60) |> # 100 requisições em 60 segundos
      req_perform() |>
      resp_body_json(simplifyVector = TRUE) |>
      as_tibble()

  }, error = function(e) {
    if (inherits(e, "httr2_http")) {
      warning(sprintf("HTTP error: %s", e$message), call. = FALSE, immediate. = TRUE)
    } else if (inherits(e, "jsonlite_error")) {
      warning(sprintf("JSON parse error: %s", e$message), call. = FALSE, immediate. = TRUE)
    } else {
      warning(sprintf("Unexpected error: %s", e$message), call. = FALSE, immediate. = TRUE)
    }
    tibble()
  })
}


normaliza_tipos_compras <- function(df) {
  colunas_character <- c(
    "numeroControlePNCP",
    "perc",
    "idCompra",
    "idCompraItem",
    "idContratacaoPNCP",
    "unidadeOrgaoCodigoUnidade",
    "orgaoEntidadeCnpj",
    "descricaoResumida",
    "materialOuServico",
    "materialOuServicoNome",
    "descricaodetalhada",
    "unidadeMedida",
    "itemCategoriaNome",
    "criterioJulgamentoNome",
    "situacaoCompraItem",
    "situacaoCompraItemNome",
    "tipoBeneficio",
    "tipoBeneficioNome",
    "codFornecedor",
    "nomeFornecedor",
    "dataInclusaoPncp",
    "dataAtualizacaoPncp",
    "dataResultado",
    "codigoNCM",
    "descricaoNCM",
    "numeroControlePNCPCompra"
  )

  colunas_integer <- c(
    "lot",
    "numeroItemPncp",
    "numeroItemCompra",
    "numeroGrupo",
    "codigoClasse",
    "codigoGrupo",
    "codItemCatalogo",
    "itemCategoriaIdPncp",
    "criterioJulgamentoIdPncp",
    "compras_totalRegistros",
    "compras_totalPaginas",
    "compras_paginasRestantes"
  )

  colunas_double <- c(
    "quantidade",
    "valorUnitarioEstimado",
    "valorTotal",
    "quantidadeResultado",
    "valorUnitarioResultado",
    "valorTotalResultado",
    "percentualMargemPreferenciaNormal",
    "percentualMargemPreferenciaAdicional"
  )

  colunas_logical <- c(
    "orcamentoSigiloso",
    "incentivoProdutivoBasico",
    "temResultado",
    "margemPreferenciaNormal",
    "margemPreferenciaAdicional"
  )

  df |>
    mutate(
      across(any_of(colunas_character), as.character),
      across(any_of(colunas_integer), as.integer),
      across(any_of(colunas_double), as.double),
      across(any_of(colunas_logical), as.logical)
    )
}

# EXEMPLO:
# idCompra: 98683505900092026
# idCompraItem: 9868350590009202600003
# numeroControlePNCP: 46189718000179-1-000038/2026
# numeroItem 3

"https://dadosabertos.compras.gov.br/modulo-contratacoes/2.1_consultarItensContratacoes_PNCP_14133_Id?tipo=numeroControlePNCPCompra&codigo=46189718000179-1-000038%2F2026"

# request_modulo_compras(params = list(tipo = "numeroControlePNCPCompra", codigo= "46189718000179-1-000038/2026"))

# collect_endpoint_compras(params = list(tipo = "numeroControlePNCPCompra", codigo = "46189718000179-1-000038/2026")) |>
collect_endpoint_compras(params = list(tipo = "numeroControlePNCPCompra", codigo = "32556060000181-1-000006/2026")) |>
   glimpse()
