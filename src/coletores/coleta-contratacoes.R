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

source(here("src/coletores/funcoes.R"))

# PARAMETROS --------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)

# Verifica se o diretório de saída foi passado como argumento, caso contrário, define um padrão
PATH_OUTPUT_DIR <- ifelse(length(args) >= 1, args[1], here("coleta", "contratacoes"))

# Obtém o primeiro dia do mês anterior
PRIMEIRO_DIA <- floor_date(today() - months(1), "month")

# Obtém o último dia do mês anterior
ULTIMO_DIA <- ceiling_date(PRIMEIRO_DIA, "month") - days(1)

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
  
  url_base = "https://pncp.gov.br/api/consulta/v1/contratacoes/atualizacao?"
  paste0(url_base,
         "dataInicial=", data_inicial,
         "&dataFinal=", data_final,
         "&codigoModalidadeContratacao=", codigo_modalidade_contratacao,
         "&pagina=", pagina, 
         "&tamanhoPagina=", tamanho_pagina)
}

# Dataframe para guardar quantas páginas por modalidade serão consultadas
paginas_por_modalidade = data.frame()

# Faz uma consulta inicial por modalidade e salva os resultados para saber
# quantas páginas serão consultadas ao todo.
for (i in MODALIDADES) {
  endpoint <- monta_endpoint(PRIMEIRO_DIA, ULTIMO_DIA, i, 1, TAMANHO_PAGINA)
 
   # Tenta coletar os dados e lança erros caso haja
  tryCatch({
    resposta <- coleta_endpoint(endpoint)
    resposta$erro <- FALSE
    resposta$codigoModalidade <- i
    resposta$endpoint <- endpoint
    # Adiciona a resposta retornada ao dataframe `paginas_por_modalidade`
    paginas_por_modalidade <- bind_rows(paginas_por_modalidade, resposta)
    
  }, error = function(e) {
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
  })
  
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
  mutate(pagina = list(1:totalPaginas)) %>%  # Cria uma lista de páginas para cada modalidade
  unnest(pagina) %>%  # Expande a lista em várias linhas
  mutate(endpoint = monta_endpoint(PRIMEIRO_DIA, ULTIMO_DIA, codigoModalidade, pagina, TAMANHO_PAGINA))

# Extrai só a coluna de endpoints  
endpoints <- paginas_por_modalidade %>% pull(endpoint)


# COLETA ------------------------------------------------------------------

# Executa a coleta
coleta(endpoints = endpoints, output_dir = PATH_OUTPUT_DIR)
