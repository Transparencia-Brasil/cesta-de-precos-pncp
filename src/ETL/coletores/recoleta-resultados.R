#' Recoleta resultados de itens ainda não homologados
#' 
#' Descrição - Nem sempre a homologação (resultado) do item estará disponível ao
#' coletar os dados do item contratado. Estes itens ainda não homologados são salvos
#' no banco de dados e a cada coleta esta lista de itens é revisitada para identificar
#' quais já possuem resultado (homologação) que pode ser coletado.
#' 
#' Entrada:  
#'  * Lista de identificadores de itens (medicamentos) que ainda não foram homologados.
#'    (essa lista vem do banco de dados. Ela não é passada como parâmetro do script)
#'  * Tem o parâmetro opcional que é o diretório onde os resultados da coleta serão salvos.
#'    (similar aos outros arquivos da coleta)
#' 
#' Saída:
#'  * Arquivo com os resultados dos itens das contratações
#'  * Arquivo de log de monitoramento da coleta
#'  * Arquivo com erros de coleta
#' 
#' Resultado:
#'   * Os dados coletados deverão ser inseridos no banco no formato correspondente.
#'   * Os itens homologados devem ser removidos da lista de itens ainda não homologados.
#'   

suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(here))
suppressPackageStartupMessages(library(readr))
suppressPackageStartupMessages(library(DBI))
suppressPackageStartupMessages(library(RPostgres))

source(here("src/ETL/coletores/funcoes.R"))

# PARÂMETROS DE ENTRADAS --------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)

# Verifica se o argumento foi passado, caso contrário, define um padrão
PATH_OUTPUT_DIR <- ifelse(length(args) >= 1,
                          args[1],
                          here("coleta", "resultados", "itens-licitados"))


# CONECTA-SE AO BANCO -----------------------------------------------------

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


# EXTRAI LISTA DE ITENS AINDA NÃO HOMOLOGADOS -----------------------------

# Tabela de itens licitados mas não homologados
query <- "SELECT * FROM item_licitado;"
tb_item_licitado <- dbGetQuery(con, query)

# Gera endpoints de resultados a partir dos endpoints de itens
endpoints_resultados = paste0(tb_item_licitado$url_api, "/resultados")

# RECOLETA OS RESULTADOS --------------------------------------------------

# Executa a coleta
coleta(endpoints = endpoints_resultados, output_dir = PATH_OUTPUT_DIR)


# INSERE RESULTADOS NO BANCO ----------------------------------------------

CAMINHO_RESULTADOS <- here(PATH_OUTPUT_DIR, "dados.csv")
resultados <- read_csv(CAMINHO_RESULTADOS, show_col_types = FALSE)

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
  "numero_controle_pncp",
  "codigo_item_catalogo",
  "cnpj_contratante",
  "codigo_unidade_contratante",
  "cnpj_contratante_subrogado",
  "codigo_unidade_contratante_subrogado",
  "niFornecedor",                      # Essa coluna vem dos resultados
  "numero_item",
  "descricao",
  "unidade_medida",
  "material_servico",
  "codigo_categoria_item",
  "nome_categoria_item",
  "codigo_catalogo",
  "nome_catalogo",
  "codigo_categoria_item_catalogo",
  "nome_categoria_item_catalogo",
  "codigo_item_catalogo_pncp",
  "codigo_ncm_nbs",
  "descricao_ncm_nbs",
  "codigo_criterio_julgamento",
  "nome_criterio_julgamento",
  "codigo_situacao_item",
  "nome_situacao_item",
  "codigo_tipo_beneficio",
  "nome_tipo_beneficio",
  "orcamento_sigiloso",
  "valor_unitario_estimado",
  "valor_total_estimado",
  "quantidade_estimada",
  "situacaoCompraItemResultadoId",     # Essa coluna vem dos resultados
  "situacaoCompraItemResultadoNome",   # Essa coluna vem dos resultados
  "valorUnitarioHomologado",           # Essa coluna vem dos resultados
  "valorTotalHomologado",              # Essa coluna vem dos resultados
  "quantidadeHomologada",              # Essa coluna vem dos resultados
  "moedaEstrangeira",                  # Essa coluna vem dos resultados
  "valorNominalMoedaEstrangeira",      # Essa coluna vem dos resultados
  "dataResultado",                     # Essa coluna vem dos resultados
  "dataCancelamento",                  # Essa coluna vem dos resultados
  "motivoCancelamento",                # Essa coluna vem dos resultados
  "url_api",
  "url_pncp"
)

# Cria a tabela "fornecedor"
{
  tb_fornecedor <- resultados %>%
    select(all_of(colunas_fornecedor)) %>%
    distinct(niFornecedor, .keep_all = TRUE)
}

# Une os resultados dos itens ao restante das informações
tb_item_homologado <- tb_item_licitado %>%
  inner_join(
    resultados,
    by = join_by(numero_controle_pncp == numeroControlePNCPCompra, numero_item == numeroItem),
    suffix = c("", "Resultado"),
    multiple = "first" # se ouver mais de um resultado, usar só o primeiro
  ) %>% 
  select(all_of(colunas_item_homologado))


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
    ON CONFLICT (numero_controle_pncp, numero_item) DO NOTHING;
"


# Loop para inserir os itens homologados
for (i in 1:nrow(tb_item_homologado)) {
  tryCatch({
    dbExecute(con, query_item_homologado, params = as.list(unname(tb_item_homologado[i, ])))
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


# REMOVE ITENS HOMOLOGADOS DA TABELA ITEM_LICITADO ------------------------

ids_itens_homologados <- tb_item_homologado %>% select(numero_controle_pncp, numero_item)

# Iniciar a transação manualmente
dbBegin(con)

# Cria tabela temporária no PostgreSQL
dbExecute(
  con,
  "CREATE TEMP TABLE temp_ids (
      numero_controle_pncp VARCHAR(30),
      numero_item INTEGER,
      PRIMARY KEY (numero_controle_pncp, numero_item)) ON COMMIT DROP"
)

# Inseri os IDs na tabela temporária
dbWriteTable(con, "temp_ids", ids_itens_homologados, append = TRUE, row.names = FALSE)

# Executa o DELETE usando JOIN
dbExecute(
  con, 
  "DELETE FROM item_licitado USING temp_ids 
  WHERE item_licitado.numero_controle_pncp = temp_ids.numero_controle_pncp
  AND item_licitado.numero_item = temp_ids.numero_item"
)

# Confirmar as mudanças (commit da transação)
dbCommit(con)

# Fecha a conexão com o BD
dbDisconnect(con)
