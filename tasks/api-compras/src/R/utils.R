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
      req_error(body = function(resp) resp_body_string(resp)) |>
      req_perform() |>
      resp_body_json(simplifyVector = TRUE) |>
      as_tibble()

  }, error = function(e) {
    if (inherits(e, "httr2_http")) {
      warning(sprintf("HTTP error: %s", conditionMessage(e)), call. = FALSE, immediate. = TRUE)
    } else if (inherits(e, "jsonlite_error")) {
      warning(sprintf("JSON parse error: %s", conditionMessage(e)), call. = FALSE, immediate. = TRUE)
    } else {
      warning(sprintf("Unexpected error: %s", conditionMessage(e)), call. = FALSE, immediate. = TRUE)
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

#' Coleta dados em lotes a partir de um endpoint da API de compras
#'
#' @param lote Número do lote a ser coletado.
#' @param df Data frame contendo os lotes e os dados a serem coletados.
#' @param endpoint Endpoint específico a ser acessado.
#' @param modulo Módulo da API a ser acessado.
#'
#' @return Data frame com os dados coletados para o lote especificado.
coleta_em_lotes <- function(lote, df, endpoint, modulo) {

  msg <- sprintf("Coletando lote %s", lote)
  flush.console()
  cat(msg, "\r")

  df <- df |>
    filter(lot == lote) |>
    unnest(data) |>
    select(-data)

  df <- df |>
    mutate(compras = map(numeroControlePNCP,
      ~ collect_endpoint_compras(
        modulo = modulo,
        endpoint = endpoint,
        params = list(
          tipo = "numeroControlePNCPCompra",
          codigo = .x
        )
    ))) |>
    filter(map_int(compras, nrow) > 0) |>
    unnest(compras, names_sep = "_") |>
    unnest_wider(compras_resultado) |>
    normaliza_tipos_compras()

  output_file <- file.path(PATH_TMP, paste0("coleta_", lote, ".parquet"))
  arrow::write_parquet(df, output_file)

  Sys.sleep(2) # Pausa de 2 segundos entre os lotes para evitar sobrecarga na API
}


#' Coleta Endpoint de Compras com Status
#'
#' Realiza requisição para endpoint de compras com tratamento de erros e retorna
#' lista com dados, status e mensagens.
#'
#' @param ... Argumentos passados para \code{\link{request_modulo_compras}}.
#'
#' @return Lista contendo:
#'   \item{compras}{tibble com os dados coletados}
#'   \item{status_requisicao}{código HTTP da resposta}
#'   \item{situacao_requisicao}{status da requisição: "sucesso", "erro" ou "vazio"}
#'   \item{mensagem_requisicao}{mensagem descritiva ou NA}
#'
#' @keywords internal
#'
collect_endpoint_compras_com_status <- function(...) {
  tryCatch({
    resp <- request_modulo_compras(...) |>
      req_retry(max_tries = 3) |>
      req_throttle(capacity = 100, fill_time_s = 60) |>
      req_error(is_error = function(resp) FALSE) |>
      req_perform()

    status <- resp_status(resp)

    if (status < 200 || status >= 300) {
      mensagem_erro <- resp_body_string(resp)
      if (identical(mensagem_erro, "")) {
        mensagem_erro <- sprintf("HTTP %s", status)
      }

      return(list(
        compras = tibble(),
        status_requisicao = status,
        situacao_requisicao = "erro",
        mensagem_requisicao = mensagem_erro
      ))
    }

    mensagem_erro <- NA_character_
    body <- tryCatch(
      resp_body_json(resp, simplifyVector = TRUE),
      error = function(e) {
        mensagem_erro <<- conditionMessage(e)
        NULL
      }
    )

    erro_parse <- !is.na(mensagem_erro)

    if (erro_parse) {
      return(list(
        compras = tibble(),
        status_requisicao = status,
        situacao_requisicao = "erro",
        mensagem_requisicao = mensagem_erro
      ))
    }

    resultado_vazio <- status == 200 && body_resultado_vazio(body)

    if (resultado_vazio) {
      return(list(
        compras = tibble(),
        status_requisicao = status,
        situacao_requisicao = "vazio",
        mensagem_requisicao = "vazio"
      ))
    }

    resultado <- tryCatch(
      as_tibble(body),
      error = function(e) {
        mensagem_erro <<- conditionMessage(e)
        tibble()
      }
    )

    erro_parse <- !is.na(mensagem_erro)
    resultado_vazio <- status == 200 && nrow(resultado) == 0

    list(
      compras = resultado,
      status_requisicao = status,
      situacao_requisicao = case_when(
        erro_parse ~ "erro",
        resultado_vazio ~ "vazio",
        TRUE ~ "sucesso"
      ),
      mensagem_requisicao = case_when(
        erro_parse ~ mensagem_erro,
        resultado_vazio ~ "vazio",
        TRUE ~ NA_character_
      )
    )
  }, error = function(e) {
    list(
      compras = tibble(),
      status_requisicao = NA_integer_,
      situacao_requisicao = "erro",
      mensagem_requisicao = conditionMessage(e)
    )
  })
}

#' Verifica se o corpo da resposta da API está vazio
#'
#' Avalia diferentes estruturas de resposta da API e retorna \code{TRUE}
#' quando não há resultados úteis (NULL, data frame sem linhas, lista vazia
#' ou campo \code{resultado} ausente/vazio).
#'
#' @param body Corpo da resposta da API. Pode ser \code{NULL}, um data frame,
#'   uma lista genérica ou uma lista com o campo \code{resultado}.
#'
#' @return \code{TRUE} se o corpo for considerado vazio; \code{FALSE} caso contrário.
#'
#' @examples
#' body_resultado_vazio(NULL)          # TRUE
#' body_resultado_vazio(list())        # TRUE
#' body_resultado_vazio(tibble())      # TRUE
#' body_resultado_vazio(list(resultado = list()))  # TRUE
body_resultado_vazio <- function(body) {
  if (is.null(body)) return(TRUE)
  if (is.data.frame(body)) return(nrow(body) == 0)
  if (!is.list(body)) return(length(body) == 0)
  if (!"resultado" %in% names(body)) return(length(body) == 0)

  resultado <- body[["resultado"]]

  if (is.null(resultado)) return(TRUE)
  if (is.data.frame(resultado)) return(nrow(resultado) == 0)
  if (is.list(resultado)) {
    return(
      length(resultado) == 0 ||
        all(vapply(resultado, length, integer(1)) == 0)
    )
  }

  length(resultado) == 0
}

#' Coleta dados de compras para um lote específico
#'
#' Filtra o data frame pelo número do lote informado, desaninha a coluna
#' \code{data} e dispara requisições à API do Compras.gov para cada par
#' \code{(idCompra, codItemCatalogo)}, aguardando 60 segundos ao final para
#' evitar sobrecarga na API.
#'
#' @param lote Número (inteiro) do lote a ser processado.
#' @param df Data frame contendo as colunas \code{lot}, \code{data},
#'   \code{idCompra} e \code{codItemCatalogo}.
#' @param endpoint Character. Endpoint da API a ser consultado.
#' @param modulo Character. Módulo da API a ser utilizado.
#'
#' @return Data frame com as colunas originais acrescidas das colunas
#'   retornadas por \code{collect_endpoint_compras_com_status()} via
#'   \code{unnest_wider()}.
coleta_compras_em_lotes <- function(lote, df, endpoint, modulo) {

  msg <- sprintf("Coletando lote %s", lote)
  flush.console()
  cat(msg, "\r")

  df <- df |>
    filter(lot == lote)

  df <- df |>
    unnest(data)

  df <- df |>
    mutate(coleta = map2(idCompra, codItemCatalogo,
      ~ collect_endpoint_compras_com_status(
        modulo = modulo,
        endpoint = endpoint,
        params = list(
          idCompra = .x,
          codigoItemCatalogo = .y
        )
    ))) |>
    unnest_wider(coleta)

  Sys.sleep(2) # Pausa de 2 segundos entre os lotes para evitar sobrecarga na API
  df
}


#' Versão segura de \code{coleta_compras_em_lotes}
#'
#' Envolve \code{coleta_em_lotes} com \code{purrr::safely()} para capturar
#' erros sem interromper a execução, adicionando os campos \code{status_lote}
#' e \code{mensagem_erro_lote} ao resultado.
#'
#' @param ... Argumentos repassados a \code{coleta_em_lotes}.
#'
#' @return Lista com os elementos retornados por \code{safely()
#'   (result} e \code{error}), acrescida de:
#'   \describe{
#'     \item{status_lote}{Character. \code{"sucesso"} ou \code{"erro"}.}
#'     \item{mensagem_erro_lote}{Character. Mensagem de erro capturada, ou
#'       \code{NA_character_} em caso de sucesso.}
#'   }
coleta_compras_em_lotes_safely <- function(...) {
  res <- safely(coleta_compras_em_lotes)(...)

  res$status_lote <- if (is.null(res$error)) "sucesso" else "erro"
  res$mensagem_erro_lote <- if (is.null(res$error)) {
    NA_character_
  } else {
    conditionMessage(res$error)
  }

  res
}
