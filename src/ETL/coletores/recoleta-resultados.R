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

source(here("src/ETL/coletores/utils.R"))
source(here("src/ETL/loaders/utils.R"))


# PARÂMETROS DE ENTRADAS -------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)

# Verifica se o argumento foi passado, caso contrário, define um padrão
PATH_OUTPUT_DIR <- ifelse(length(args) >= 1,
                          args[1],
                          here("coleta", "resultados", "itens-licitados"))
# PATH_OUTPUT_DIR <- here("coleta/resultados/2025-09/QUINZENA-2/recoleta")

# CONECTA-SE AO BANCO ----------------------------------------------------------

con <- conecta_bd_medicamentos_transparentes()


# EXTRAI LISTA DE ITENS AINDA NÃO HOMOLOGADOS ----------------------------------

# Tabela de itens licitados mas não homologados
query <- "SELECT * FROM item_licitado;"
tb_item_licitado <- dbGetQuery(con, query)

message("Itens licitados ainda não homologados:")
print(as_tibble(tb_item_licitado))

# Gera endpoints de resultados a partir dos endpoints de itens
endpoints_resultados = paste0(tb_item_licitado$url_api, "/resultados")


# RECOLETA OS RESULTADOS -------------------------------------------------------

# TEMPLATE ---------------------------------------------------------------------
# Mapear todas as colunas que serão coletadas e garantir balanceamento do dataset

# referência: https://pncp.gov.br/api/pncp/swagger-ui/index.html#/Contrata%C3%A7%C3%A3o/recuperarResultados
template_resultados_itens <- tibble::tibble(
  # ids
  numeroControlePNCPCompra = character(),
  numeroItem = character(),
  endpoint = character(),
  sequencialResultado = character(),
  # Situação da compra
  situacaoCompraItemResultadoId = character(),
  situacaoCompraItemResultadoNome = character(),
  # data inclusão e atualização
  dataInclusao = character(),
  dataAtualizacao = character(),
  # Fornecedor
  niFornecedor = character(),
  nomeRazaoSocialFornecedor = character(),
  tipoPessoa = character(),
  porteFornecedorId = character(),
  porteFornecedorNome = character(),
  naturezaJuridicaId = character(),
  naturezaJuridicaNome = character(),
  codigoPais = character(),
  # Quantidades e valores
  quantidadeHomologada = character(),
  valorUnitarioHomologado = character(),
  valorTotalHomologado = character(),
  percentualDesconto = character(),
  # País de origem
  paisOrigemProdutoServico.id = character(),
  paisOrigemProdutoServico.nome = character(),
  # Moeda estrangeira
  moedaEstrangeira.id = character(),
  moedaEstrangeira.simbolo = character(),
  moedaEstrangeira.nome = character(),
  timezoneCotacaoMoedaEstrangeira = character(),
  valorNominalMoedaEstrangeira = character(),
  dataCotacaoMoedaEstrangeira = character(),
  # Margem preferência + amparo legal
  aplicacaoMargemPreferencia = character(),
  amparoLegalMargemPreferencia.id = character(),
  amparoLegalMargemPreferencia.nome = character(),
  amparoLegalMargemPreferencia.descricao = character(),
  amparoLegalMargemPreferencia.statusAtivo = character(),
  # benefício ME/EPP
  aplicacaoBeneficioMeEpp = character(),
  # Critério de desempate + amparo legal
  aplicacaoCriterioDesempate = character(),
  amparoLegalCriterioDesempate.id = character(),
  amparoLegalCriterioDesempate.nome = character(),
  amparoLegalCriterioDesempate.descricao = character(),
  amparoLegalCriterioDesempate.statusAtivo = character(),
  # subcontratação
  indicadorSubcontratacao = character(),
  # classificação SRP
  ordemClassificacaoSrp = character(),
  # resultado/cancelamento
  dataResultado = character(),
  dataCancelamento = character(),
  motivoCancelamento = character(),
)

# Executa a coleta com template definido
coleta(endpoints = endpoints_resultados, output_dir = PATH_OUTPUT_DIR, template = template_resultados_itens)


# INSERE RESULTADOS NO BANCO ---------------------------------------------------

CAMINHO_RESULTADOS <- here(PATH_OUTPUT_DIR, "dados.csv")
resultados <- read_csv(CAMINHO_RESULTADOS, show_col_types = FALSE)


# Colunas da tabela item_licitado + colunas dos resultados do PNCP
COLUNAS_ITEM_HOMOLOGADO <- c(
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
  "moedaEstrangeira.simbolo",          # Essa coluna vem dos resultados
  "valorNominalMoedaEstrangeira",      # Essa coluna vem dos resultados
  "dataResultado",                     # Essa coluna vem dos resultados
  "dataCancelamento",                  # Essa coluna vem dos resultados
  "motivoCancelamento",                # Essa coluna vem dos resultados
  "url_api",
  "url_pncp"
)


# Cria a tabela "fornecedor"
{
  message('Cria a tabela "fornecedor"')
  tb_fornecedor <- resultados %>%
    select(all_of(COLUNAS_FORNECEDOR)) %>%
    distinct(niFornecedor, .keep_all = TRUE)
}


# Une os resultados dos itens ao restante das informações para criar a tabela item_homologado
{
  message('Une os resultados dos itens ao restante das informações para criar a tabela item_homologado')
  tb_item_homologado <- tb_item_licitado %>%
    inner_join(
      resultados,
      by = join_by(
        numero_controle_pncp == numeroControlePNCPCompra,
        numero_item == numeroItem
      ),
      suffix = c("", "Resultado"),
      multiple = "first" # se ouver mais de um resultado, usar só o primeiro
    ) %>%
    as_tibble() |>
    select(all_of(COLUNAS_ITEM_HOMOLOGADO))
}

# Contages antes da inserção

n_fornecedores_antes <- get_query("select count(*) from fornecedor;") |>
  pull(count) |>
  as.integer()

n_itens_hmologados_antes <- get_query("select count(*) from item_homologado;") |>
  pull(count) |>
  as.integer()


# Insere os fornecedores -------------------------------------------------------

insere_tabela(con, tb_fornecedor, CONSULTA_INSERIR_FORNECEDOR)

n_fornecedores_depois <- get_query("select count(*) from fornecedor;") |>
  pull(count) |>
  as.integer()

msg <- sprintf("Foram inseridos %d novos fornecedores.", n_fornecedores_depois - n_fornecedores_antes)
message(msg)
message("\r\nAntes:", n_fornecedores_antes, "\r\nDepois:", n_fornecedores_depois)


# Insere os itens homologados --------------------------------------------------

insere_tabela(con, tb_item_homologado, CONSULTA_INSERIR_ITEM_HOMOLOGADO)

n_itens_homologados_depois <- get_query("select count(*) from item_homologado;") |>
  pull(count) |>
  as.integer()

msg <- sprintf("Foram inseridos %d novos fornecedores.", n_itens_homologados_depois - n_itens_homologados_antes)
message(msg)
message("\r\nAntes:", n_itens_homologados_antes, "\r\nDepois:", n_itens_homologados_depois)

# REMOVE ITENS HOMOLOGADOS DA TABELA ITEM_LICITADO ------------------------

ids_itens_homologados <- tb_item_homologado %>%
  select(numero_controle_pncp, numero_item) |>
  as_tibble()

message("IDs dos itens homologados que serão removidos da tabela item_licitado:")
print(ids_itens_homologados)

# Inicia a transação manualmente
dbBegin(con)

# Exemplo: dropar se existir e recriar
dbExecute(con, "DROP TABLE IF EXISTS temp_ids")

# Cria uma tabela temporária no banco para inserir IDs
dbExecute(
  con,
  "CREATE TEMP TABLE temp_ids (
      numero_controle_pncp VARCHAR(30),
      numero_item INTEGER,
      PRIMARY KEY (numero_controle_pncp, numero_item)) ON COMMIT DROP"
)

# Inseri os IDs na tabela temporária
dbWriteTable(con, "temp_ids", ids_itens_homologados, overwrite = TRUE, row.names = FALSE)

message("Conteúdo da tabela temporária temp_ids:")
get_query("select * from temp_ids;")

message("Removendo itens homologados da tabela item_licitado...")
n_itens_licitado_antes <- get_query("select count(*) from item_licitado") |>
  pull(count) |>
  as.integer()


# Executa o DELETE usando JOIN
dbExecute(
  con,
  "DELETE FROM item_licitado USING temp_ids
  WHERE item_licitado.numero_controle_pncp = temp_ids.numero_controle_pncp
  AND item_licitado.numero_item = temp_ids.numero_item"
)


# Confirmar as mudanças (commit da transação)
dbCommit(con)

# Confirmação da remoção
n_itens_licitado_depois <- get_query("select count(*) from item_licitado") |>
  pull(count) |>
  as.integer()

msg <- sprintf(
  "Foram removidos %d itens homologados da tabela item_licitado.",
  n_itens_licitado_antes - n_itens_licitado_depois
)
message(msg)
message("\r\nAntes:", n_itens_licitado_antes, "\r\nDepois:", n_itens_licitado_depois)


# Fecha a conexão com o BD
dbDisconnect(con)

message("Fim da recoleta de resultados.")
