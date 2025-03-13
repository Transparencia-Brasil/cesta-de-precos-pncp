#' Este script coleta os dados de itens das contratações a partir da API do PNCP.
#' 
#' Há dois parâmetros de entrada:
#' parâmetro 1 (obrigatório) - o caminho para um arquivo .csv que seja um dataframe
#' contendo uma coluna nomeada 'endpoint', indicando os endpoints de contratações 
#' coletadas anteriormente.
#' 
#' parâmetro 2 (opcional) - o caminho para o diretório de saída, onde serão salvos
#' os arquivos de dados da coleta. Caso não seja passado, será criado um diretório
#' chamado "coleta/itens" na raiz do projeto.
#' 
#' Ao final da coleta 3 arquivos são salvos:
#' 1. dados.csv - contém os dados de itens das contratações.
#' 2. erros.csv - contém os endpoints que retornaram erros ao consultar e a mensagem de erro.
#' 3. monitoramento.csv - contém metadados sobre a duração da coleta para cada lote de dados.
#' 
#' https://pncp.gov.br/api/pncp/swagger-ui/index.html#/Contrata%C3%A7%C3%A3o/pesquisarCompraItem

suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(here))
suppressPackageStartupMessages(library(readr))

source(here("src/ETL/coletores/funcoes.R"))

# PARAMETROS --------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 1) {
  stop("Erro: É necessário passar o caminho para o arquivo de contratações como
       argumento. Os itens serão coletados a partir destas contratações.")
}

PATH_CONTRATACOES <- here(args[1])

# Verifica se a extensão do arquivo é .csv
if (tolower(tools::file_ext(PATH_CONTRATACOES)) != "csv") {
  stop("Erro: O arquivo deve ter a extensão .csv")
}

# Verifica se o segundo argumento foi passado, caso contrário, define um padrão
PATH_OUTPUT_DIR <- ifelse(length(args) >= 2, args[2], here("coleta", "itens"))

# LISTA DE ENDPOINTS A COLETAR --------------------------------------------

contratacoes_df <- read_csv(PATH_CONTRATACOES)

if (! "data.orgaoEntidade.cnpj" %in% names(contratacoes_df)) {
  stop("Erro: O dataframe passado precisa ter uma coluna chamada 'data.orgaoEntidade.cnpj'.")
}

if (! "data.anoCompra" %in% names(contratacoes_df)) {
  stop("Erro: O dataframe passado precisa ter uma coluna chamada 'data.anoCompra'.")
}

if (! "data.sequencialCompra" %in% names(contratacoes_df)) {
  stop("Erro: O dataframe passado precisa ter uma coluna chamada 'data.sequencialCompra'.")
}

# Monta os endpoints dos itens a partir de informacoes da contratacao.
# Formato: https://pncp.gov.br/api/pncp/v1/orgaos/<CNPJ>/compras/<ano>/<sequencial>/itens
endpoints_itens <- paste0("https://pncp.gov.br/api/pncp/v1/orgaos/",
                          contratacoes_df$data.orgaoEntidade.cnpj, 
                          "/compras/", contratacoes_df$data.anoCompra,
                          "/", contratacoes_df$data.sequencialCompra,
                          "/itens")


# COLETA ------------------------------------------------------------------

# Executa a coleta
coleta(endpoints = endpoints_itens, output_dir = PATH_OUTPUT_DIR)
