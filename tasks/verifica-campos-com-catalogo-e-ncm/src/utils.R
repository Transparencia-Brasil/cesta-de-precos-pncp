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

#' Conta e plota a quantidade de itens coletados do PNCP por mês
#'
#' @param itens Data frame contendo os itens coletados, com colunas de data e identificação.
#' @return Um gráfico ggplot2 com a contagem de itens por mês e coleta.
#' @import dplyr ggplot2 lubridate forcats scales ggtext
contagem_de_itens_coletados <- function(itens) {
  # COUNT ALL --------------------------------------------------------------------

  quantidades <- itens %>%
    mutate(coleta = fct_reorder(coleta, data_coleta)) %>%
    count(coleta, atual, ano = year(dataInclusao), mes = month(dataInclusao)) %>%
    mutate(mesInclusao = my(sprintf("%s/%s", mes, ano))) %>%
    summarise(.by = c(coleta, atual, mesInclusao), n = sum(n))

  quantidades %>%
    ggplot(aes(x = mesInclusao, y = n, fill = coleta)) +
    geom_col(aes(color = after_scale(darken(fill, .4)))) +
    labs(
      title = "Quantidade de itens coletados do PNCP - por mês",
      subtitle = "Ex: https:\\/\\/pncp.gov.br\\/api\\/pncp\\/v1\\/orgaos\\/**{cnpj}**\\/compras\\/**{ano}**\\/**{sequencial}**\\/itens/**{numeroItem}**<br><br>Dados são coletados por data de atualização do item",
      x = "<br>dataInclusao do item no PNCP",
      y = "<br>Quantidade de itens coletados",
      fill = "Ano/mês da coleta<br>(quanto mais escuro mais atual)"
    ) +
    scale_x_date(date_labels = "%b-%y", date_breaks = "1 months", expand = c(0, 0)) +
    scale_y_continuous(labels = numero, breaks = seq(0, 3e5, length.out = 6), limits = c(0, 3.8e5), expand = c(0, 0), position = "right") +
    scale_fill_brewer(palette = "Purples") +
    theme(
      axis.text.x = ggtext::element_markdown(angle = 45, hjust = 1),
      legend.position = c(.15, .82),
      legend.direction = "vertical",
      legend.title.position = "top"
    )
}
