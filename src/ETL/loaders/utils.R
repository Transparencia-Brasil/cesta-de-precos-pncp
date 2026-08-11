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

#' Lê e valida o mapeamento de características OCDS do catálogo
#'
#' @param caminho Caminho do CSV versionado com o mapeamento OCDS.
#'
#' @return Dataframe com `codigo_item` e `caracteristicas_ocds`.
le_mapeamento_caracteristicas_ocds <- function(caminho) {
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
  mapeamento
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

#' Valida a fonte CATMAT antes de qualquer escrita no banco
#'
#' @param catalogo Dataframe lido do arquivo `catmat-N.rds`.
#'
#' @return O catálogo recebido, invisivelmente.
valida_catalogo_fonte <- function(catalogo) {
  colunas_esperadas <- setdiff(COLUNAS_CATALOGO, "caracteristicas_ocds")
  colunas_ausentes <- setdiff(colunas_esperadas, names(catalogo))

  if (length(colunas_ausentes) > 0) {
    stop(sprintf(
      "O catálogo não contém as colunas obrigatórias: %s.",
      paste(colunas_ausentes, collapse = ", ")
    ))
  }

  codigos <- trimws(as.character(catalogo$codigo_br))
  codigos_ausentes <- is.na(catalogo$codigo_br) | codigos == ""

  if (any(codigos_ausentes)) {
    stop("O catálogo contém codigo_br ausente ou vazio.")
  }

  if (any(!grepl("^[0-9]+$", codigos))) {
    stop("O catálogo contém codigo_br não numérico.")
  }

  codigos_inteiros <- suppressWarnings(as.integer(codigos))
  if (any(is.na(codigos_inteiros))) {
    stop("O catálogo contém codigo_br fora do intervalo aceito por INTEGER.")
  }

  colunas_nao_nulas <- c(
    "codigo_classe", "nome_classe", "codigo_pdm", "nome_pdm", "nome_item"
  )
  colunas_com_ausencias <- colunas_nao_nulas[vapply(
    catalogo[colunas_nao_nulas],
    anyNA,
    logical(1)
  )]
  if (length(colunas_com_ausencias) > 0) {
    stop(sprintf(
      "O catálogo contém valores ausentes em colunas obrigatórias: %s.",
      paste(colunas_com_ausencias, collapse = ", ")
    ))
  }

  codigos_duplicados <- unique(codigos[duplicated(codigos)])
  if (length(codigos_duplicados) > 0) {
    stop(sprintf(
      "O catálogo contém codigo_br duplicado: %s.",
      paste(utils::head(codigos_duplicados, 10), collapse = ", ")
    ))
  }

  invisible(catalogo)
}

#' Valida se o mapeamento OCDS pertence ao catálogo informado
#'
#' Itens do catálogo sem mapeamento continuam permitidos e recebem `NULL`. Já
#' códigos no mapeamento que não existem no catálogo indicam arquivos de versões
#' incompatíveis e interrompem a carga.
#'
#' @param catalogo Dataframe CATMAT validado.
#' @param mapeamento Dataframe retornado por `le_mapeamento_caracteristicas_ocds()`.
#'
#' @return O mapeamento recebido, invisivelmente.
valida_compatibilidade_mapeamento_ocds <- function(catalogo, mapeamento) {
  codigos_catalogo <- as.character(catalogo$codigo_br)
  codigos_extras <- setdiff(as.character(mapeamento$codigo_item), codigos_catalogo)

  if (length(codigos_extras) > 0) {
    stop(sprintf(
      paste0(
        "O mapeamento OCDS contém códigos ausentes no catálogo informado: %s. ",
        "Verifique se os arquivos possuem a mesma versão."
      ),
      paste(utils::head(codigos_extras, 10), collapse = ", ")
    ))
  }

  invisible(mapeamento)
}

#' Valida a tabela de catálogo pronta para o banco
#'
#' @param tabela Dataframe transformado para a consulta de upsert.
#' @param total_esperado Quantidade de códigos únicos da fonte CATMAT.
#'
#' @return A tabela recebida, invisivelmente.
valida_tabela_catalogo <- function(tabela, total_esperado) {
  colunas_esperadas <- c(
    "codigo_classe", "nome_classe", "codigo_pdm", "nome_pdm", "codigo_br",
    "nome_item", "item_suspenso", "item_ativo", "item_sustentavel",
    "caracteristicas_ocds", "caracteristicas", "unidade_fornecimento"
  )
  colunas_ausentes <- setdiff(colunas_esperadas, names(tabela))

  if (length(colunas_ausentes) > 0) {
    stop(sprintf(
      "A tabela transformada não contém as colunas obrigatórias: %s.",
      paste(colunas_ausentes, collapse = ", ")
    ))
  }

  if (nrow(tabela) != total_esperado) {
    stop(sprintf(
      "A transformação alterou a quantidade de itens: esperado %d, obtido %d.",
      total_esperado,
      nrow(tabela)
    ))
  }

  if (anyDuplicated(as.character(tabela$codigo_br)) > 0) {
    stop("A tabela transformada contém codigo_br duplicado.")
  }

  for (coluna in c("caracteristicas", "unidade_fornecimento")) {
    json_valido <- vapply(tabela[[coluna]], jsonlite::validate, logical(1))
    if (any(!json_valido)) {
      stop(sprintf("A coluna %s contém JSON inválido.", coluna))
    }
  }

  preenchidos <- !is.na(tabela$caracteristicas_ocds)
  json_ocds_valido <- vapply(
    tabela$caracteristicas_ocds[preenchidos],
    jsonlite::validate,
    logical(1)
  )
  if (any(!json_ocds_valido)) {
    stop("A coluna caracteristicas_ocds contém JSON inválido.")
  }

  invisible(tabela)
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
      unidades_fornecimento = $12::jsonb,
      data_atualizacao = CURRENT_TIMESTAMP;"

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
        nome_modo_disputa = $17;"

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
        motivo_cancelamento = $40;"

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
#' @param interromper_em_erro Se `TRUE`, interrompe no primeiro erro para permitir
#' rollback pelo chamador. O padrão preserva o comportamento dos demais loaders.
#'
#' @return Quantidade de linhas processadas com sucesso, invisivelmente.
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
insere_tabela <- function(con, tabela, consulta, interromper_em_erro = FALSE) {
  total_inserido <- 0L

  for (i in seq_len(nrow(tabela))) {
    tryCatch({
      params <- unname(as.list(tabela[i, ]))
      dbExecute(con, consulta, params = params)
      total_inserido <- total_inserido + 1L
    }, error = function(e) {
      nome_tabela <- deparse(substitute(tabela))
      mensagem <- sprintf(
        "Erro ao inserir a linha %d da tabela %s: %s",
        i,
        nome_tabela,
        e$message
      )

      if (interromper_em_erro) {
        stop(mensagem, call. = FALSE)
      }

      message(mensagem)
    })
  }

  invisible(total_inserido)
}
