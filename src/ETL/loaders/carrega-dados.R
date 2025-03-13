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

colunas_contratacao <- c(
  "data.numeroControlePNCP",
  "data.anoCompra",
  "data.sequencialCompra",
  "data.objetoCompra",
  "data.dataAberturaProposta",
  "data.dataEncerramentoProposta",
  "data.valorTotalEstimado",
  "data.valorTotalHomologado",
  "data.srp",
  "data.tipoInstrumentoConvocatorioCodigo",
  "data.tipoInstrumentoConvocatorioNome",
  "data.modalidadeId",
  "data.modalidadeNome",
  "data.amparoLegal.codigo",
  "data.amparoLegal.nome",
  "data.modoDisputaId",
  "data.modoDisputaNome"
)

colunas_item_homologado <- c(
  "data.numeroControlePNCP",
  "codigo_br",
  "data.orgaoEntidade.cnpj",
  "data.unidadeOrgao.codigoUnidade",
  "data.orgaoSubRogado.cnpj",
  "data.unidadeSubRogada.codigoUnidade",
  "niFornecedor",
  "numeroItem",
  "descricao",
  "unidadeMedida",
  "materialOuServico",
  "itemCategoriaId",
  "itemCategoriaNome",
  "catalogo.id",
  "catalogo.nome",
  "categoriaItemCatalogo.id",
  "categoriaItemCatalogo.nome",
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

colunas_item_licitado <- c(
  "data.numeroControlePNCP",
  "codigo_br",
  "data.orgaoEntidade.cnpj",
  "data.unidadeOrgao.codigoUnidade",
  "data.orgaoSubRogado.cnpj",
  "data.unidadeSubRogada.codigoUnidade",
  "numeroItem",
  "descricao",
  "unidadeMedida",
  "materialOuServico",
  "itemCategoriaId",
  "itemCategoriaNome",
  "catalogo.id",
  "catalogo.nome",
  "categoriaItemCatalogo.id",
  "categoriaItemCatalogo.nome",
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
  "urlAPI",
  "urlPNCP"
)

# Cria a tabela "contratante"
{
  # Junta os contratantes dos itens homologados e apenas licitados
  tb_contratante <- itens_homologados %>% select(all_of(colunas_contratante)) %>%
    bind_rows(itens_licitados %>% select(all_of(colunas_contratante))) %>%
    distinct(data.orgaoEntidade.cnpj,
             data.unidadeOrgao.codigoUnidade,
             .keep_all = TRUE)
  
  # Cria a tabela "contratante subrogado". O Contratante subrogado é inserido
  # na mesma tabela que os demais contratantes.
  tb_contratante_subrogado <- itens_homologados %>% select(all_of(colunas_contratante_subrogado)) %>%
    bind_rows(itens_licitados %>% select(all_of(colunas_contratante_subrogado))) %>%
    filter(!is.na(data.orgaoSubRogado.cnpj) &
             !is.na(data.unidadeSubRogada.codigoUnidade)) %>%
    distinct(data.orgaoSubRogado.cnpj,
             data.unidadeSubRogada.codigoUnidade,
             .keep_all = TRUE)
  
  # Deixa as tabelas de contratante e contratante subrogado com as mesmas colunas
  names(tb_contratante_subrogado) <- names(tb_contratante)
  # Certifica-se que as tabelas possuem colunas de mesmo tipo
  tb_contratante_subrogado <- map2_dfr(tb_contratante_subrogado, tb_contratante, ~ as(.x, class(.y)))
  # Une as tabelas em um único dataframe
  tb_contratante <- bind_rows(tb_contratante, tb_contratante_subrogado)
}


# Cria a tabela "contratacao"
{
  tb_contratacao <- itens_homologados %>% select(all_of(colunas_contratacao)) %>%
    bind_rows(itens_licitados %>% select(all_of(colunas_contratacao))) %>%
    distinct(data.numeroControlePNCP, .keep_all = TRUE)
}

# Cria a tabela "fornecedor"
{
  tb_fornecedor <- itens_homologados %>%
    select(all_of(colunas_fornecedor)) %>%
    distinct(niFornecedor, .keep_all = TRUE)
}

# Cria a tabela "item_homologado"
{
  tb_item_homologado <- itens_homologados %>%
    select(any_of(colunas_item_homologado))
  # Se houver colunas faltantes, elas são preenchidas como NA
  colunas_faltantes <- setdiff(colunas_item_homologado, names(tb_item_homologado))
  for (col in colunas_faltantes) {
    tb_item_homologado[col] <- NA
  }
  # Ordena as colunas
  tb_item_homologado <- tb_item_homologado[colunas_item_homologado]
}

# Cria a tabela "item_licitado"
{
  tb_item_licitado <- itens_licitados %>%
    select(any_of(colunas_item_licitado))
  # Se houver colunas faltantes, elas são preenchidas como NA
  colunas_faltantes <- setdiff(colunas_item_licitado, names(tb_item_licitado))
  for (col in colunas_faltantes) {
    tb_item_licitado[col] <- NA
  }
  # Ordena as colunas
  tb_item_licitado <- tb_item_licitado[colunas_item_licitado]
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

query_contratante <- "
    INSERT INTO contratante (cnpj, razao_social, esfera, poder, codigo_unidade,
    nome_unidade, codigo_ibge_municipio, nome_municipio, sigla_uf, nome_uf)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
    ON CONFLICT (cnpj, codigo_unidade) DO NOTHING
"

# Loop para inserir os contratantes
for (i in 1:nrow(tb_contratante)) {
  tryCatch({
    dbExecute(con, query_contratante, params = as.list(unname(tb_contratante[i, colunas_contratante])))
  }, error = function(e) {
    message(
      sprintf(
        "Erro ao inserir o contratante %d (órgão) %d (unidade): %s",
        tb_contratante[[i, 'data.orgaoEntidade.cnpj']],
        tb_contratante[[i, 'data.unidadeOrgao.codigoUnidade']],
        e$message
      )
    )
  })
}

query_fornecedor <- "
    INSERT INTO fornecedor (ni, nome, codigo_pais, tipo_pessoa, codigo_porte,
    nome_porte, codigo_natureza_juridica, nome_natureza_juridica)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
    ON CONFLICT (ni) DO NOTHING
"

# Loop para inserir os fornecedores
for (i in 1:nrow(tb_fornecedor)) {
  tryCatch({
    dbExecute(con, query_fornecedor, params = as.list(unname(tb_fornecedor[i, colunas_fornecedor])))
  }, error = function(e) {
    message(sprintf(
      "Erro ao inserir o fornecedor %s: %s",
      tb_fornecedor[[i, 'niFornecedor']],
      e$message
    ))
  })
}

# Insere uma contratação nova ou, caso a contratação já exista no banco, atualiza os campos
query_contratacao <- "
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

# Loop para inserir as contratacoes
for (i in 1:nrow(tb_contratacao)) {
  tryCatch({
    dbExecute(con, query_contratacao, params = as.list(unname(tb_contratacao[i, colunas_contratacao])))
  }, error = function(e) {
    message(sprintf(
      "Erro ao inserir a contratação %s: %s",
      tb_contratacao[[i, 'data.numeroControlePNCP']],
      e$message
    ))
  })
}

# Insere um item novo ou, caso o item já exista no banco, atualiza os campos
query_item_homologado <- "
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

# Loop para inserir os itens homologados
for (i in 1:nrow(tb_item_homologado)) {
  tryCatch({
    dbExecute(con, query_item_homologado, params = as.list(unname(tb_item_homologado[i, colunas_item_homologado])))
  }, error = function(e) {
    message(
      sprintf(
        "Erro ao inserir o item %s, %i: %s",
        tb_item_homologado[[i, 'data.numeroControlePNCP']],
        tb_item_homologado[[i, 'numeroItem']],
        e$message
      )
    )
  })
}

# Insere um item novo ou, caso o item já exista no banco, atualiza os campos
query_item_licitado <- "
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

# Loop para inserir os itens homologados
for (i in 1:nrow(tb_item_licitado)) {
  tryCatch({
    dbExecute(con, query_item_licitado, params = as.list(unname(tb_item_licitado[i, colunas_item_licitado])))
  }, error = function(e) {
    message(
      sprintf(
        "Erro ao inserir o item %s, %d: %s",
        tb_item_licitado[[i, 'data.numeroControlePNCP']],
        tb_item_licitado[[i, 'numeroItem']],
        e$message
      )
    )
  })
}

# Fecha a conexão com o BD
dbDisconnect(con)
