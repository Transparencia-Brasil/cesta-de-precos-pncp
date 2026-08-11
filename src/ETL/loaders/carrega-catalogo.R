#' Este script insere os dados do catálogo de itens no banco de dados configurado.
#'
#' O parâmetro de entrada obrigatório é o caminho para o arquivo versionado do
#' catálogo no formato `catmat-N.rds`. O mapeamento OCDS correspondente deve
#' estar no mesmo diretório, no formato `tabela-mapeamento-ocds-N.csv`.
#'
#' O catálogo foi obtido a partir da seguinte API:
#' https://cnbs.estaleiro.serpro.gov.br/cnbs-api/swagger-ui/index.html#/
#'
#' Utilizando o seguinte script:
#' https://github.com/Transparencia-Brasil/pncp-analises/tree/main/tasks/scrap-catmat
#'

suppressPackageStartupMessages(library(readr))
suppressPackageStartupMessages(library(tidyr))
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
    paste0(
      "Uso correto: Rscript carrega-catalogo.R <catmat-N.rds> ",
      "[--validar-apenas]"
    )
  )
}

# Lê os argumentos
CAMINHO_CATALOGO <- args[1]
opcoes <- args[-1]
opcoes_invalidas <- setdiff(opcoes, "--validar-apenas")

if (length(opcoes_invalidas) > 0) {
  stop(sprintf(
    "Opção desconhecida: %s.",
    paste(opcoes_invalidas, collapse = ", ")
  ))
}

VALIDAR_APENAS <- "--validar-apenas" %in% opcoes

# Verifica se o arquivo do catálogo existe
if (!file.exists(CAMINHO_CATALOGO)) {
  stop(sprintf("O arquivo do catálogo não foi encontrado: %s", CAMINHO_CATALOGO))
}

# Verifica se a extensão do arquivo é .rds
if (tolower(tools::file_ext(CAMINHO_CATALOGO)) != "rds") {
  stop("O arquivo do catálogo deve ser no formato .rds.")
}

# Extrai a versão do nome do catálogo
nome_catalogo <- basename(CAMINHO_CATALOGO)

# checa se o nome do catálogo segue o padrão catmat-N.rds, em que N é a versão numérica
correspondencia_versao <- regexec("^catmat-([0-9]+)\\.rds$", nome_catalogo, ignore.case = TRUE)
partes_nome_catalogo <- regmatches(nome_catalogo, correspondencia_versao)[[1]]

if (length(partes_nome_catalogo) == 0) {
  stop("O nome do catálogo deve seguir o padrão catmat-N.rds, em que N é a versão numérica.")
}

# Definição da versão do catálogo a partir do nome do arquivo
versao_catalogo <- partes_nome_catalogo[[2]]

# Define o caminho do arquivo de mapeamento OCDS correspondente à versão do catálogo
CAMINHO_MAPEAMENTO_OCDS <- file.path(dirname(CAMINHO_CATALOGO), sprintf("tabela-mapeamento-ocds-%s.csv", versao_catalogo))

if (!file.exists(CAMINHO_MAPEAMENTO_OCDS)) {
  stop(sprintf("O mapeamento OCDS da versão %s não foi encontrado: %s", versao_catalogo, CAMINHO_MAPEAMENTO_OCDS))
}


# LOAD FILES -----------------------------------------------------------------

# Lê os arquivos de dados
catalogo <- readRDS(CAMINHO_CATALOGO) |>
  # Converte codigo_br para character para evitar problemas de join com o mapeamento OCDS
  mutate(codigo_br = as.character(codigo_br))

mapeamento_caracteristicas_ocds <- le_mapeamento_caracteristicas_ocds(CAMINHO_MAPEAMENTO_OCDS)


# SELECIONA CARACTERÍSTICAS DOS MEDICAMENTOS ------------------------------

# Número máximo de características a manter por medicamento (por PDM)
MAX_CARACTERISTICAS = 3

# Desaninha a coluna "buscaItemCaracteristica"
catalogo <- catalogo %>% unnest(buscaItemCaracteristica)

# Cria um  dataframe com as caracteristicas que serão mantidas para cada medicamento
caracteristicas <- catalogo %>%
  # Agrupa por PDM e codigoCaracteristica
  group_by(codigo_pdm, codigoCaracteristica) %>%
  # Conta valores únicos para cada característica dentro de cada PDM
  summarise(n_valores_unicos = n_distinct(nomeValorCaracteristica),
            .groups = "drop") %>%
  # Agrupa por PDM
  group_by(codigo_pdm) %>%
  # Seleciona as (MAX_CARACTERISTICAS) características com mais valores distintos
  slice_max(n = MAX_CARACTERISTICAS,
            order_by = n_valores_unicos,
            with_ties = FALSE) %>%
  # remove características com apenas 1 valor distinto
  filter(n_valores_unicos > 1) %>%
  # Adiciona uma flag: Devemos manter essa caracteristica?
  mutate(manter = TRUE)

# Marca no catálogo as caracteristicas que serão utilizadas (manter == TRUE)
catalogo <- catalogo %>%
  left_join(caracteristicas, by = c("codigo_pdm", "codigoCaracteristica"))

# Reaninha as características dentro do catálogo
# Reaninha antes de excluir as características para não correr o risco de excluir
# medicamentos que possuam apenas uma característica com um único valor.
# Exemplo: Hidróxido De Alumínio, Indicação:300mg (codigo br: 267271)
catalogo <- catalogo %>%
  group_by(codigo_br) %>%
  nest(
    buscaItemCaracteristica = c(
      codigoCaracteristica,
      codigoValorCaracteristica,
      nomeCaracteristica,
      caracteristicaObrigatoria,
      statusCaracteristica,
      numeroCaracteristica,
      nomeValorCaracteristica,
      siglaUnidadeMedida,
      statusValorCaracteristica,
      manter,
      n_valores_unicos
    )
  ) %>%
  ungroup()

# Filtra as características dentro do dataframe aninhado
catalogo <- catalogo %>%
  mutate(buscaItemCaracteristica = map(buscaItemCaracteristica, ~ filter(.x, manter == TRUE)))

# Integra as características OCDS por codigo_br = codigo_item
catalogo <- adiciona_caracteristicas_ocds(catalogo, mapeamento_caracteristicas_ocds)


# TRANSFORMA A TABELA -----------------------------------------------------

tb_catalogo <- catalogo %>%
  select(all_of(COLUNAS_CATALOGO)) %>%
  mutate( # Seleciona atributos de interesse
    caracteristicas = map(buscaItemCaracteristica, ~ select(.x, nomeCaracteristica, nomeValorCaracteristica))
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

insere_tabela(con, tb_catalogo, CONSULTA_UPDATE_CATALOGO)

# Fechar conexão
dbDisconnect(con)
