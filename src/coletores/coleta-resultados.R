#' Este script coleta os dados resultados de itens das contratações a partir da 
#' API do PNCP. Os resultados referem-se aos resultados da homologação da licitação.
#' 
#' Há dois parâmetros de entrada:
#' parâmetro 1 (obrigatório) - o caminho para um arquivo .csv que seja um dataframe
#' contendo uma coluna nomeada 'endpoint', indicando os endpoints de itens das contratações 
#' coletados anteriormente.
#' 
#' parâmetro 2 (opcional) - o caminho para o diretório de saída, onde serão salvos
#' os arquivos de dados da coleta. Caso não seja passado, será criado um diretório
#' chamado "coleta/resultados" na raiz do projeto.
#' 
#' Ao final da coleta 3 arquivos são salvos:
#' 1. dados.csv - contém os dados de resultados de itens das contratações.
#' 2. erros.csv - contém os endpoints que retornaram erros ao consultar e a mensagem de erro.
#' 3. monitoramento.csv - contém metadados sobre a duração da coleta para cada lote de dados.
#' 
#' https://pncp.gov.br/api/pncp/swagger-ui/index.html#/Contrata%C3%A7%C3%A3o/recuperarResultados

library(dplyr)
library(here)
library(readr)

source(here("src/coletores/funcoes.R"))

# PARAMETROS --------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 1) {
  stop("Erro: É necessário passar o caminho para o arquivo de itens das contratações 
  como argumento. Os resultados serão coletados a partir destes itens.")
}

PATH_ITENS <- here(args[1])

# Verifica se a extensão do arquivo é .csv
if (tolower(tools::file_ext(PATH_ITENS)) != "csv") {
  stop("Erro: O arquivo deve ter a extensão .csv")
}

# Verifica se o segundo argumento foi passado, caso contrário, define um padrão
PATH_OUTPUT_DIR <- ifelse(length(args) >= 2, args[2], here("coleta", "resultados"))

# LISTA DE ENDPOINTS A COLETAR --------------------------------------------

itens_df <- read_csv(PATH_ITENS)

if (!all(c("endpoint", "numeroItem") %in% names(itens_df))) {
  stop("Erro: O dataframe passado precisa ter colunas chamadas 'endpoint' e 'numeroItem'.")
}

# Adiciona "/<numeroItem>/resultados" aos endpoints dos itens para transformá-los 
# em endpoints de resultados.
endpoints_resultados <- paste0(itens_df$endpoint, "/", itens_df$numeroItem, "/resultados")


# COLETA ------------------------------------------------------------------

# Executa a coleta
coleta(endpoints = endpoints_resultados, output_dir = PATH_OUTPUT_DIR)
