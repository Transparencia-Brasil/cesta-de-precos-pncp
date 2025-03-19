#' Este script insere os dados do catálogo de itens no banco de dados configurado.
#' 
#' O parâmetro de entrada obrigatório é o caminho para o arquivo do catálogo em 
#' formato .rds.
#' 
#' O catálogo foi obtido a partir da seguinte API:
#' https://cnbs.estaleiro.serpro.gov.br/cnbs-api/swagger-ui/index.html#/
#' 
#' Utilizando o seguinte script:
#' https://github.com/Transparencia-Brasil/pncp-analises/tree/main/tasks/scrap-catmat
#' 

suppressPackageStartupMessages(library(readr))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(here))
suppressPackageStartupMessages(library(jsonlite))
suppressPackageStartupMessages(library(purrr))
suppressPackageStartupMessages(library(DBI))

source(here("src/ETL/loaders/utils.R"))

# LÊ ARQUIVOS  ------------------------------------------------------------

# Captura os argumentos da linha de comando
args <- commandArgs(trailingOnly = TRUE)

# Verifica se os argumentos foram fornecidos corretamente
if (length(args) < 1) {
  stop(
    "Uso correto: Rscript carrega-catalogo.R <catalogo.rds>"
  )
}

# Lê os argumentos
CAMINHO_CATALOGO <- args[1]

# Verifica se a extensão do arquivo é .rds
if (tolower(tools::file_ext(arg)) != ".rds") {
  stop("Erro: O arquivo do catálogo deve ser no formato .rds.")
}

# Lê os arquivos de dados
catalogo <- read_csv(CAMINHO_CATALOGO, show_col_types = FALSE)


# TRANSFORMA A TABELA -----------------------------------------------------

tb_catalogo <- catalogo %>% select(all_of(COLUNAS_CATALOGO)) %>%
  mutate( # Seleciona atributos de interesse
    caracteristicas = map(buscaItemCaracteristica, ~ select(.x, nomeCaracteristica, caracteristicaObrigatoria, nomeValorCaracteristica))
  ) %>%
  mutate( # transforma as características em um JSON
    caracteristicas = map(caracteristicas, ~ toJSON(.x, auto_unbox = TRUE)),
    unidade_fornecimento = map(unidadeFornecimento, ~ toJSON(.x, auto_unbox = TRUE))
  ) %>%
  mutate( # transforma o JSON em character (string)
    caracteristicas = as.character(caracteristicas),
    unidade_fornecimento = as.character(unidade_fornecimento)
  ) %>%
  select(-buscaItemCaracteristica, -unidadeFornecimento)


# CONECTA-SE  COM O BD ----------------------------------------------------

con <- conecta_bd_medicamentos_transparentes()

# INSERE OS DADOS ---------------------------------------------------------

insere_tabela(con, tb_catalogo, CONSULTA_INSERIR_CATALOGO)

# Fechar conexão
dbDisconnect(con)
