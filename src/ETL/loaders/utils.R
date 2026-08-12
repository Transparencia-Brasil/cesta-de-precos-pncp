#' Script auxiliar ao inserir dados no banco.
#'
#' Conteúdo:
#'  * Mapeamento entre colunas dos arquivos do PNCP e colunas do banco de dados.
#'  * Consultas de inserção no banco.
#'  * Função para se conectar ao banco.
#'  * Função para inserir dados no banco a partir de um dataframe.
#'
#'  Para conectar-se ao banco insira um arquivo .env na raiz do projeto com
#'  o seguinte conteúdo:
#'
#'  DB_HOST=seu_host_aqui
#'  1DB_USER=seu_usuario_aqui
#'  DB_PASS=sua_senha_aqui
#'  DB_PORT=sua_porta_aqui
#'

suppressPackageStartupMessages(library(DBI))
suppressPackageStartupMessages(library(RPostgres))
suppressPackageStartupMessages(library(dotenv))

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
    "unidadeFornecimento",
    "caracteristicas_ocds"
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
    "data.modoDisputaNome",
    "compra_judicial"
  )

  COLUNAS_DESCONTOS_ITEM <- c(
    "incentivoProdutivoBasico",
    "exigenciaConteudoNacional",
    "aplicabilidadeMargemPreferenciaNormal",
    "aplicabilidadeMargemPreferenciaAdicional",
    "tipoMargemPreferencia.codigo",
    "tipoMargemPreferencia.nome",
    "percentualMargemPreferenciaNormal",
    "percentualMargemPreferenciaAdicional"
  )

  COLUNAS_DESCONTOS_RESULTADO <- c(
    "aplicacaoBeneficioMeEpp",
    "aplicacaoMargemPreferencia",
    "amparoLegalMargemPreferencia.id",
    "amparoLegalMargemPreferencia.nome",
    "amparoLegalMargemPreferencia.descricao",
    "aplicacaoCriterioDesempate",
    "amparoLegalCriterioDesempate.id",
    "amparoLegalCriterioDesempate.nome",
    "amparoLegalCriterioDesempate.descricao",
    "percentualDesconto"
  )

  COLUNAS_DESCONTOS_ITEM_HOMOLOGADO <- c(
    "aplicacaoBeneficioMeEpp",
    "incentivoProdutivoBasico",
    "exigenciaConteudoNacional",
    "aplicabilidadeMargemPreferenciaNormal",
    "aplicabilidadeMargemPreferenciaAdicional",
    "tipoMargemPreferencia.codigo",
    "tipoMargemPreferencia.nome",
    "percentualMargemPreferenciaNormal",
    "percentualMargemPreferenciaAdicional",
    "aplicacaoMargemPreferencia",
    "amparoLegalMargemPreferencia.id",
    "amparoLegalMargemPreferencia.nome",
    "amparoLegalMargemPreferencia.descricao",
    "aplicacaoCriterioDesempate",
    "amparoLegalCriterioDesempate.id",
    "amparoLegalCriterioDesempate.nome",
    "amparoLegalCriterioDesempate.descricao",
    "percentualDesconto"
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
    COLUNAS_DESCONTOS_ITEM_HOMOLOGADO,
    "urlAPI",
    "urlPNCP"
  )

  COLUNAS_ITEM_HOMOLOGADO_RECOLETA <- c(
    "numero_controle_pncp",
    "codigo_item_catalogo",
    "cnpj_contratante",
    "codigo_unidade_contratante",
    "cnpj_contratante_subrogado",
    "codigo_unidade_contratante_subrogado",
    "niFornecedor",
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
    "situacaoCompraItemResultadoId",
    "situacaoCompraItemResultadoNome",
    "valorUnitarioHomologado",
    "valorTotalHomologado",
    "quantidadeHomologada",
    "moedaEstrangeira.simbolo",
    "valorNominalMoedaEstrangeira",
    "dataResultado",
    "dataCancelamento",
    "motivoCancelamento",
    COLUNAS_DESCONTOS_ITEM_HOMOLOGADO,
    "url_api",
    "url_pncp"
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

#' Normaliza representacoes textuais de valores nulos do PNCP
#'
#' @param x Vetor a normalizar.
#' @return Vetor de caracteres com valores vazios representados por `NA`.
normaliza_nulo_pncp <- function(x) {
  valor <- trimws(as.character(x))
  valor[is.na(x) | valor %in% c("", "NA", "N/A", "NULL", "null")] <- NA_character_
  valor
}

#' Converte um campo booleano recebido do PNCP
#'
#' @param x Vetor a converter.
#' @param coluna Nome do campo, usado em mensagens de erro.
#' @return Vetor logico.
converte_booleano_pncp <- function(x, coluna) {
  valor <- tolower(normaliza_nulo_pncp(x))
  verdadeiros <- c("true", "t", "1", "sim", "s", "yes", "y", "verdadeiro", "v")
  falsos <- c("false", "f", "0", "nao", "não", "n", "no", "falso")
  invalidos <- unique(valor[!is.na(valor) & !valor %in% c(verdadeiros, falsos)])

  if (length(invalidos) > 0) {
    stop(sprintf(
      "Valores booleanos invalidos na coluna '%s': %s.",
      coluna,
      paste(invalidos, collapse = ", ")
    ))
  }

  resultado <- rep(NA, length(valor))
  resultado[valor %in% verdadeiros] <- TRUE
  resultado[valor %in% falsos] <- FALSE
  resultado
}

#' Converte um campo inteiro recebido do PNCP
#'
#' @param x Vetor a converter.
#' @param coluna Nome do campo, usado em mensagens de erro.
#' @return Vetor de inteiros.
converte_inteiro_pncp <- function(x, coluna) {
  valor <- normaliza_nulo_pncp(x)
  convertido <- suppressWarnings(as.integer(valor))
  invalidos <- unique(valor[!is.na(valor) & is.na(convertido)])

  if (length(invalidos) > 0) {
    stop(sprintf(
      "Valores inteiros invalidos na coluna '%s': %s.",
      coluna,
      paste(invalidos, collapse = ", ")
    ))
  }

  convertido
}

#' Converte um campo numerico recebido do PNCP
#'
#' @param x Vetor a converter.
#' @param coluna Nome do campo, usado em mensagens de erro.
#' @return Vetor numerico, sem restricao de faixa.
converte_numerico_pncp <- function(x, coluna) {
  valor <- normaliza_nulo_pncp(x)
  convertido <- suppressWarnings(as.numeric(valor))
  invalidos <- unique(valor[!is.na(valor) & is.na(convertido)])

  if (length(invalidos) > 0) {
    stop(sprintf(
      "Valores numericos invalidos na coluna '%s': %s.",
      coluna,
      paste(invalidos, collapse = ", ")
    ))
  }

  convertido
}

#' Completa e normaliza os campos de descontos de item_homologado
#'
#' @param tabela Dataframe resultante dos joins do loader.
#' @return Dataframe com os 18 campos presentes e tipados.
normaliza_campos_descontos_item_homologado <- function(tabela) {
  colunas_faltantes <- setdiff(COLUNAS_DESCONTOS_ITEM_HOMOLOGADO, names(tabela))
  for (coluna in colunas_faltantes) {
    tabela[[coluna]] <- rep(NA, nrow(tabela))
  }

  colunas_booleanas <- c(
    "aplicacaoBeneficioMeEpp",
    "incentivoProdutivoBasico",
    "exigenciaConteudoNacional",
    "aplicabilidadeMargemPreferenciaNormal",
    "aplicabilidadeMargemPreferenciaAdicional",
    "aplicacaoMargemPreferencia",
    "aplicacaoCriterioDesempate"
  )
  colunas_inteiras <- c(
    "tipoMargemPreferencia.codigo",
    "amparoLegalMargemPreferencia.id",
    "amparoLegalCriterioDesempate.id"
  )
  colunas_numericas <- c(
    "percentualMargemPreferenciaNormal",
    "percentualMargemPreferenciaAdicional",
    "percentualDesconto"
  )
  colunas_textuais <- setdiff(
    COLUNAS_DESCONTOS_ITEM_HOMOLOGADO,
    c(colunas_booleanas, colunas_inteiras, colunas_numericas)
  )

  for (coluna in colunas_booleanas) {
    tabela[[coluna]] <- converte_booleano_pncp(tabela[[coluna]], coluna)
  }
  for (coluna in colunas_inteiras) {
    tabela[[coluna]] <- converte_inteiro_pncp(tabela[[coluna]], coluna)
  }
  for (coluna in colunas_numericas) {
    tabela[[coluna]] <- converte_numerico_pncp(tabela[[coluna]], coluna)
  }
  for (coluna in colunas_textuais) {
    tabela[[coluna]] <- normaliza_nulo_pncp(tabela[[coluna]])
  }

  tabela
}

#' Seleciona colunas de item_homologado na ordem da consulta parametrizada
#'
#' @param tabela Dataframe resultante dos joins do loader.
#' @param colunas Colunas esperadas pela consulta de insercao.
#' @return Dataframe completo, tipado e ordenado.
seleciona_colunas_item_homologado <- function(tabela, colunas) {
  tabela <- normaliza_campos_descontos_item_homologado(tabela)
  colunas_faltantes <- setdiff(colunas, names(tabela))
  for (coluna in colunas_faltantes) {
    tabela[[coluna]] <- rep(NA, nrow(tabela))
  }

  tabela[colunas]
}

#' Constroi item_homologado para a carga regular
#'
#' @param medicamentos Itens classificados como medicamentos.
#' @param resultados Resultados coletados do PNCP.
#' @param contratacoes Contratacoes de origem.
#' @return Dataframe pronto para `CONSULTA_INSERIR_ITEM_HOMOLOGADO`.
monta_item_homologado <- function(medicamentos, resultados, contratacoes) {
  medicamentos |>
    dplyr::inner_join(
      resultados,
      by = dplyr::join_by(endpointResultado == endpoint),
      suffix = c("", "Resultado"),
      multiple = "first"
    ) |>
    dplyr::inner_join(
      contratacoes,
      by = dplyr::join_by(endpointContratacao == endpoint),
      suffix = c("", "Contratacao")
    ) |>
    seleciona_colunas_item_homologado(COLUNAS_ITEM_HOMOLOGADO)
}

#' Constroi item_homologado durante a recoleta de resultados
#'
#' @param itens_licitados Itens ainda sem resultado armazenados no banco.
#' @param resultados Resultados recoletados do PNCP.
#' @return Dataframe pronto para `CONSULTA_INSERIR_ITEM_HOMOLOGADO`.
monta_item_homologado_recoleta <- function(itens_licitados, resultados) {
  itens_licitados |>
    dplyr::inner_join(
      resultados,
      by = dplyr::join_by(
        numero_controle_pncp == numeroControlePNCPCompra,
        numero_item == numeroItem
      ),
      suffix = c("", "Resultado"),
      multiple = "first"
    ) |>
    tibble::as_tibble() |>
    seleciona_colunas_item_homologado(COLUNAS_ITEM_HOMOLOGADO_RECOLETA)
}

#' Lê e valida o mapeamento de características OCDS do catálogo
#'
#' @param caminho Caminho do CSV versionado com o mapeamento OCDS.
#'
#' @return Dataframe com `codigo_item` e `caracteristicas_ocds`.
le_mapeamento_caracteristicas_ocds <- function(
  caminho = here::here(
    "tasks/alteracoes-no-banco-de-dados/catalogo-caracteristicas-ocds",
    "outputs/tabela-mapeamento-ocds.csv"
  )
) {
  colunas_esperadas <- c("codigo_item", "caracteristicas_ocds")

  mapeamento <- readr::read_csv(
    caminho,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE,
    progress = FALSE
  )

  colunas_ausentes <- setdiff(colunas_esperadas, names(mapeamento))
  if (length(colunas_ausentes) > 0) {
    stop(sprintf(
      "O mapeamento OCDS não contém as colunas obrigatórias: %s.",
      paste(colunas_ausentes, collapse = ", ")
    ))
  }

  mapeamento <- mapeamento[, colunas_esperadas, drop = FALSE]
  mapeamento$codigo_item <- trimws(mapeamento$codigo_item)
  mapeamento$caracteristicas_ocds <- trimws(mapeamento$caracteristicas_ocds)
  valores_vazios <- !is.na(mapeamento$caracteristicas_ocds) &
    mapeamento$caracteristicas_ocds == ""
  mapeamento$caracteristicas_ocds[valores_vazios] <- NA_character_

  if (any(is.na(mapeamento$codigo_item) | mapeamento$codigo_item == "")) {
    stop("O mapeamento OCDS contém codigo_item ausente ou vazio.")
  }

  codigos_duplicados <- unique(
    mapeamento$codigo_item[duplicated(mapeamento$codigo_item)]
  )
  if (length(codigos_duplicados) > 0) {
    stop(sprintf(
      "O mapeamento OCDS contém codigo_item duplicado: %s.",
      paste(utils::head(codigos_duplicados, 10), collapse = ", ")
    ))
  }

  preenchidos <- !is.na(mapeamento$caracteristicas_ocds)
  json_valido <- vapply(
    mapeamento$caracteristicas_ocds[preenchidos],
    jsonlite::validate,
    logical(1)
  )
  if (any(!json_valido)) {
    codigos_invalidos <- mapeamento$codigo_item[preenchidos][!json_valido]
    stop(sprintf(
      "O mapeamento OCDS contém JSON inválido para codigo_item: %s.",
      paste(utils::head(codigos_invalidos, 10), collapse = ", ")
    ))
  }

  mapeamento
}

#' Adiciona as características OCDS aos itens do catálogo
#'
#' @param catalogo Dataframe do catálogo CATMAT.
#' @param mapeamento Dataframe validado com o mapeamento OCDS.
#'
#' @return Catálogo enriquecido por `codigo_br = codigo_item`.
adiciona_caracteristicas_ocds <- function(
  catalogo,
  mapeamento = le_mapeamento_caracteristicas_ocds()
) {
  if ("caracteristicas_ocds" %in% names(catalogo)) {
    catalogo$caracteristicas_ocds <- NULL
  }

  dplyr::left_join(
    catalogo,
    mapeamento,
    by = c("codigo_br" = "codigo_item")
  )
}

# Lista usada por nltk.corpus.stopwords.words("portuguese") no NLTK 3.9.1.
STOPWORDS_PORTUGUES_NLTK <- strsplit(
  paste(
    "a à ao aos aquela aquelas aquele aqueles aquilo as às até com como",
    "da das de dela delas dele deles depois do dos e é ela elas ele eles em",
    "entre era eram éramos essa essas esse esses esta está estamos estão",
    "estar estas estava estavam estávamos este esteja estejam estejamos estes",
    "esteve estive estivemos estiver estivera estiveram estivéramos estiverem",
    "estivermos estivesse estivessem estivéssemos estou eu foi fomos for fora",
    "foram fôramos forem formos fosse fossem fôssemos fui há haja hajam",
    "hajamos hão havemos haver hei houve houvemos houver houvera houverá",
    "houveram houvéramos houverão houverei houverem houveremos houveria",
    "houveriam houveríamos houvermos houvesse houvessem houvéssemos isso isto",
    "já lhe lhes mais mas me mesmo meu meus minha minhas muito na não nas nem",
    "no nos nós nossa nossas nosso nossos num numa o os ou para pela pelas",
    "pelo pelos por qual quando que quem são se seja sejam sejamos sem ser",
    "será serão serei seremos seria seriam seríamos seu seus só somos sou sua",
    "suas também te tem tém temos tenha tenham tenhamos tenho terá terão terei",
    "teremos teria teriam teríamos teu teus teve tinha tinham tínhamos tive",
    "tivemos tiver tivera tiveram tivéramos tiverem tivermos tivesse tivessem",
    "tivéssemos tu tua tuas um uma você vocês vos"
  ),
  "[[:space:]]+"
)[[1]]

#' Normaliza texto seguindo a regra de referência do notebook
#'
#' A normalização converte o texto para minúsculas, remove as stopwords em
#' português do NLTK, remove acentos com normalização NFKD e normaliza espaços.
#'
#' @param texto Texto escalar a ser normalizado.
#'
#' @return Texto normalizado.
limpa_texto <- function(texto) {
  texto <- tolower(as.character(texto))

  palavras <- strsplit(texto, "[[:space:]]+", perl = TRUE)[[1]]
  palavras <- palavras[nzchar(palavras)]
  palavras <- palavras[!palavras %in% STOPWORDS_PORTUGUES_NLTK]
  texto <- paste(palavras, collapse = " ")

  texto <- stringi::stri_trans_nfkd(texto)
  texto <- stringi::stri_replace_all_regex(texto, "\\p{M}", "")
  texto <- gsub("[[:space:]]+", " ", texto, perl = TRUE)

  trimws(texto)
}

#' Identifica possível referência a demanda judicial em uma descrição
#'
#' @param descricao Descrição escalar do objeto da contratação.
#'
#' @return `TRUE` quando o texto normalizado contém `judic`; caso contrário,
#'   `FALSE`.
possui_indicativo_judicial <- function(descricao) {
  if (length(descricao) == 0 || is.na(descricao)) {
    return(FALSE)
  }

  grepl("judic", limpa_texto(descricao), fixed = TRUE)
}

# Consultas de inserção no banco
{

  # Insere um item do catálogo
  CONSULTA_INSERIR_CATALOGO <- "
    INSERT INTO catalogo (codigo_classe, nome_classe, codigo_pdm, nome_pdm,
    codigo_item, nome_item, item_suspenso, item_ativo, item_sustentavel,
    caracteristicas_ocds, características, unidades_fornecimento)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9,
    $10::jsonb, $11::jsonb, $12::jsonb)
    ON CONFLICT (codigo_item) DO NOTHING;"

  # Insere ou atualiza um item do catálogo
  CONSULTA_UPDATE_CATALOGO <- "
    INSERT INTO catalogo (codigo_classe, nome_classe, codigo_pdm, nome_pdm,
    codigo_item, nome_item, item_suspenso, item_ativo, item_sustentavel,
    caracteristicas_ocds, características, unidades_fornecimento)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9,
    $10::jsonb, $11::jsonb, $12::jsonb)
    ON CONFLICT (codigo_item)
    DO UPDATE SET
      codigo_classe = $1,
      nome_classe = $2,
      codigo_pdm = $3,
      nome_pdm = $4,
      nome_item = $6,
      item_suspenso = $7,
      item_ativo = $8,
      item_sustentavel = $9,
      caracteristicas_ocds = $10::jsonb,
      características = $11::jsonb,
      unidades_fornecimento = $12::jsonb;"

  # Insere um contratante
  CONSULTA_INSERIR_CONTRATANTE <- "
    INSERT INTO contratante (cnpj, razao_social, esfera, poder, codigo_unidade,
    nome_unidade, codigo_ibge_municipio, nome_municipio, sigla_uf, nome_uf)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
    ON CONFLICT (cnpj, codigo_unidade) DO NOTHING"

  # Insere um fornecedor
  CONSULTA_INSERIR_FORNECEDOR <- "
    INSERT INTO fornecedor (ni, nome, codigo_pais, tipo_pessoa, codigo_porte,
    nome_porte, codigo_natureza_juridica, nome_natureza_juridica)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
    ON CONFLICT (ni) DO NOTHING"

  # Insere uma contratação nova ou, caso a contratação já exista no banco, atualiza os campos
  CONSULTA_INSERIR_CONTRATACAO <- "
    INSERT INTO contratacao (
        numero_controle_pncp, ano_compra, sequencial_compra, objeto_compra,
        data_abertura_proposta, data_encerramento_proposta,
        valor_estimado_compra, valor_homologado_compra, srp,
        codigo_tipo_instrumento_convocatorio, nome_tipo_instrumento_convocatorio,
        codigo_modalidade, nome_modalidade,
        codigo_amparo_legal, nome_amparo_legal,
        codigo_modo_disputa, nome_modo_disputa, compra_judicial
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18)
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
        nome_modo_disputa = $17,
        compra_judicial = $18;"

  # Insere um item homologado novo ou, caso o item já exista no banco, atualiza os campos
  CONSULTA_INSERIR_ITEM_HOMOLOGADO <- "
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
        aplicacao_beneficio_me_epp,
        incentivo_produtivo_basico, exigencia_conteudo_nacional,
        aplicabilidade_margem_preferencia_normal,
        aplicabilidade_margem_preferencia_adicional,
        tipo_margem_preferencia_codigo, tipo_margem_preferencia_nome,
        percentual_margem_preferencia_normal,
        percentual_margem_preferencia_adicional,
        aplicacao_margem_preferencia,
        amparo_legal_margem_preferencia_id,
        amparo_legal_margem_preferencia_nome,
        amparo_legal_margem_preferencia_descricao,
        aplicacao_criterio_desempate,
        amparo_legal_criterio_desempate_id,
        amparo_legal_criterio_desempate_nome,
        amparo_legal_criterio_desempate_descricao,
        percentual_desconto,
        url_api, url_pncp)
    VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
        $11, $12, $13, $14, $15, $16, $17, $18, $19, $20,
        $21, $22, $23, $24, $25, $26, $27, $28, $29, $30,
        $31, $32, $33, $34, $35, $36, $37, $38, $39, $40,
        $41, $42, $43, $44, $45, $46, $47, $48, $49, $50,
        $51, $52, $53, $54, $55, $56, $57, $58, $59, $60)
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
        motivo_cancelamento = $40,
        aplicacao_beneficio_me_epp = $41,
        incentivo_produtivo_basico = $42,
        exigencia_conteudo_nacional = $43,
        aplicabilidade_margem_preferencia_normal = $44,
        aplicabilidade_margem_preferencia_adicional = $45,
        tipo_margem_preferencia_codigo = $46,
        tipo_margem_preferencia_nome = $47,
        percentual_margem_preferencia_normal = $48,
        percentual_margem_preferencia_adicional = $49,
        aplicacao_margem_preferencia = $50,
        amparo_legal_margem_preferencia_id = $51,
        amparo_legal_margem_preferencia_nome = $52,
        amparo_legal_margem_preferencia_descricao = $53,
        aplicacao_criterio_desempate = $54,
        amparo_legal_criterio_desempate_id = $55,
        amparo_legal_criterio_desempate_nome = $56,
        amparo_legal_criterio_desempate_descricao = $57,
        percentual_desconto = $58;"

  # Insere um item licitado novo ou, caso o item já exista no banco, atualiza os campos
  CONSULTA_INSERIR_ITEM_LICITADO <- "
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
        quantidade_estimada = $29;"
}


#' Conecta ao banco de dados "medicamentos-transparentes"
#'
#' Esta função estabelece uma conexão com o banco de dados PostgreSQL chamado
#' "medicamentos-transparentes", localizado no host "localhost" com as credenciais
#' padrão de usuário e senha ("postgres").
#'
#' @return Um objeto de conexão do tipo `DBI::DBIConnection`, que pode ser utilizado para
#' executar consultas SQL no banco de dados.
#' @examples
#' # Criar conexão com o banco de dados
#' con <- conecta_bd_medicamentos_transparentes()
#'
#' # Verificar se a conexão está ativa
#' DBI::dbIsValid(con)
#'
#' # Lembre-se de fechar a conexão ao finalizar o uso
#' DBI::dbDisconnect(con)
#' @import DBI RPostgres
conecta_bd_medicamentos_transparentes <- function() {
  # Lê o arquivo .env
  load_dot_env()

  NOME_BD <- "medicamentos_transparentes"
  HOST <- Sys.getenv("DB_HOST")
  USUARIO <- Sys.getenv("DB_USER")
  SENHA <- Sys.getenv("DB_PASS")
  PORTA <- Sys.getenv("DB_PORT")

  con <- dbConnect(
    RPostgres::Postgres(),
    dbname = NOME_BD,
    host = HOST,
    user = USUARIO,
    password = SENHA,
    port = PORTA
  )

  return(con)
}

#' @title Função para chamar tabelas no banco postgres
#' @param qry comando mysql, exemplo "select * from coletas;"
#' @param conectar marque TRUE para conectar ao banco de dados antes de fazer a query.
#' @param quiet ao rodar a função uma mensagem aparece no console, quiet=TRUE desabilita essa mensagem.
get_query <- function(qry, conectar = FALSE, quiet = FALSE) {
  # se quiser reiniciar a comunicação basta indicar `conectar = TRUE`
  if (conectar) conecta_bd_medicamentos_transparentes()

  # Se não quiser ver essa mensagem printada no console defina `quiet = TRUE`
  dbname <- DBI::dbGetInfo(con)$dbname
  if (!quiet) message(sprintf("dbname: %s\n %s", dbname, qry))

  # envia a query para o banco de dados e retorna uma tibble
  df <- DBI::dbGetQuery(con, qry) |> tibble::as_tibble()
  return(df)
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
  for (i in seq_len(nrow(tabela))) {
    tryCatch({
      params <- unname(as.list(tabela[i, ]))
      dbExecute(con, consulta, params = params)
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
