URL_LOADER_ITENS_CONTRATACOES <- "https://raw.githubusercontent.com/Transparencia-Brasil/cesta-de-precos-pncp/refs/heads/main/src/ETL/dados-de-teste/amostra_medicamentos.csv?token=GHSAT0AAAAAAC7EZNQDNPC4K4XKJXCVMV44Z63QRFA"

"https://github.com/Transparencia-Brasil/cesta-de-precos-pncp/tree/carrega-dados-no-banco/src/ETL/dados-de-teste"

read_csv(URL_LOADER_ITENS_CONTRATACOES) %>%
  names() %>%
  paste0(collapse = "\" = \"\",\n  \"") %>%
  sprintf("mapeamento_colunas <- c(\n  \"%s\" = \"\"\n)\n", .) %>%
  cat()


# Mapeamento entre colunas dos arquivos do PNCP e colunas do banco de dados
{
  COLUNAS_CATALOGO <- c(
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
