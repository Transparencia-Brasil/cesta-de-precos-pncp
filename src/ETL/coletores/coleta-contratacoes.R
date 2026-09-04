#' Este script coleta os dados das contratações a partir da API do PNCP.
#' Os dados são coletados a partir do endpoint consultarContratacaoPorDataUltimaAtualizacao.
#' Todas as contratações do mês anterior ao vigente são coletadas.
#'
#' Há 1 parâmetros opcional de entrada:
#' PATH_OUTPUT_DIR - o caminho para o diretório de saída, onde serão salvos
#' os arquivos de dados da coleta. Caso não seja passado, será criado um diretório
#' chamado "coleta/contratacoes" na raiz do projeto.
#'
#' Ao final da coleta 3 arquivos são salvos:
#' 1. dados.csv - contém os dados das contratações.
#' 2. erros.csv - contém os endpoints que retornaram erros ao consultar e a mensagem de erro.
#' 3. monitoramento.csv - contém metadados sobre a duração da coleta para cada lote de dados.
#'
#' https://pncp.gov.br/api/consulta/swagger-ui/index.html#/Contrata%C3%A7%C3%A3o/consultarContratacaoPorDataUltimaAtualizacao


suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(tidyr))
suppressPackageStartupMessages(library(here))
suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(readr))

source(here("src/ETL/coletores/utils.R"))
source(here("src/ETL/template/utils-template.R"))

# PARAMETROS --------------------------------------------------------------

# captura os arqgumentos
args <- commandArgs(trailingOnly = TRUE)

# Processa os argumentos
for (arg in args) {
  if (grepl("^PATH_OUTPUT_DIR=", arg)) {
    PATH_OUTPUT_DIR <- here(sub("^PATH_OUTPUT_DIR=", "", arg))
  } else if (grepl("^PRIMEIRO_DIA=", arg)) {
    PRIMEIRO_DIA <- as_date(sub("^PRIMEIRO_DIA=", "", arg))
  } else if (grepl("^ULTIMO_DIA=", arg)) {
    ULTIMO_DIA <- as_date(sub("^ULTIMO_DIA=", "", arg))
  }
}

# Exemplo de mensagem para verificar os valores
message("\nPATH_OUTPUT_DIR: ", PATH_OUTPUT_DIR)
message("\nPRIMEIRO_DIA: ", PRIMEIRO_DIA)
message("\nULTIMO_DIA: ", ULTIMO_DIA, "\n")

stopifnot({
  dir.exists(PATH_OUTPUT_DIR)
  is.Date(PRIMEIRO_DIA)
  is.Date(ULTIMO_DIA)
})

# Os códigos das modalidades de contratações no PNCP vão de 1 a 14
# Ref: https://pncp.gov.br/app/entidades-dominio
MODALIDADES <- c(1:14)

# Serão coletadas 50 contratações por página
TAMANHO_PAGINA <- 50


# PÁGINAS POR MODALIDADE --------------------------------------------------
# Quantos registros/páginas temos no mês por modalidade?

#' @title Monta uma URL para consulta na API do PNCP
#' @description Constrói uma URL com os parâmetros necessários para buscar contratações na API do PNCP.
#'
#' @param data_inicial Data inicial do período de consulta (formato Date).
#' @param data_final Data final do período de consulta (formato Date).
#' @param codigo_modalidade_contratacao Código da modalidade de contratação (inteiro).
#' @param pagina Número da página da consulta (inteiro).
#' @param tamanho_pagina Quantidade de registros por página (inteiro).
#'
#' @return Uma string contendo a URL formatada para consulta na API do PNCP.
#'
#' @examples
#' url <- monta_endpoint(as.Date("2024-01-01"), as.Date("2024-01-31"), 5, 1, 50)
#' print(url)
monta_endpoint <- function(data_inicial,
                           data_final,
                           codigo_modalidade_contratacao,
                           pagina,
                           tamanho_pagina) {
  # Converte as datas para o formato yyyyMMdd
  data_inicial <- format(data_inicial, "%Y%m%d")
  data_final <- format(data_final, "%Y%m%d")

  url_base <- "https://pncp.gov.br/api/consulta/v1/contratacoes/atualizacao?"
  paste0(
    url_base,
    "dataInicial=", data_inicial,
    "&dataFinal=", data_final,
    "&codigoModalidadeContratacao=", codigo_modalidade_contratacao,
    "&pagina=", pagina,
    "&tamanhoPagina=", tamanho_pagina
  )
}

# Dataframe para guardar quantas páginas por modalidade serão consultadas
paginas_por_modalidade <- data.frame()

# Faz uma consulta inicial por modalidade e salva os resultados para saber
# quantas páginas serão consultadas ao todo.
for (i in MODALIDADES) {
  endpoint <- monta_endpoint(PRIMEIRO_DIA, ULTIMO_DIA, i, 1, TAMANHO_PAGINA)

  resultado_modalidade <- tryCatch(
    {
      resposta <- coleta_endpoint(endpoint)

      if (nrow(resposta) == 0) {
        resposta <- data.frame(
          erro = FALSE,
          codigoModalidade = i,
          endpoint = endpoint,
          totalRegistros = 0L,
          totalPaginas = 0L,
          stringsAsFactors = FALSE
        )

        cat(sprintf("Modalidade %d sem registros (HTTP 204).", i), "\n")
      } else {
        resposta$erro <- FALSE
        resposta$codigoModalidade <- i
        resposta$endpoint <- endpoint

        cat(
          sprintf(
            "Modalidade %d coletada: %d registros em %d páginas.",
            i,
            resposta$totalRegistros[[1]],
            resposta$totalPaginas[[1]]
          ),
          "\n"
        )
      }

      resposta
    },
    error = function(e) {
      mensagem_erro <- sprintf("Modalidade %d: %s", i, e$message)
      cat(
        sprintf(
          "Modalidade %d falhou após as tentativas: %s",
          i,
          e$message
        ),
        "\n"
      )

      data.frame(
        erro = TRUE,
        codigoModalidade = i,
        endpoint = endpoint,
        mensagem_erro = mensagem_erro,
        stringsAsFactors = FALSE
      )
    }
  )

  paginas_por_modalidade <- bind_rows(
    paginas_por_modalidade,
    resultado_modalidade
  )
  flush.console()
}

# Salva um arquivo com as consultas que deram erro
modalidades_com_erro <- paginas_por_modalidade %>% filter(erro == TRUE)

if (nrow(modalidades_com_erro) > 0) {
  if (!dir.exists(PATH_OUTPUT_DIR)) {
    dir.create(PATH_OUTPUT_DIR, recursive = TRUE)
  }

  path_erros <- here(PATH_OUTPUT_DIR, "erros.csv")

  modalidades_com_erro %>%
    select(endpoint, mensagem_erro) %>%
    write_csv(path_erros)

  total_modalidades_com_erro <- n_distinct(
    modalidades_com_erro$codigoModalidade
  )

  stop(
    sprintf(
      paste0(
        "A descoberta de páginas falhou em %d de %d modalidades. ",
        "Consulte %s. Nenhuma página será coletada."
      ),
      total_modalidades_com_erro,
      length(MODALIDADES),
      path_erros
    ),
    call. = FALSE
  )
}

# Sumariza o dataframe para saber quantas páginas e registros temos por modalidade
paginas_por_modalidade <- paginas_por_modalidade %>%
  select(codigoModalidade, totalRegistros, totalPaginas) %>%
  distinct() %>%
  arrange(codigoModalidade)

  cat(sprintf("Total de páginas a coletar: %d", sum(paginas_por_modalidade$totalPaginas)), "\n\r")
  cat(sprintf("Total de registros a coletar: %d", sum(paginas_por_modalidade$totalRegistros)), "\n\r")


# LISTA DE ENDPOINTS A COLETAR --------------------------------------------

# Cria um endpoint para cada página a consultar para cada modalidade
paginas_por_modalidade <- paginas_por_modalidade %>%
  rowwise() %>%
  mutate(pagina = list(1:totalPaginas)) %>% # Cria uma lista de páginas para cada modalidade
  unnest(pagina) %>% # Expande a lista em várias linhas
  mutate(endpoint = monta_endpoint(PRIMEIRO_DIA, ULTIMO_DIA, codigoModalidade, pagina, TAMANHO_PAGINA))

# Extrai só a coluna de endpoints
endpoints <- paginas_por_modalidade %>% pull(endpoint)

# TEMPLATE ----------------------------------------------------------------
# Template versionado e atualizado pelo validador em src/ETL/template.
template_contratacoes <- carrega_template_coleta("contratacoes")


# COLETA ------------------------------------------------------------------

# Executa a coleta
coleta(
  endpoints = endpoints,
  output_dir = PATH_OUTPUT_DIR,
  template = template_contratacoes
)
