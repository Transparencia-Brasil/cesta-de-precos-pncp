# Mapeamento das colunas dos arquivos de itens

# :: CONTRATAÇÕES --------------------------------------------------------------

# Mapeamento das colunas dos arquivos de contratações
mapeamento_colunas_contratacoes <- c(
  # orgaoEntidade
  "data.orgaoEntidade.cnpj" = "orgaoEntidade_cnpj",
  "data.orgaoEntidade.razaoSocial" = "orgaoEntidade_razaoSocial",
  "data.orgaoEntidade.esferaId" = "orgaoEntidade_esferaId",
  "data.orgaoEntidade.poderId" = "orgaoEntidade_poderId",
  # unidadeOrgao
  "data.unidadeOrgao.codigoUnidade" = "unidadeOrgao_codigoUnidade",
  "data.unidadeOrgao.nomeUnidade" = "unidadeOrgao_nomeUnidade",
  "data.unidadeOrgao.codigoIbge" = "unidadeOrgao_codigoIbge",
  "data.unidadeOrgao.municipioNome" = "unidadeOrgao_municipioNome",
  "data.unidadeOrgao.ufSigla" = "unidadeOrgao_ufSigla",
  "data.unidadeOrgao.ufNome" = "unidadeOrgao_ufNome",
  # orgaoSubRogado
  "data.orgaoSubRogado.cnpj" = "orgaoSubRogado_cnpj",
  "data.orgaoSubRogado.razaoSocial" = "orgaoSubRogado_razaoSocial",
  "data.orgaoSubRogado.esferaId" = "orgaoSubRogado_esferaId",
  "data.orgaoSubRogado.poderId" = "orgaoSubRogado_poderId",
  # unidadeSubRogada
  "data.unidadeSubRogada.codigoUnidade" = "unidadeSubRogada_codigoUnidade",
  "data.unidadeSubRogada.nomeUnidade" = "unidadeSubRogada_nomeUnidade",
  "data.unidadeSubRogada.codigoIbge" = "unidadeSubRogada_codigoIbge",
  "data.unidadeSubRogada.municipioNome" = "unidadeSubRogada_municipioNome",
  "data.unidadeSubRogada.ufSigla" = "unidadeSubRogada_ufSigla",
  "data.unidadeSubRogada.ufNome" = "unidadeSubRogada_ufNome",
  # ids
  "data.numeroControlePNCP" = "numeroControlePNCP",
  "data.anoCompra" = "anoCompra",
  "data.sequencialCompra" = "sequencialCompra",
  # objetoCompra
  "data.objetoCompra" = "objetoCompra",
  # dataAbertura e dataEncerramento
  "data.dataAberturaProposta" = "dataAberturaProposta",
  "data.dataEncerramentoProposta" = "dataEncerramentoProposta",
  # valorEstimado e valorHomologado
  "data.valorTotalEstimado" = "valorTotalEstimado",
  "data.valorTotalHomologado" = "valorTotalHomologado",
  # srp
  "data.srp" = "srp",
  # instrumentoConvocatorio
  "data.tipoInstrumentoConvocatorioCodigo" = "tipoInstrumentoConvocatorioCodigo",
  "data.tipoInstrumentoConvocatorioNome" = "tipoInstrumentoConvocatorioNome",
  # modalidade
  "data.modalidadeId" = "modalidadeId",
  "data.modalidadeNome" = "modalidadeNome",
  # ampareLegal
  "data.amparoLegal.codigo" = "amparoLegal_codigo",
  "data.amparoLegal.nome" = "amparoLegal_nome",
  # modoDisputa
  "data.modoDisputaId" = "modoDisputaId",
  "data.modoDisputaNome" = "modoDisputaNome"
)

# :: ITENS ---------------------------------------------------------------------

#' Mapeamento de colunas para itens de coleta I
#'
#' Esta função realiza o mapeamento das colunas de um conjunto de dados de itens de coleta I,
#' selecionando as colunas existentes e adicionando novas colunas com valores padrão.
#'
#' @param itens_coleta1 Um data frame contendo os dados dos itens de coleta I.
#' @return Um data frame (itens_coleta1) com as colunas mapeadas e novas colunas adicionadas.
mapeamento_colunas_itens_coleta1 <- function(itens_coleta1) {
  itens_coleta1 %>%
    select(
      # colunas que existiam na coleta I
      numeroItem = numeroItem,
      descricao = descricao,
      materialOuServico = materialOuServico,
      materialOuServicoNome = materialOuServicoNome,
      valorUnitarioEstimado = valorUnitarioEstimado,
      valorTotal = valorTotal,
      quantidade = quantidade,
      unidadeMedida = unidadeMedida,
      orcamentoSigiloso = orcamentoSigiloso,
      itemCategoriaId = itemCategoriaId,
      itemCategoriaNome = itemCategoriaNome,
      patrimonio = patrimonio,
      codigoRegistroImobiliario = codigoRegistroImobiliario,
      criterioJulgamentoId = criterioJulgamentoId,
      criterioJulgamentoNome = criterioJulgamentoNome,
      situacaoCompraItem = situacaoCompraItem,
      situacaoCompraItemNome = situacaoCompraItemNome,
      tipoBeneficio = tipoBeneficio,
      tipoBeneficioNome = tipoBeneficioNome,
      incentivoProdutivoBasico = incentivoProdutivoBasico,
      dataInclusao = dataInclusao,
      dataAtualizacao = dataAtualizacao,
      temResultado = temResultado,
      imagem = imagem,
      endpoint = pncp_endpoint
    ) %>%
    # colunas que foram criadas depois da coleta I
    mutate(
      aplicabilidadeMargemPreferenciaNormal = NA_character_,
      aplicabilidadeMargemPreferenciaAdicional = NA_character_,
      percentualMargemPreferenciaNormal = NA_character_,
      percentualMargemPreferenciaAdicional = NA_character_,
      ncmNbsCodigo = NA_character_,
      ncmNbsDescricao = NA_character_,
      catalogo = NA_character_,
      categoriaItemCatalogo = NA_character_,
      # catalogoCodigoItem = NA_character_,
      # informacaoComplementar = NA_character_,
      # codigo_pdm = NA_character_
    )
}

#' Mapeamento de colunas para itens de coleta II
#'
#' Realiza o mapeamento das colunas de um conjunto de dados de itens de coleta II.
#'
#' @param itens_coleta2 Um data frame contendo os dados dos itens de coleta II.
#' @return Um data frame (itens_coleta2) com as colunas mapeadas e novas colunas adicionadas.
mapeamento_colunas_itens_coleta2 <- function(itens_coleta2) {
  itens_coleta2 %>%
    select(
      # colunas que existiam na coleta II
      numeroItem = numeroItem,
      descricao = descricao,
      materialOuServico = materialOuServico,
      materialOuServicoNome = materialOuServicoNome,
      valorUnitarioEstimado = valorUnitarioEstimado,
      valorTotal = valorTotal,
      quantidade = quantidade,
      unidadeMedida = unidadeMedida,
      orcamentoSigiloso = orcamentoSigiloso,
      itemCategoriaId = itemCategoriaId,
      itemCategoriaNome = itemCategoriaNome,
      patrimonio = patrimonio,
      codigoRegistroImobiliario = codigoRegistroImobiliario,
      criterioJulgamentoId = criterioJulgamentoId,
      criterioJulgamentoNome = criterioJulgamentoNome,
      situacaoCompraItem = situacaoCompraItem,
      situacaoCompraItemNome = situacaoCompraItemNome,
      tipoBeneficio = tipoBeneficio,
      tipoBeneficioNome = tipoBeneficioNome,
      incentivoProdutivoBasico = incentivoProdutivoBasico,
      dataInclusao = dataInclusao,
      dataAtualizacao = dataAtualizacao,
      temResultado = temResultado,
      imagem = imagem,
      aplicabilidadeMargemPreferenciaNormal = aplicabilidadeMargemPreferenciaNormal,
      aplicabilidadeMargemPreferenciaAdicional = aplicabilidadeMargemPreferenciaAdicional,
      percentualMargemPreferenciaNormal = percentualMargemPreferenciaNormal,
      percentualMargemPreferenciaAdicional = percentualMargemPreferenciaAdicional,
      ncmNbsCodigo = ncmNbsCodigo,
      ncmNbsDescricao = ncmNbsDescricao,
      endpoint = endpoint
      # codigo_pdm = codigo_pdm
    ) %>%
    mutate(
      # colunas que foram criadas depois da coleta II
      catalogo = NA_character_,
      categoriaItemCatalogo = NA_character_
      # catalogoCodigoItem = NA_character_,
      # informacaoComplementar = NA_character_
    )
}

#' Mapeamento de colunas para itens de coleta III
#'
#' Realiza o mapeamento das colunas de um conjunto de dados de itens de coleta III.
#'
#' @param itens_coleta3 Um data frame contendo os dados dos itens de coleta III.
#' @return Um data frame (itens_coleta3) com as colunas mapeadas.
mapeamento_colunas_itens_coleta3 <- function(itens_coleta3) {
  itens_coleta3 %>%
    select(
      # colunas que existiam na coleta III
      numeroItem = numeroItem,
      descricao = descricao,
      materialOuServico = materialOuServico,
      materialOuServicoNome = materialOuServicoNome,
      valorUnitarioEstimado = valorUnitarioEstimado,
      valorTotal = valorTotal,
      quantidade = quantidade,
      unidadeMedida = unidadeMedida,
      orcamentoSigiloso = orcamentoSigiloso,
      itemCategoriaId = itemCategoriaId,
      itemCategoriaNome = itemCategoriaNome,
      patrimonio = patrimonio,
      codigoRegistroImobiliario = codigoRegistroImobiliario,
      criterioJulgamentoId = criterioJulgamentoId,
      criterioJulgamentoNome = criterioJulgamentoNome,
      situacaoCompraItem = situacaoCompraItem,
      situacaoCompraItemNome = situacaoCompraItemNome,
      tipoBeneficio = tipoBeneficio,
      tipoBeneficioNome = tipoBeneficioNome,
      incentivoProdutivoBasico = incentivoProdutivoBasico,
      dataInclusao = dataInclusao,
      dataAtualizacao = dataAtualizacao,
      temResultado = temResultado,
      imagem = imagem,
      aplicabilidadeMargemPreferenciaNormal = aplicabilidadeMargemPreferenciaNormal,
      aplicabilidadeMargemPreferenciaAdicional = aplicabilidadeMargemPreferenciaAdicional,
      percentualMargemPreferenciaNormal = percentualMargemPreferenciaNormal,
      percentualMargemPreferenciaAdicional = percentualMargemPreferenciaAdicional,
      ncmNbsCodigo = ncmNbsCodigo,
      ncmNbsDescricao = ncmNbsDescricao,
      catalogo = catalogo,
      categoriaItemCatalogo = categoriaItemCatalogo,
      # catalogoCodigoItem = catalogoCodigoItem,
      # informacaoComplementar = informacaoComplementar,
      endpoint = endpoint
      # codigo_pdm = codigo_pdm
    )
}

# :: RESULTADOS DOS ITENS ------------------------------------------------------

#' Mapeamento de colunas para itens de resultados de coleta II
#'
#' Realiza o mapeamento das colunas de um conjunto de dados de resultados de coleta II.
#'
#' @param resultado_coleta2 Um data frame contendo os dados de resultados de coleta II.
#' @return Um data frame (resultado_coleta2) com as colunas mapeadas e novas colunas adicionadas.
mapeamento_colunas_resultado_coleta2 <- function(resultado_coleta2) {
  resultado_coleta2 %>%
    select(
      # colunas que existiam na coleta II
      situacaoCompraItemResultadoNome = situacaoCompraItemResultadoNome,
      porteFornecedorNome = porteFornecedorNome,
      sequencialResultado = sequencialResultado,
      naturezaJuridicaNome = naturezaJuridicaNome,
      dataAtualizacao = dataAtualizacao,
      niFornecedor = niFornecedor,
      tipoPessoa = tipoPessoa,
      dataInclusao = dataInclusao,
      numeroItem = numeroItem,
      valorTotalHomologado = valorTotalHomologado,
      timezoneCotacaoMoedaEstrangeira = timezoneCotacaoMoedaEstrangeira,
      moedaEstrangeira = moedaEstrangeira,
      valorNominalMoedaEstrangeira = valorNominalMoedaEstrangeira,
      dataCotacaoMoedaEstrangeira = dataCotacaoMoedaEstrangeira,
      nomeRazaoSocialFornecedor = nomeRazaoSocialFornecedor,
      codigoPais = codigoPais,
      porteFornecedorId = porteFornecedorId,
      quantidadeHomologada = quantidadeHomologada,
      valorUnitarioHomologado = valorUnitarioHomologado,
      percentualDesconto = percentualDesconto,
      amparoLegalMargemPreferencia = amparoLegalMargemPreferencia,
      amparoLegalCriterioDesempate = amparoLegalCriterioDesempate,
      paisOrigemProdutoServico = paisOrigemProdutoServico,
      indicadorSubcontratacao = indicadorSubcontratacao,
      ordemClassificacaoSrp = ordemClassificacaoSrp,
      dataResultado = dataResultado,
      motivoCancelamento = motivoCancelamento,
      dataCancelamento = dataCancelamento,
      situacaoCompraItemResultadoId = situacaoCompraItemResultadoId,
      aplicacaoMargemPreferencia = aplicacaoMargemPreferencia,
      aplicacaoBeneficioMeEpp = aplicacaoBeneficioMeEpp,
      aplicacaoCriterioDesempate = aplicacaoCriterioDesempate,
      naturezaJuridicaId = naturezaJuridicaId,
      endpoint = endpoint,
      numeroControlePNCPCompra = numeroControlePNCPCompra,
    ) %>%
    mutate(
      # colunas que foram criadas depois da coleta II
      amparoLegalCriterioDesempate.statusAtivo = NA_character_,
      amparoLegalCriterioDesempate.id = NA_character_,
      amparoLegalCriterioDesempate.nome = NA_character_,
      amparoLegalCriterioDesempate.descricao = NA_character_,
      amparoLegalCriterioDesempate.statusAtivo = NA_character_
    )
}

#' Mapeamento de colunas para itens de resultados de coleta III
#'
#' Realiza o mapeamento das colunas de um conjunto de dados de resultados de coleta III.
#'
#' @param resultado_coleta3 Um data frame contendo os dados de resultados de coleta III.
#' @return Um data frame (resultado_coleta3) com as colunas mapeadas.
mapeamento_colunas_resultado_coleta3 <- function(resultado_coleta3) {
  resultado_coleta3 %>%
    select(
      # colunas que existiam na coleta II
      situacaoCompraItemResultadoNome = situacaoCompraItemResultadoNome,
      porteFornecedorNome = porteFornecedorNome,
      sequencialResultado = sequencialResultado,
      naturezaJuridicaNome = naturezaJuridicaNome,
      dataAtualizacao = dataAtualizacao,
      niFornecedor = niFornecedor,
      tipoPessoa = tipoPessoa,
      dataInclusao = dataInclusao,
      numeroItem = numeroItem,
      valorTotalHomologado = valorTotalHomologado,
      timezoneCotacaoMoedaEstrangeira = timezoneCotacaoMoedaEstrangeira,
      moedaEstrangeira = moedaEstrangeira,
      valorNominalMoedaEstrangeira = valorNominalMoedaEstrangeira,
      dataCotacaoMoedaEstrangeira = dataCotacaoMoedaEstrangeira,
      nomeRazaoSocialFornecedor = nomeRazaoSocialFornecedor,
      codigoPais = codigoPais,
      porteFornecedorId = porteFornecedorId,
      quantidadeHomologada = quantidadeHomologada,
      valorUnitarioHomologado = valorUnitarioHomologado,
      percentualDesconto = percentualDesconto,
      amparoLegalMargemPreferencia = amparoLegalMargemPreferencia,
      paisOrigemProdutoServico = paisOrigemProdutoServico,
      indicadorSubcontratacao = indicadorSubcontratacao,
      ordemClassificacaoSrp = ordemClassificacaoSrp,
      dataResultado = dataResultado,
      motivoCancelamento = motivoCancelamento,
      dataCancelamento = dataCancelamento,
      situacaoCompraItemResultadoId = situacaoCompraItemResultadoId,
      aplicacaoMargemPreferencia = aplicacaoMargemPreferencia,
      aplicacaoBeneficioMeEpp = aplicacaoBeneficioMeEpp,
      aplicacaoCriterioDesempate = aplicacaoCriterioDesempate,
      naturezaJuridicaId = naturezaJuridicaId,
      endpoint = endpoint,
      numeroControlePNCPCompra = numeroControlePNCPCompra,
      amparoLegalCriterioDesempate.id = amparoLegalCriterioDesempate.id,
      amparoLegalCriterioDesempate.nome = amparoLegalCriterioDesempate.nome,
      amparoLegalCriterioDesempate.descricao = amparoLegalCriterioDesempate.descricao,
      amparoLegalCriterioDesempate.statusAtivo = amparoLegalCriterioDesempate.statusAtivo
    ) %>%
    # Essa coluna desagregou em id, nome, descricao, statusAtivo. Porém está no template.
    mutate(amparoLegalCriterioDesempate = if_else(!is.na(amparoLegalCriterioDesempate.id), TRUE, NA))
}

# :: HELPERS -------------------------------------------------------------------

# FUNÇÃO PARA VALIDAR ---

#' Comparar Colunas de um Dataframe com um Template
#'
#' Esta função compara as colunas de um dataframe com as colunas de um template,
#' identificando quais colunas estão faltando, quais são extras e quais são comuns entre ambos.
#'
#' @param df Um dataframe cujas colunas serão comparadas.
#' @param template Um dataframe ou lista que serve como template para a comparação.
#'
#' @return Uma lista com três elementos:
#' \describe{
#'   \item{faltando}{Vetor de colunas que estão no template, mas não no dataframe.}
#'   \item{extras}{Vetor de colunas que estão no dataframe, mas não no template.}
#'   \item{comuns}{Vetor de colunas que estão presentes em ambos.}
#' }
#'
comparar_colunas <- function(df, template) {
  colunas_template <- names(template)
  colunas_df <- names(df)

  # Colunas que estão no template, mas não no dataframe
  faltando <- setdiff(colunas_template, colunas_df)

  # Colunas que estão no dataframe, mas não no template
  extras <- setdiff(colunas_df, colunas_template)

  # Colunas que estão em ambos
  comuns <- intersect(colunas_template, colunas_df)

  list(
    faltando = faltando,
    extras = extras,
    comuns = comuns
  )
}

#' @title Gerar Identificador de Controle PNCP
#' @description Função para criar um identificador único de controle PNCP com base no endpoint fornecido.
#' @details
#' Número de Controle da Contratação (id contratação PNCP) (Máscara: 99999999999999-1-999999/9999.)
#' Cada contratação receberá um número de controle composto por:
#' - CNPJ do Órgão/Entidade da contratação (14 dígitos)
#' - Dígito "1" - marcador que indica tratar-se de uma contratação
#' - Número sequencial da contratação no PNCP *
#' - Ano da contratação (4 dígitos)
#'
#' * O número PNCP será gerado sequencialmente com 6 dígitos e reiniciado a cada mudança de ano.
#' (Fonte: Manual de Integração do PNCP)
#' @param endpoint Uma string representando o endpoint da API contendo informações sobre o fornecedor, ano e sequencial.
#' @return Uma string contendo o identificador no formato "{niFornecedor}-1-{sequencial}/{ano}".
#' @examples
#' make_id("https://api.exemplo.com/orgaos/12345/compras/2023/6789/itens")
#' # Retorna: "12345-1-006789/2023"
make_id <- \(endpoint) {
  cnpj <- endpoint %>%
    str_remove("^.+orgaos\\/") %>%
    str_remove("\\/compras.+")

  ano <- endpoint %>%
    str_remove("^.+compras\\/") %>%
    str_extract("^\\d+")

  sequencial <- endpoint %>%
    str_remove(str_glue("^.+compras\\/{ano}\\/")) %>%
    str_remove(str_glue("\\/itens")) %>%
    str_pad(width = 6, pad = "0")

  numeroControlePNCP <- str_glue("{cnpj}-1-{sequencial}/{ano}")

  return(numeroControlePNCP)
}