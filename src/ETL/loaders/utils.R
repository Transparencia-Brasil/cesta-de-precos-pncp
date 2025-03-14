#'
#'
#'

suppressPackageStartupMessages(library(DBI))

# Mapeamento entre colunas dos arquivos do PNCP e colunas do banco de dados
{
  COLUNAS_CONTRATANTE <- c(
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
  
  COLUNAS_CONTRATANTE_SUBROGADO <- c(
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
  
  COLUNAS_FORNECEDOR <- c(
    "niFornecedor",
    "nomeRazaoSocialFornecedor",
    "codigoPais",
    "tipoPessoa",
    "porteFornecedorId",
    "porteFornecedorNome",
    "naturezaJuridicaId",
    "naturezaJuridicaNome"
  )
  
  COLUNAS_CONTRATACAO <- c(
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
  
  COLUNAS_ITEM_HOMOLOGADO <- c(
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
  
  COLUNAS_ITEM_LICITADO <- c(
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
}


#' Insere os dados de um dataframe em um banco de dados PostgreSQL
#'
#' Esta função percorre todas as linhas de um dataframe e executa uma consulta SQL 
#' para inseri-las no banco de dados. Se ocorrer um erro ao inserir uma linha, 
#' uma mensagem de aviso é exibida com o índice da linha e o nome da tabela de origem.
#'
#' @param con Conexão ativa com o banco de dados, criada com `DBI::dbConnect()`.
#' @param tabela Dataframe contendo os dados a serem inseridos no banco.
#' @param consulta Consulta SQL parametrizada (`INSERT INTO ... VALUES ($1, $2, ...)`) 
#' para inserção dos dados.
#'
#' @return Nenhum valor é retornado explicitamente. As inserções são feitas diretamente 
#' no banco de dados.
#'
#' @examples
#' \dontrun{
#' con <- DBI::dbConnect(RPostgres::Postgres(), dbname = "meubanco", user = "usuario", password = "senha")
#' 
#' df <- data.frame(id = 1:3, nome = c("A", "B", "C"))
#' 
#' query <- "INSERT INTO minha_tabela (id, nome) VALUES ($1, $2)"
#' 
#' insere_tabela(con, df, query)
#' 
#' DBI::dbDisconnect(con)
#' }
#' 
#' @import DBI
#' @import RPostgres
insere_tabela <- function(con, tabela, consulta) {
  for (i in 1:nrow(tabela)) {
    tryCatch({
      dbExecute(con, consulta, params = as.list(unname(tabela[i, ])))
    }, error = function(e) {
      nome_tabela <- deparse(substitute(tabela))
      message(sprintf(
        "Erro ao inserir a linha %d da tabela %s: %s",
        i,
        nome_tabela,
        e$message
      ))
    })
  }
}
