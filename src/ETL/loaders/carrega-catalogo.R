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
suppressPackageStartupMessages(library(RPostgres))

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

colunas_catalogo <- c(
  "codigo_classe",
  "nome_classe",
  "codigo_pdm",
  "nome_pdm",
  "codigo_br",
  "nome_item",
  "item_suspenso",
  "item_ativo",
  "item_sustentavel",
  "buscaItemCaracteristica",
  "unidadeFornecimento"
)

tb_catalogo <- catalogo %>% select(all_of(colunas_catalogo)) %>%
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

NOME_BD <- "medicamentos-transparentes"
HOST <- "localhost"
USUARIO <- "postgres"
SENHA <- "postgres"
PORTA <- 5432

con <- dbConnect(
  RPostgres::Postgres(),
  dbname = NOME_BD ,
  host = HOST,
  user = USUARIO,
  password = SENHA,
  port = PORTA
)


# INSERE OS DADOS ---------------------------------------------------------

query <- "INSERT INTO catalogo (codigo_classe, nome_classe, codigo_pdm, nome_pdm,
codigo_item, nome_item, item_suspenso, item_ativo, item_sustentavel, características,
unidades_fornecimento)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10::jsonb, $11::jsonb)
ON CONFLICT (codigo_item) DO NOTHING;"

for (i in 1:nrow(tb_catalogo)) {
  dbExecute(con, query, params = as.list(unname(tb_catalogo[i, ])))
}

# Fechar conexão
dbDisconnect(con)
