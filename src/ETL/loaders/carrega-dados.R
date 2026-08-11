#' Este script carrega os dados coletados do PNCP no banco do Medicamentos Transparentes.
#'
#' Há 3 parâmetros obrigatórios:
#' 1 - caminho para um arquivo .csv contendo contratações obtidas da API de consulta
#' 2 - caminho para um arquivo .csv contendo itens obtidos da API de integração
#' 3 - caminho para um arquivo .csv contendo resultados de itens obtidos da API de integração
#'
#' O script processa os arquivos e os insere nas tabelas do banco.
#'
#' API de consulta: https://pncp.gov.br/api/consulta/swagger-ui/index.html#/
#' API de integração: https://pncp.gov.br/api/pncp/swagger-ui/index.html#/
#'

suppressPackageStartupMessages(library(readr))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(here))
suppressPackageStartupMessages(library(purrr))
suppressPackageStartupMessages(library(DBI))

source(here("src/ETL/loaders/utils.R"))
source(here("src/ETL/loaders/utils-historico.R"))


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
classificacao_compras_judiciais <- le_classificacao_compras_judiciais()

list(
  nrow(contratacoes),
  nrow(medicamentos),
  nrow(resultados)
) %>% walk(~ message("Linhas lidas: ", .x))

# TRANSFORMA DADOS --------------------------------------------------------

# Remove linhas onde 'endpoint' é NA.
# Idealmente nenhuma linha seria removida. Mas pode haver má formatação do dado
# durante a coleta.
contratacoes <- contratacoes %>% filter(!is.na(endpoint))
medicamentos <- medicamentos %>% filter(!is.na(endpoint))
resultados <- resultados %>% filter(!is.na(endpoint))


list(
  nrow(contratacoes),
  nrow(medicamentos),
  nrow(resultados)
) %>% walk(~ message("Linhas lidas (após remover NA's): ", .x))

# Cria chaves para fazer joins e adiciona a url do item na API
medicamentos <- medicamentos %>%
  mutate(
    endpointResultado = paste0(endpoint, "/", numeroItem, "/resultados"),
    endpointContratacao = sub("/itens$", "", endpoint),
    urlAPI = paste0(endpoint, "/", numeroItem)
  )

# Cria chaves para fazer joins e adiciona a url da contratacao no PNCP
contratacoes <- contratacoes %>%
  mutate(
    endpoint = paste0(
      "https://pncp.gov.br/api/pncp/v1/orgaos/",
      data.orgaoEntidade.cnpj,
      "/compras/",
      data.anoCompra,
      "/",
      data.sequencialCompra
    ),
    urlPNCP = paste0(
      "https://pncp.gov.br/app/editais/",
      data.orgaoEntidade.cnpj,
      "/",
      data.anoCompra,
      "/",
      data.sequencialCompra
    )
  )

# Filtra somente as contratações de medicamentos
contratacoes <- contratacoes %>%
  semi_join(medicamentos, by = join_by(endpoint == endpointContratacao))

# Adiciona a classificação versionada de compras judiciais
contratacoes <- adiciona_classificacao_compras_judiciais(
  contratacoes,
  classificacao_compras_judiciais
)


# EXTRAI TABELAS----------------------------------------------------------

# Cria a tabela "contratante"
{
  # Todos os contratantes coletados
  tb_contratante <- contratacoes %>% select(all_of(COLUNAS_CONTRATANTE))

  # Todos os contratantes subrogados coletados
  tb_contratante_subrogado <- contratacoes %>%
    select(all_of(COLUNAS_CONTRATANTE_SUBROGADO)) %>%
    filter(!is.na(data.orgaoSubRogado.cnpj) &
             !is.na(data.unidadeSubRogada.codigoUnidade))

  # Deixa os dataframes com os mesmos nomes de colunas (para uní-los)
  names(tb_contratante_subrogado) <- names(tb_contratante)

  # Certifica-se que os dataframes possuem colunas de mesmo tipo (para uní-los)
  tb_contratante_subrogado <- map2_dfr(tb_contratante_subrogado, tb_contratante, ~ as(.x, class(.y)))

  # Une os dataframes em uma única tabela de contratantes
  tb_contratante <- bind_rows(tb_contratante, tb_contratante_subrogado) %>%
    distinct(data.orgaoEntidade.cnpj,
             data.unidadeOrgao.codigoUnidade,
             .keep_all = TRUE)
}

# Cria a tabela "contratacao"
{
  tb_contratacao <- contratacoes %>%
    select(all_of(COLUNAS_CONTRATACAO)) %>%
    distinct(data.numeroControlePNCP, .keep_all = TRUE)
}

# Cria a tabela "fornecedor"
{
  tb_fornecedor <- resultados %>%
    select(all_of(COLUNAS_FORNECEDOR)) %>%
    distinct(niFornecedor, .keep_all = TRUE)
}

# Cria a tabela "item_homologado" (item com resultado)
{
  # Une as contratações, itens e resultados em um único dataframe
  tb_item_homologado <- medicamentos %>%
    inner_join(
      resultados,
      by = join_by(endpointResultado == endpoint),
      suffix = c("", "Resultado"),
      multiple = "first"
    ) %>% # se ouver mais de um resultado, usar só o primeiro
    inner_join(
      contratacoes,
      by = join_by(endpointContratacao == endpoint),
      suffix = c("", "Contratacao")
    )

  # Seleciona apenas as colunas que serão inseridas no banco de dados
  tb_item_homologado <- tb_item_homologado %>% select(any_of(COLUNAS_ITEM_HOMOLOGADO))

  # Se houver colunas faltantes, elas são preenchidas como NA
  colunas_faltantes <- setdiff(COLUNAS_ITEM_HOMOLOGADO, names(tb_item_homologado))
  for (col in colunas_faltantes) {
    tb_item_homologado[col] <- NA
  }

  # Organiza as colunas na ordem correta de inserção
  tb_item_homologado <- tb_item_homologado[COLUNAS_ITEM_HOMOLOGADO]
}

# Cria a tabela "item_licitado" (item sem resultado)
{
  # Seleciona apenas os itens que não possuem resultado
  tb_item_licitado <- medicamentos %>%
    anti_join(resultados, by = join_by(endpointResultado == endpoint)) %>%
    inner_join(
      contratacoes,
      by = join_by(endpointContratacao == endpoint),
      suffix = c("", "Contratacao")
    )

  # Seleciona apenas as colunas que serão inseridas no banco de dados
  tb_item_licitado <- tb_item_licitado %>% select(any_of(COLUNAS_ITEM_LICITADO))

  # Se houver colunas faltantes, elas são preenchidas como NA
  colunas_faltantes <- setdiff(COLUNAS_ITEM_LICITADO, names(tb_item_licitado))
  for (col in colunas_faltantes) {
    tb_item_licitado[col] <- NA
  }

  # Organiza as colunas na ordem correta de inserção
  tb_item_licitado <- tb_item_licitado[COLUNAS_ITEM_LICITADO]
}


# CONECTA-SE  COM O BD ----------------------------------------------------

con <- conecta_bd_medicamentos_transparentes()

contagens_historico_antes <- contar_tabelas_historico(con)


# INSERE OS DADOS ---------------------------------------------------------

# Contratantes
insere_tabela(con, tb_contratante, CONSULTA_INSERIR_CONTRATANTE)

# Fornecedores
insere_tabela(con, tb_fornecedor, CONSULTA_INSERIR_FORNECEDOR)

# Contratações
insere_tabela(con, tb_contratacao, CONSULTA_INSERIR_CONTRATACAO)

# Itens homologados
insere_tabela(con, tb_item_homologado, CONSULTA_INSERIR_ITEM_HOMOLOGADO)

# Itens licitados
insere_tabela(con, tb_item_licitado, CONSULTA_INSERIR_ITEM_LICITADO)

contagens_historico_depois <- contar_tabelas_historico(con)

linhas_historico <- montar_linhas_historico(
  rotina = "carga_dados",
  contagens_antes = contagens_historico_antes,
  contagens_depois = contagens_historico_depois,
  caminhos_origem = c(CAMINHO_CONTRATACOES, CAMINHO_MEDICAMENTOS, CAMINHO_RESULTADOS)
)

registrar_historico_cargas(linhas_historico)

# Fecha a conexão com o BD
dbDisconnect(con)
