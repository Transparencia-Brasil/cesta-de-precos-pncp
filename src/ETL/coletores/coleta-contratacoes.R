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
#' https://pncp.gov.br/api/consulta/swagger-ui/index.html#/Contrata%C3%A7%C3%A3o/consultarContratacaoPorDataDePublicacao

suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(tidyr))
suppressPackageStartupMessages(library(here))
suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(readr))

source(here("src/ETL/coletores/utils.R"))

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

  # Tenta coletar os dados e lança erros caso haja
  tryCatch(
    {
      resposta <- coleta_endpoint(endpoint)
      resposta$erro <- FALSE
      resposta$codigoModalidade <- i
      resposta$endpoint <- endpoint
      # Adiciona a resposta retornada ao dataframe `paginas_por_modalidade`
      paginas_por_modalidade <- bind_rows(paginas_por_modalidade, resposta)
    },
    error = function(e) {
      # Se houve erro, mostra a mensagem de erro e adiciona aos resultados
      print(e$message)
      paginas_por_modalidade <- bind_rows(
        paginas_por_modalidade,
        data.frame(
          erro = TRUE,
          codigoModalidade = i,
          endpoint = endpoint,
          mensagem_erro = as.character(e$message),
          stringsAsFactors = FALSE
        )
      )
    }
  )

  # Acompanhamento das consultas
  cat(sprintf("Modalidade %d coletada", i), "\r")
  flush.console()
}

# Salva um arquivo com as consultas que deram erro
if (nrow(paginas_por_modalidade %>% filter(erro == TRUE)) > 0) {
  if (!dir.exists(PATH_OUTPUT_DIR)) {
    dir.create(output_dir, recursive = TRUE)
  }

  paginas_por_modalidade %>%
    filter(erro == TRUE) %>%
    select(endpoint, mensagem_erro) %>%
    write_csv(here(PATH_OUTPUT_DIR, "erros.csv"))
}

# Sumariza o dataframe para saber quantas páginas e registros temos por modalidade
paginas_por_modalidade <- paginas_por_modalidade %>%
  select(codigoModalidade, totalRegistros, totalPaginas) %>%
  distinct() %>%
  arrange(codigoModalidade)


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
# Mapear todas as colunas que serão coletadas e garantir balanceamento do dataset

# referência: https://pncp.gov.br/api/consulta/swagger-ui/index.html#/Contrata%C3%A7%C3%A3o/consultarContratacaoPorDataDePublicacao
template_contratacoes <- tibble(
  # ids
  data.numeroControlePNCP = character(),
  data.anoCompra = character(),
  data.sequencialCompra = character(),
  # modalidade
  data.modalidadeId = character(),
  data.modalidadeNome = character(),
  # modoDisputa
  data.modoDisputaId = character(),
  data.modoDisputaNome = character(),
  # instrumentoConvocatorio
  data.tipoInstrumentoConvocatorioCodigo = character(),
  data.tipoInstrumentoConvocatorioNome = character(),
  # dataAbertura e dataEncerramento
  data.dataAberturaProposta = character(),
  data.dataEncerramentoProposta = character(),
  # valorEstimado e valorHomologado
  data.valorTotalEstimado = character(),
  data.valorTotalHomologado = character(),
  # objetoCompra
  data.objetoCompra = character(),
  # srp
  data.srp = character(),
  # ampareLegal
  data.amparoLegal.codigo = character(),
  data.amparoLegal.nome = character(),
  # orgaoEntidade
  data.orgaoEntidade.cnpj = character(),
  data.orgaoEntidade.razaoSocial = character(),
  data.orgaoEntidade.esferaId = character(),
  data.orgaoEntidade.poderId = character(),
  # unidadeOrgao
  data.unidadeOrgao.codigoUnidade = character(),
  data.unidadeOrgao.nomeUnidade = character(),
  data.unidadeOrgao.codigoIbge = character(),
  data.unidadeOrgao.municipioNome = character(),
  data.unidadeOrgao.ufSigla = character(),
  data.unidadeOrgao.ufNome = character(),
  # unidadeSubRogada
  data.unidadeSubRogada.codigoUnidade = character(),
  data.unidadeSubRogada.nomeUnidade = character(),
  data.unidadeSubRogada.codigoIbge = character(),
  data.unidadeSubRogada.municipioNome = character(),
  data.unidadeSubRogada.ufSigla = character(),
  data.unidadeSubRogada.ufNome = character(),
  # orgaoSubRogado
  data.orgaoSubRogado.cnpj = character(),
  data.orgaoSubRogado.razaoSocial = character(),
  data.orgaoSubRogado.esferaId = character(),
  data.orgaoSubRogado.poderId = character(),
)


# COLETA ------------------------------------------------------------------

# Executa a coleta
coleta(
  endpoints = endpoints,
  output_dir = PATH_OUTPUT_DIR,
  template = template_contratacoes
)
