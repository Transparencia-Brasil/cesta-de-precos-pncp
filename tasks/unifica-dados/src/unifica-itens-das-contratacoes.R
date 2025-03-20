#' ---
#' Unifica coletas de itens das contratações
#' ---
#'
#' Este script une os dados de itens das contratações de medicamentos.
#' Esta unificação busca facilitar a análise de variação de preços de medicamentos.
#'
#' - Coleta 2: https://drive.google.com/drive/folders/1ZZ5ysQixMzT4srwCpirGhGsm9OpWeKy9
#' - Coleta 3: https://drive.google.com/drive/folders/13euL1rcl01dj3pQciLrMUj5yCnGf7ako
#'
#' Nota: Baixe os arquivos com o script `download-de-dados.R`, eles não serão enviados ao github, pois são grandes demais.
#'
#' A união dos datasets é feita com base no arquivo src/ETL/dados-de-teste/amostra_medicamentos.csv
#'


library(readr)
library(dplyr)
library(purrr)
library(here)
library(tidyverse)

# FILEPATHS --------------------------------------------------------------------

# os arquivos de coleta foram baixados do google drive e salvos localmente com o script "download-de-dados.R"
INPUT_DIR <- "tasks/unifica-dados/input"

# os arquivos unificados ficarão salvos na pasta "output"
OUTPUT_DIR <- "tasks/unifica-dados/output"

# dados de teste
CAMINHO_DADOS_DE_TESTE <- here("src/ETL/dados-de-teste/amostra_medicamentos.csv")

# Arquivo: https://drive.google.com/file/d/1JxG_TQh9CMTdVykG0_gJk3YdengNF69V
CAMINHO_ITENS_COLETA1 <- here(INPUT_DIR, "itens1.rds")

# Arquivo: https://drive.google.com/file/d/1YttE9nGYI5NRzFe2VSNqDSPcpSqZoWU7
CAMINHO_ITENS_COLETA2 <- here(INPUT_DIR, "itens2.rds")

# Arquivo: https://drive.google.com/file/d/1qUsnlRLyAafgCEYQcTzsU47Yw4nT-qqn
CAMINHO_ITENS_COLETA3 <- here(INPUT_DIR, "itens3.rds")

# CARREGA COLETAS --------------------------------------------------------------

itens_coleta1 <- readRDS(CAMINHO_ITENS_COLETA1) %>%
  as_tibble() %>%
  filter(is.na(error)) # remove linhas com erro de coleta

itens_coleta2 <- readRDS(CAMINHO_ITENS_COLETA2) %>%
  as_tibble()

itens_coleta3 <- readRDS(CAMINHO_ITENS_COLETA3) %>%
  as_tibble()

# dados de teste:
# Serve como referência para preencher nome de colunas e garantir que os dataframes possuem colunas de mesmo tipo
template <- read_csv(CAMINHO_DADOS_DE_TESTE, col_types = cols(.default = col_character()))[1:5, 1:32] %>%
  mutate(endpoint = NA_character_)

# MAPPING ----------------------------------------------------------------------
# Mapeamento das colunas dos arquivos de itens

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

# COLETA I ---

itens_coleta1 <- itens_coleta1 %>%
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

# expected: `faltando` e `extras`` vazios e `comuns` com 33 elementos
comparar_colunas(itens_coleta1, template)

# COLETA II ---

itens_coleta2 <- itens_coleta2 %>%
  # colunas que existiam na coleta II
  select(
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
    endpoint = endpoint,
    # codigo_pdm = codigo_pdm
  ) %>%
  # colunas que foram criadas depois da coleta II
  mutate(
    catalogo = NA_character_,
    categoriaItemCatalogo = NA_character_,
    # catalogoCodigoItem = NA_character_,
    # informacaoComplementar = NA_character_
  )

# expected: `faltando` e `extras` vazios e `comuns` com 33 elementos
comparar_colunas(itens_coleta2, template)

# COLETA III ---

itens_coleta3 <- itens_coleta3 %>%
  select(
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
    endpoint = endpoint,
    # codigo_pdm = codigo_pdm
  )

# expected: `faltando` e `extras` vazios e `comuns` com 33 elementos
comparar_colunas(itens_coleta3, template)

# ORDENAR COLUNA ---

# Alinhar perfeitamente as colunas
ordenar_colunas <- \(coleta, template) select(coleta, names(template))

itens_coleta1 <- ordenar_colunas(itens_coleta1, template)
itens_coleta2 <- ordenar_colunas(itens_coleta2, template)
itens_coleta3 <- ordenar_colunas(itens_coleta3, template)

# FORÇA TIPO DE TEMPLATE ---

# Certifica-se que os dataframes possuem colunas de mesmo tipo (para uní-los)
coerce_class <- \(coleta) mutate(coleta, across(everything(), \(x) as.character(x)))

itens_coleta1 <- coerce_class(itens_coleta1)
itens_coleta2 <- coerce_class(itens_coleta2)
itens_coleta3 <- coerce_class(itens_coleta3)

# UNIFICA COLETAS --------------------------------------------------------------

# Une os dados de contratações de todas as coletas.
itens <- bind_rows(itens_coleta1, itens_coleta2, itens_coleta3)

# Salva o arquivo em formato rds
saveRDS(itens, here(OUTPUT_DIR, "itens.csv"))
