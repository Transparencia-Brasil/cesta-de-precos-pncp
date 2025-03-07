#' Documente o script
#' 

# 1. Ler os arquivos a serem processados
# 2. Fazer as transformacoes e
# 3. Inserir no banco

suppressPackageStartupMessages(library(readr))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(here))
suppressPackageStartupMessages(library(purrr))
suppressPackageStartupMessages(library(DBI))
suppressPackageStartupMessages(library(RPostgres))

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

# LEMBRAR DE REMOVER ISSO DEPOIS
contratacoes <- read_csv("src/coletores/amostra_contratacoes.csv")
medicamentos <- read_csv("src/coletores/amostra_medicamentos.csv")
resultados <- read_csv("src/coletores/amostra_resultados.csv")

# Remove linhas onde 'endpoint' é NA.
# Idealmente nenhuma linha seria removida. Mas pode haver má formatação do dado
# durante a coleta.
contratacoes <- contratacoes %>% filter(!is.na(endpoint))
medicamentos <- medicamentos %>% filter(!is.na(endpoint))
resultados <- resultados %>% filter(!is.na(endpoint))

# Cria chaves para fazer joins e adiciona URLs úteis
medicamentos <- medicamentos %>%
  mutate(
    endpointResultado = paste0(endpoint, "/", numeroItem, "/resultados"),
    endpointContratacao = sub("/itens$", "", endpoint),
    urlAPI = paste0(endpoint, "/", numeroItem)
  )

# Cria chaves para fazer joins e adiciona URLs úteis
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

# Constrói o dataset de itens homologados (itens com resultado)
itens_homologados <- medicamentos %>%
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

# Constrói o dataset de itens ainda não homologados (itens sem resultado)
itens_licitados <- medicamentos %>%
  anti_join(resultados, by = join_by(endpointResultado == endpoint)) %>%
  inner_join(
    contratacoes,
    by = join_by(endpointContratacao == endpoint),
    suffix = c("", "Contratacao")
  )


# EXTRAI TABELAS----------------------------------------------------------

colunas_id <- c("data.numeroControlePNCP", "numeroItem")

colunas_contratante <- c(
  "data.orgaoEntidade.cnpj",
  "data.orgaoEntidade.razaoSocial",
  "data.orgaoEntidade.esferaId",
  "data.orgaoEntidade.poderId",
  "data.unidadeOrgao.codigoUnidade",
  "data.unidadeOrgao.nomeUnidade",
  "data.unidadeOrgao.codigoIbge",
  "data.unidadeOrgao.municipioNome",
  "data.unidadeOrgao.ufSigla",
  "data.unidadeOrgao.ufNome"
)

colunas_contratante_subrogado <- c(
  "data.orgaoSubRogado.cnpj",
  "data.orgaoSubRogado.razaoSocial",
  "data.orgaoSubRogado.esferaId",
  "data.orgaoSubRogado.poderId",
  "data.unidadeSubRogada.codigoUnidade",
  "data.unidadeSubRogada.nomeUnidade",
  "data.unidadeSubRogada.codigoIbge",
  "data.unidadeSubRogada.municipioNome",
  "data.unidadeSubRogada.ufSigla",
  "data.unidadeSubRogada.ufNome"
)

colunas_fornecedor <- c(
  "niFornecedor",
  "nomeRazaoSocialFornecedor",
  "codigoPais",
  "tipoPessoa",
  "porteFornecedorId",
  "porteFornecedorNome",
  "naturezaJuridicaId",
  "naturezaJuridicaNome"
)

colunas_item_homologado <- c(
  "data.numeroControlePNCP",
  "data.anoCompra",
  "data.sequencialCompra",
  "data.tipoInstrumentoConvocatorioCodigo",
  "data.tipoInstrumentoConvocatorioNome",
  "data.modalidadeId",
  "data.modalidadeNome",
  "data.amparoLegal.codigo",
  "data.amparoLegal.nome",
  "data.modoDisputaId",
  "data.modoDisputaNome",
  "data.objetoCompra",
  "data.dataAberturaProposta",
  "data.dataEncerramentoProposta",
  "data.valorTotalEstimado",
  "data.valorTotalHomologado",
  "data.srp",
  "numeroItem",
  "descricao",
  "unidadeMedida",
  "materialOuServico",
  "itemCategoriaId",
  "itemCategoriaNome",
  "catalogo",
  "categoriaItemCatalogo",
  "catalogoCodigoItem",
  "ncmNbsCodigo",
  "ncmNbsDescricao",
  "criterioJulgamentoId",
  "criterioJulgamentoNome",
  "situacaoCompraItem",
  "situacaoCompraItemNome",
  "tipoBeneficio",
  "tipoBeneficioNome",
  "orcamentoSigiloso",
  "valorUnitarioEstimado",
  "valorTotal",
  "quantidade",
  "situacaoCompraItemResultadoId",
  "situacaoCompraItemResultadoNome",
  "valorUnitarioHomologado",
  "valorTotalHomologado",
  "quantidadeHomologada",
  "moedaEstrangeira",
  "valorNominalMoedaEstrangeira",
  "dataResultado",
  "dataCancelamento",
  "motivoCancelamento",
  "urlAPI",
  "urlPNCP"
)

# Cria a tabela "contratante"
tb_contratante <- itens_homologados %>% select(all_of(c(colunas_id, colunas_contratante)))

# Cria a tabela "contratante subrogado". O Contratante subrogado é inserido
# na mesma tabela que os demais contratantes, mas é preciso identificá-los como subrogado.
tb_contratante_subrogado <- itens_homologados %>% select(all_of(c(colunas_id, colunas_contratante_subrogado)))
  
# elimina as linhas em que todas as colunas de subrogado são NA, isto é, não houve órgão subrogado.
tb_contratante_subrogado <- tb_contratante_subrogado[rowSums(is.na(tb_contratante_subrogado)) < ncol(tb_contratante_subrogado)-2, ]

# Cria a tabela "fornecedor"
tb_fornecedor <- itens_homologados %>% select(all_of(colunas_fornecedor))

# Cria a tabela "processo_licitatório"
tb_processo_licitatorio <- itens_homologados %>% select(all_of(colunas_processo_licitatorio))

# Cria a tabela "item_homologado"
tb_item_homologado <- itens_homologados %>% select(all_of(colunas_item_homologado))


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

query_contratante <- "
-- Primeiro, insira o novo registro e retorne o id
WITH insercao AS (
    INSERT INTO contratante (cnpj, razao_social, esfera, poder, codigo_unidade,
    nome_unidade, codigo_ibge_municipio, nome_municipio, sigla_uf, nome_uf)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
    ON CONFLICT (cnpj, codigo_unidade) DO NOTHING
    RETURNING id
)
SELECT id FROM insercao
UNION
-- Caso o registro já exista na tabela, apenas retorne-o
SELECT id
FROM contratante
WHERE cnpj = $1
  AND codigo_unidade = $5
"

# Loop para inserir os contratantes e retornar os ids
for (i in 1:nrow(tb_contratante)) {
  id <- dbGetQuery(con, query_contratante, params = as.list(unname(tb_contratante[i, colunas_contratante])))
  tb_contratante[i, "id"] <- id
}

# Se houver algum contratante subrogado, insere-o como contratante
if (nrow(tb_contratante_subrogado) > 0) {
  # Loop para inserir os contratantes subrogados e retornar os ids
  for (i in 1:nrow(tb_contratante_subrogado)) {
    id <- dbGetQuery(con, query_contratante, params = as.list(unname(tb_contratante_subrogado[i, colunas_contratante_subrogado])))
    tb_contratante_subrogado[i, "id"] <- id
  }
}

query_fornecedor <- "
-- Primeiro, insira o novo registro e retorne o id
WITH insercao AS (
    INSERT INTO fornecedor (ni, nome, codigo_pais, tipo_pessoa, codigo_porte,
    nome_porte, codigo_natureza_juridica, nome_natureza_juridica)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
    ON CONFLICT (ni) DO NOTHING
    RETURNING id
)
SELECT id FROM insercao
UNION
-- Caso o registro já exista na tabela, apenas retorne-o
SELECT id 
FROM fornecedor
WHERE ni = $1
"

# Loop para inserir os fornecedores e retornar os ids
for (i in 1:nrow(tb_fornecedor)) {
  id <- dbGetQuery(con, query_fornecedor, params = as.list(unname(tb_fornecedor[i, colunas_fornecedor])))
  tb_fornecedor[i, "id"] <- id
}




# Fechar conexão
dbDisconnect(con)





