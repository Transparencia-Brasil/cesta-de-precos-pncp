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
suppressPackageStartupMessages(library(RPostgres))

source(here("src/ETL/loaders/utils.R"))

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

# Remove linhas onde 'endpoint' é NA.
# Idealmente nenhuma linha seria removida. Mas pode haver má formatação do dado
# durante a coleta.
contratacoes <- contratacoes %>% filter(!is.na(endpoint))
medicamentos <- medicamentos %>% filter(!is.na(endpoint))
resultados <- resultados %>% filter(!is.na(endpoint))

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

consulta_insere_contratante <- "
    INSERT INTO contratante (cnpj, razao_social, esfera, poder, codigo_unidade,
    nome_unidade, codigo_ibge_municipio, nome_municipio, sigla_uf, nome_uf)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
    ON CONFLICT (cnpj, codigo_unidade) DO NOTHING
"

insere_tabela(con, tb_contratante, consulta_insere_contratante)

consulta_insere_fornecedor <- "
    INSERT INTO fornecedor (ni, nome, codigo_pais, tipo_pessoa, codigo_porte,
    nome_porte, codigo_natureza_juridica, nome_natureza_juridica)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
    ON CONFLICT (ni) DO NOTHING
"

insere_tabela(con, tb_fornecedor, consulta_insere_fornecedor)

# Insere uma contratação nova ou, caso a contratação já exista no banco, atualiza os campos
consulta_insere_contratacao <- "
INSERT INTO contratacao (
    numero_controle_pncp, ano_compra, sequencial_compra, objeto_compra,
    data_abertura_proposta, data_encerramento_proposta,
    valor_estimado_compra, valor_homologado_compra, srp,
    codigo_tipo_instrumento_convocatorio, nome_tipo_instrumento_convocatorio,
    codigo_modalidade, nome_modalidade,
    codigo_amparo_legal, nome_amparo_legal,
    codigo_modo_disputa, nome_modo_disputa
)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
ON CONFLICT (numero_controle_pncp) 
DO UPDATE SET
    objeto_compra = $4,
    data_abertura_proposta = $5,
    data_encerramento_proposta = $6,
    valor_estimado_compra = $7,
    valor_homologado_compra = $8,
    srp = $9,
    codigo_tipo_instrumento_convocatorio = $10,
    nome_tipo_instrumento_convocatorio = $11,
    codigo_modalidade = $12,
    nome_modalidade = $13,
    codigo_amparo_legal = $14,
    nome_amparo_legal = $15,
    codigo_modo_disputa = $16,
    nome_modo_disputa = $17;
"

insere_tabela(con, tb_contratacao, consulta_insere_contratacao)

# Insere um item novo ou, caso o item já exista no banco, atualiza os campos
consulta_insere_item_homologado <- "
    INSERT INTO item_homologado (
        numero_controle_pncp, codigo_item_catalogo,
        cnpj_contratante, codigo_unidade_contratante,
        cnpj_contratante_subrogado, codigo_unidade_contratante_subrogado,
        ni_fornecedor,
        numero_item, descricao, unidade_medida, material_servico,
        codigo_categoria_item, nome_categoria_item,
        codigo_catalogo, nome_catalogo,
        codigo_categoria_item_catalogo, nome_categoria_item_catalogo,
        codigo_item_catalogo_pncp,
        codigo_ncm_nbs, descricao_ncm_nbs,
        codigo_criterio_julgamento, nome_criterio_julgamento,
        codigo_situacao_item, nome_situacao_item,
        codigo_tipo_beneficio, nome_tipo_beneficio,
        orcamento_sigiloso,
        valor_unitario_estimado, valor_total_estimado, quantidade_estimada,
        codigo_situacao_resultado, nome_situacao_resultado,
        valor_unitario_homologado, valor_total_homologado, quantidade_homologada,
        moeda_estrangeira, valor_nominal_moeda_estrangeira,
        data_resultado, data_cancelamento, motivo_cancelamento,
        url_api, url_pncp)
    VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
        $11, $12, $13, $14, $15, $16, $17, $18, $19, $20,
        $21, $22, $23, $24, $25, $26, $27, $28, $29, $30,
        $31, $32, $33, $34, $35, $36, $37, $38, $39, $40,
        $41, $42)
    ON CONFLICT (numero_controle_pncp, numero_item) 
    DO UPDATE SET
        codigo_item_catalogo = $2,
        cnpj_contratante_subrogado = $5, 
        codigo_unidade_contratante_subrogado = $6,
        ni_fornecedor = $7,
        descricao = $9, 
        unidade_medida = $10, 
        material_servico = $11,
        codigo_categoria_item = $12, 
        nome_categoria_item = $13,
        codigo_catalogo = $14,
        nome_catalogo = $15,
        codigo_categoria_item_catalogo = $16, 
        nome_categoria_item_catalogo = $17,
        codigo_item_catalogo_pncp = $18,
        codigo_ncm_nbs = $19, 
        descricao_ncm_nbs = $20,
        codigo_criterio_julgamento = $21, 
        nome_criterio_julgamento = $22,
        codigo_situacao_item = $23, 
        nome_situacao_item = $24,
        codigo_tipo_beneficio = $25, 
        nome_tipo_beneficio = $26,
        orcamento_sigiloso = $27,
        valor_unitario_estimado = $28, 
        valor_total_estimado = $29, 
        quantidade_estimada = $30,
        codigo_situacao_resultado = $31, 
        nome_situacao_resultado = $32,
        valor_unitario_homologado = $33, 
        valor_total_homologado = $34, 
        quantidade_homologada = $35,
        moeda_estrangeira = $36, 
        valor_nominal_moeda_estrangeira = $37,
        data_resultado = $38, 
        data_cancelamento = $39, 
        motivo_cancelamento = $40;
"

insere_tabela(con, tb_item_homologado, consulta_insere_item_homologado)

# Insere um item novo ou, caso o item já exista no banco, atualiza os campos
consulta_insere_item_licitado <- "
    INSERT INTO item_licitado (
        numero_controle_pncp, codigo_item_catalogo,
        cnpj_contratante, codigo_unidade_contratante,
        cnpj_contratante_subrogado, codigo_unidade_contratante_subrogado,
        numero_item, descricao, unidade_medida, material_servico,
        codigo_categoria_item, nome_categoria_item,
        codigo_catalogo, nome_catalogo,
        codigo_categoria_item_catalogo, nome_categoria_item_catalogo,
        codigo_item_catalogo_pncp,
        codigo_ncm_nbs, descricao_ncm_nbs,
        codigo_criterio_julgamento, nome_criterio_julgamento,
        codigo_situacao_item, nome_situacao_item,
        codigo_tipo_beneficio, nome_tipo_beneficio,
        orcamento_sigiloso,
        valor_unitario_estimado, valor_total_estimado, quantidade_estimada,
        url_api, url_pncp)
    VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
        $11, $12, $13, $14, $15, $16, $17, $18, $19, $20,
        $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, $31)
    ON CONFLICT (numero_controle_pncp, numero_item)
    DO UPDATE SET
        codigo_item_catalogo = $2,
        cnpj_contratante_subrogado = $5, 
        codigo_unidade_contratante_subrogado = $6,
        descricao = $8, 
        unidade_medida = $9, 
        material_servico = $10,
        codigo_categoria_item = $11, 
        nome_categoria_item = $12,
        codigo_catalogo = $13,
        nome_catalogo = $14,
        codigo_categoria_item_catalogo = $15, 
        nome_categoria_item_catalogo = $16,
        codigo_item_catalogo_pncp = $17,
        codigo_ncm_nbs = $18, 
        descricao_ncm_nbs = $19,
        codigo_criterio_julgamento = $20, 
        nome_criterio_julgamento = $21,
        codigo_situacao_item = $22, 
        nome_situacao_item = $23,
        codigo_tipo_beneficio = $24, 
        nome_tipo_beneficio = $25,
        orcamento_sigiloso = $26,
        valor_unitario_estimado = $27, 
        valor_total_estimado = $28, 
        quantidade_estimada = $29;
"

insere_tabela(con, tb_item_licitado, consulta_insere_item_licitado)

# Fecha a conexão com o BD
dbDisconnect(con)
