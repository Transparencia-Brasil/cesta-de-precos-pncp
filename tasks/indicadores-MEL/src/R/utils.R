#' @title Gerar Identificador de Controle PNCP
#' @description Função para criar um identificador único de controle PNCP com base no endpoint fornecido.
#' @details
#' Número de Controle da Contratação (id contratação PNCP) (Máscara: 99999999999999-1-999999/9999.)
#' Cada contratação receberá um número de controle composto por:
#' - CNPJ do Órgão/Entidade da contratação (14 dígitos)
#' - Dígito "1" - marcador que indica tratar-se de uma contratação
#' - Número sequencial da contratação no PNCP *
#' - Ano da contratação (4 dígitos)
#'
#' * O número PNCP será gerado sequencialmente com 6 dígitos e reiniciado a cada mudança de ano.
#' (Fonte: Manual de Integração do PNCP)
#' @param endpoint Uma string representando o endpoint da API contendo informações sobre o fornecedor, ano e sequencial.
#' @return Uma string contendo o identificador no formato "{cnpj}-1-{sequencial}/{ano}".
#' @examples
#' make_id("https://api.exemplo.com/orgaos/12345/compras/2023/6789/itens")
#' # Retorna: "12345-1-006789/2023"
make_id <- \(endpoint) {
  cnpj <- endpoint %>%
    str_remove("^.+orgaos\\/") %>%
    str_remove("\\/compras.+")

  ano <- endpoint %>%
    str_remove("^.+compras\\/") %>%
    str_extract("^\\d+")

  sequencial <- endpoint %>%
    str_remove(str_glue("^.+compras\\/{ano}\\/")) %>%
    str_remove(str_glue("\\/itens")) %>%
    str_pad(width = 6, pad = "0")

  numeroControlePNCP <- str_glue("{cnpj}-1-{sequencial}/{ano}")

  return(numeroControlePNCP)
}

make_anomes_coleta <- function(path) {
  path |>
    str_remove("^.+itens\\/") |>
    str_remove("\\/medicamentos\\.csv$") |>
    str_remove("[\\/\\-]Q(UINZENA)?-?[12]$") |>
    ym()
}
