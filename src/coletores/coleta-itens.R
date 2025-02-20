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

library(dplyr)
library(here)
library(readr)

source(here("src/coletores/funcoes.R"))

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

if (! "endpoint" %in% names(contratacoes_df)) {
  stop("Erro: O dataframe passado precisa ter uma coluna chamada 'endpoint'.")
}

# Os endpoints das contratacões coletadas
endpoints_contratacoes <- contratacoes_df %>% pull(endpoint)

# Adiciona "/itens" aos endpoints das contratações para transformá-los em 
# endpoints de itens.
endpoints_itens <- paste0(endpoints_contratacoes, "/itens")


# COLETA ------------------------------------------------------------------

# Executa a coleta
coleta(endpoints = endpoints_itens, output_dir = PATH_OUTPUT_DIR)
