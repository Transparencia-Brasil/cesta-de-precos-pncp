#' Documente o script
#' 

# 1. Ler os arquivos a serem processados
# 2. Fazer as transformacoes e
# 3. Inserir no banco

library(readr)
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(here))

# LÊ ARQUIVOS  ------------------------------------------------------------

# Captura os argumentos da linha de comando
args <- commandArgs(trailingOnly = TRUE)

# Verifica se os argumentos foram fornecidos corretamente
if (length(args) < 3) {
  stop("Uso correto: Rscript carrega-dados.R <contratacoes.csv> <medicamentos.csv> <resultados.csv>")
}

# Verifica se a extensão dos arquivos é .csv
for (arg in args) {
  if (tolower(tools::file_ext(arg)) != "csv") {
    stop("Erro: Os arquivos de dados devem ser no formato .csv")
  }
}

# Lê os argumentos
CAMINHO_CONTRATACOES <- args[1] 
CAMINHO_MEDICAMENTOS <- args[2] 
CAMINHO_RESULTADOS <- args[3]

# Lê os arquivos de dados
contratacoes <- read_csv(CAMINHO_CONTRATACOES, show_col_types = FALSE)
medicamentos <- read_csv(CAMINHO_MEDICAMENTOS, show_col_types = FALSE)
resultados <- read_csv(CAMINHO_RESULTADOS, show_col_types = FALSE)


# TRANSFORMA DADOS --------------------------------------------------------

contratacoes <- read_csv("src/coletores/amostra_contratacoes.csv")
medicamentos <- read_csv("src/coletores/amostra_medicamentos.csv")
resultados <- read_csv("src/coletores/amostra_resultados.csv")

# Remove linhas onde 'endpoint' é NA. 
# Idealmente nenhuma linha seria removida. Mas pode haver má formatação do dado
# durante a coleta.
contratacoes <- contratacoes %>% filter(!is.na(endpoint))
medicamentos <- medicamentos %>% filter(!is.na(endpoint))
resultados <- resultados %>% filter(!is.na(endpoint))

# Cria chaves para fazer joins
medicamentos <- medicamentos %>%
  mutate(
    endpointResultado = paste0(endpoint, "/", numeroItem, "/resultados"),
    endpointContratacao = sub("/itens$", "", endpoint)
  )

# Filtra somente as contratações de medicamentos
contratacoes <- contratacoes %>% 
  semi_join(medicamentos, by = join_by(endpoint == endpointContratacao)) 

# Constrói o dataset de itens homologados (itens com resultado)
itens_homologados <- medicamentos %>%
  inner_join(resultados,
             by = join_by(endpointResultado == endpoint),
             suffix = c("", "Resultado"),
             multiple = "first") %>% # se ouver mais de um resultado, usar só o primeiro
  inner_join(contratacoes,
             by = join_by(endpoint_contratacao == endpoint),
             suffix = c("", "Contratacao"))

# Constrói o dataset de itens ainda não homologados (itens sem resultado)
itens_licitados <- medicamentos %>%
  anti_join(resultados,
             by = join_by(endpointResultado == endpoint)) %>%
  inner_join(contratacoes,
             by = join_by(endpoint_contratacao == endpoint),
             suffix = c("", "Contratacao"))


# EXTRAI TABELAS ----------------------------------------------------------

colunas_contratane <- c("orgaoEntidade.cnpj", "")

tb_contratante <- itens_homologados %>%











