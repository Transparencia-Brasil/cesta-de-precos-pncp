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

# Arquivo: https://drive.google.com/file/d/1JxG_TQh9CMTdVykG0_gJk3YdengNF69V
CAMINHO_ITENS_COLETA1 <- here(INPUT_DIR, "itens1.rds")

# Arquivo: https://drive.google.com/file/d/1YttE9nGYI5NRzFe2VSNqDSPcpSqZoWU7
CAMINHO_ITENS_COLETA2 <- here(INPUT_DIR, "itens2.rds")

# Arquivo: https://drive.google.com/file/d/1qUsnlRLyAafgCEYQcTzsU47Yw4nT-qqn
CAMINHO_ITENS_COLETA3 <- here(INPUT_DIR, "itens3.rds")

# CARREGA COLETAS --------------------------------------------------------------
itens_coleta1 <- readRDS(CAMINHO_ITENS_COLETA1) %>%
  as_tibble() %>%
  filter(is.na(error))

itens_coleta2 <- readRDS(CAMINHO_ITENS_COLETA2) %>%
  as_tibble()

itens_coleta3 <- readRDS(CAMINHO_ITENS_COLETA3) %>%
  as_tibble()

itens_coleta1 <- itens_coleta1 %>%
  select(
    "numeroItem" = "numeroItem",
    "descricao" = "descricao",
    "materialOuServico" = "materialOuServico",
    "materialOuServicoNome" = "materialOuServicoNome",
    "valorUnitarioEstimado" = "valorUnitarioEstimado",
    "valorTotal" = "valorTotal",
    "quantidade" = "quantidade",
    "unidadeMedida" = "unidadeMedida",
    "orcamentoSigiloso" = "orcamentoSigiloso",
    "itemCategoriaId" = "itemCategoriaId",
    "itemCategoriaNome" = "itemCategoriaNome",
    "patrimonio" = "patrimonio",
    "codigoRegistroImobiliario" = "codigoRegistroImobiliario",
    "criterioJulgamentoId" = "criterioJulgamentoId",
    "criterioJulgamentoNome" = "criterioJulgamentoNome",
    "situacaoCompraItem" = "situacaoCompraItem",
    "situacaoCompraItemNome" = "situacaoCompraItemNome",
    "tipoBeneficio" = "tipoBeneficio",
    "tipoBeneficioNome" = "tipoBeneficioNome",
    "incentivoProdutivoBasico" = "incentivoProdutivoBasico",
    "dataInclusao" = "dataInclusao",
    "dataAtualizacao" = "dataAtualizacao",
    "temResultado" = "temResultado",
    "imagem" = "imagem",
    # "aplicabilidadeMargemPreferenciaNormal" = "",
    # "aplicabilidadeMargemPreferenciaAdicional" = "",
    # "percentualMargemPreferenciaNormal" = "",
    # "percentualMargemPreferenciaAdicional" = "",
    # "ncmNbsCodigo" = "",
    # "ncmNbsDescricao" = "",
    # "catalogo" = "",
    # "categoriaItemCatalogo" = "",
    # "catalogoCodigoItem" = "",
    # "informacaoComplementar" = "",
    "endpoint" = "pncp_endpoint",
    # "codigo_pdm" = "",
    # "codigo_br" = "",
    # "similaridade" = "",
    # "medicamento" = ""
  ) %>%
  mutate(
    aplicabilidadeMargemPreferenciaNormal = NA_character_,
    aplicabilidadeMargemPreferenciaAdicional = NA_character_,
    percentualMargemPreferenciaNormal = NA_character_,
    percentualMargemPreferenciaAdicional = NA_character_,
    ncmNbsCodigo = NA_character_,
    ncmNbsDescricao = NA_character_,
    catalogo = NA_character_,
    categoriaItemCatalogo = NA_character_,
    catalogoCodigoItem = NA_character_,
    informacaoComplementar = NA_character_,
    codigo_pdm = NA_character_
  )

itens_coleta2 <- itens_coleta2 %>%
  select(
    "numeroItem" = "numeroItem",
    "descricao" = "descricao",
    "materialOuServico" = "materialOuServico",
    "materialOuServicoNome" = "materialOuServicoNome",
    "valorUnitarioEstimado" = "valorUnitarioEstimado",
    "valorTotal" = "valorTotal",
    "quantidade" = "quantidade",
    "unidadeMedida" = "unidadeMedida",
    "orcamentoSigiloso" = "orcamentoSigiloso",
    "itemCategoriaId" = "itemCategoriaId",
    "itemCategoriaNome" = "itemCategoriaNome",
    "patrimonio" = "patrimonio",
    "codigoRegistroImobiliario" = "codigoRegistroImobiliario",
    "criterioJulgamentoId" = "criterioJulgamentoId",
    "criterioJulgamentoNome" = "criterioJulgamentoNome",
    "situacaoCompraItem" = "situacaoCompraItem",
    "situacaoCompraItemNome" = "situacaoCompraItemNome",
    "tipoBeneficio" = "tipoBeneficio",
    "tipoBeneficioNome" = "tipoBeneficioNome",
    "incentivoProdutivoBasico" = "incentivoProdutivoBasico",
    "dataInclusao" = "dataInclusao",
    "dataAtualizacao" = "dataAtualizacao",
    "temResultado" = "temResultado",
    "imagem" = "imagem",
    "aplicabilidadeMargemPreferenciaNormal" = "aplicabilidadeMargemPreferenciaNormal",
    "aplicabilidadeMargemPreferenciaAdicional" = "aplicabilidadeMargemPreferenciaAdicional",
    "percentualMargemPreferenciaNormal" = "percentualMargemPreferenciaNormal",
    "percentualMargemPreferenciaAdicional" = "percentualMargemPreferenciaAdicional",
    "ncmNbsCodigo" = "ncmNbsCodigo",
    "ncmNbsDescricao" = "ncmNbsDescricao",
    # "catalogo" = "",
    # "categoriaItemCatalogo" = "",
    # "catalogoCodigoItem" = "",
    # "informacaoComplementar" = "",
    "endpoint" = "endpoint",
    "codigo_pdm" = "codigo_pdm",
    # "codigo_br" = "",
    # "similaridade" = "",
    # "medicamento" = ""
  ) %>%
  mutate(
    "catalogo" = NA_character_,
    "categoriaItemCatalogo" = NA_character_,
    "catalogoCodigoItem" = NA_character_,
    "informacaoComplementar" = NA_character_
  )

itens_coleta3 <- itens_coleta3 %>%
  select(
    "numeroItem" = "numeroItem",
    "descricao" = "descricao",
    "materialOuServico" = "materialOuServico",
    "materialOuServicoNome" = "materialOuServicoNome",
    "valorUnitarioEstimado" = "valorUnitarioEstimado",
    "valorTotal" = "valorTotal",
    "quantidade" = "quantidade",
    "unidadeMedida" = "unidadeMedida",
    "orcamentoSigiloso" = "orcamentoSigiloso",
    "itemCategoriaId" = "itemCategoriaId",
    "itemCategoriaNome" = "itemCategoriaNome",
    "patrimonio" = "patrimonio",
    "codigoRegistroImobiliario" = "codigoRegistroImobiliario",
    "criterioJulgamentoId" = "criterioJulgamentoId",
    "criterioJulgamentoNome" = "criterioJulgamentoNome",
    "situacaoCompraItem" = "situacaoCompraItem",
    "situacaoCompraItemNome" = "situacaoCompraItemNome",
    "tipoBeneficio" = "tipoBeneficio",
    "tipoBeneficioNome" = "tipoBeneficioNome",
    "incentivoProdutivoBasico" = "incentivoProdutivoBasico",
    "dataInclusao" = "dataInclusao",
    "dataAtualizacao" = "dataAtualizacao",
    "temResultado" = "temResultado",
    "imagem" = "imagem",
    "aplicabilidadeMargemPreferenciaNormal" = "aplicabilidadeMargemPreferenciaNormal",
    "aplicabilidadeMargemPreferenciaAdicional" = "aplicabilidadeMargemPreferenciaAdicional",
    "percentualMargemPreferenciaNormal" = "percentualMargemPreferenciaNormal",
    "percentualMargemPreferenciaAdicional" = "percentualMargemPreferenciaAdicional",
    "ncmNbsCodigo" = "ncmNbsCodigo",
    "ncmNbsDescricao" = "ncmNbsDescricao",
    "catalogo" = "catalogo",
    "categoriaItemCatalogo" = "categoriaItemCatalogo",
    "catalogoCodigoItem" = "catalogoCodigoItem",
    "informacaoComplementar" = "informacaoComplementar",
    "endpoint" = "endpoint",
    "codigo_pdm" = "codigo_pdm",
    # "codigo_br" = "",
    # "similaridade" = "",
    # "medicamento" = ""
  )

# Renomeia as colunas e seleciona somente as necessárias

itens_coleta1 <- itens_coleta1 %>%
  mutate(catalogo = NA, catalogoCodigoItem = NA, categoriaItemCatalogo = NA)


list(itens_coleta1, itens_coleta2, itens_coleta3) %>%
  map(names) %>%
  set_names(c("coleta1", "coleta2", "coleta3")) %>%
  enframe(name = "dataset", value = "nomeCol") %>%
  unnest(nomeCol) %>%
  add_count(nomeCol) %>%
  filter(n < 3) %>%
  arrange(nomeCol)


# Certifica-se que os dataframes possuem colunas de mesmo tipo (para uní-los)

list(coleta1 = itens_coleta1, coleta2 = itens_coleta2, coleta3 = itens_coleta3) %>%
  map_df(~ mutate(.x, across(everything(), \(x) as.character(x))))

itens_coleta1 <- map2_dfr(itens_coleta1, itens_coleta2, ~ as(.x, class(.y)))
itens_coleta3 <- map2_dfr(itens_coleta3, itens_coleta2, ~ as(.x, class(.y)))

# Une os dados de contratações de todas as coletas.
itens <- bind_rows(itens_coleta1, itens_coleta2, itens_coleta3)

# Salva o arquivo em formato rds
itens %>% saveRDS(here("itens.csv"))
