#' Este script une os dados de contratações de medicamentos, itens das contratações
#' e resultados de homologação destes itens. Esta unificação busca facilitar a análise
#' de variação de preços de medicamentos.
#'
#' Coleta 1: https://drive.google.com/drive/folders/1A9mNmKapHchsy9qqXCdg2xAh9pnnOWaJ?usp=drive_link
#'    * Contratações - 07_detalhamento_da_contratacao-2024-05-02.csv
#'    * itens - 10-itens-da-contratacao-2024-03-06.rds
#' 
#' Coleta 2: https://drive.google.com/drive/folders/1ZZ5ysQixMzT4srwCpirGhGsm9OpWeKy9?usp=drive_link
#' Coleta 3: https://drive.google.com/drive/folders/13euL1rcl01dj3pQciLrMUj5yCnGf7ako
#' 
#' Nota: Baixe os arquivos por conta própria, eles não serão enviados ao github, 
#' pois são grandes demais.

library(readr)
library(dplyr)
library(purrr)
library(here)


# ITENS DAS CONTRATAÇÕES --------------------------------------------------

# Arquivo: https://drive.google.com/file/d/1JxG_TQh9CMTdVykG0_gJk3YdengNF69V/view?usp=drive_link
CAMINHO_ITENS_COLETA1 <- "insira/seu/caminho/itens1"
# Arquivo: https://drive.google.com/file/d/1YttE9nGYI5NRzFe2VSNqDSPcpSqZoWU7/view?usp=drive_link
CAMINHO_ITENS_COLETA2 <- "insira/seu/caminho/itens2"
# Arquivo: https://drive.google.com/file/d/1qUsnlRLyAafgCEYQcTzsU47Yw4nT-qqn/view?usp=drive_link
CAMINHO_ITENS_COLETA3 <- "insira/seu/caminho/itens3"

itens_coleta1 <- readRDS(CAMINHO_ITENS_COLETA1)
itens_coleta2 <- readRDS(CAMINHO_ITENS_COLETA2)
itens_coleta3 <- readRDS(CAMINHO_ITENS_COLETA3)

# Continua...

# CONTRATAÇÕES ------------------------------------------------------------

# Arquivo: https://drive.google.com/file/d/1shxwi4GTrZNnrAnP3L6qHDEFLIoYFeog/view?usp=drive_link
CAMINHO_CONTRATACOES_COLETA1 <- "insira/seu/caminho/contratacoes1"
# Arquivo: https://drive.google.com/file/d/1Al2pfTFfa_ODGgHlq7ApiyfAnpJpbuEK/view?usp=drive_link
CAMINHO_CONTRATACOES_COLETA2 <- "insira/seu/caminho/contratacoes2"
# Arquivo: https://drive.google.com/file/d/1VfrLyZoGOoc9ugF2lvLeKwcBbiReVpZm/view?usp=drive_link
CAMINHO_CONTRATACOES_COLETA3 <- "insira/seu/caminho/contratacoes3"
  
contratacoes_coleta1 <- readRDS(CAMINHO_CONTRATACOES_COLETA1)
contratacoes_coleta2 <- readRDS(CAMINHO_CONTRATACOES_COLETA2)
contratacoes_coleta3 <- readRDS(CAMINHO_CONTRATACOES_COLETA3)

mapeamento_colunas <- c(
  "data.orgaoEntidade.cnpj"         = "orgaoEntidade_cnpj",
  "data.orgaoEntidade.razaoSocial"  = "orgaoEntidade_razaoSocial",
  "data.orgaoEntidade.esferaId"     = "orgaoEntidade_esferaId",
  "data.orgaoEntidade.poderId"      = "orgaoEntidade_poderId",
  "data.unidadeOrgao.codigoUnidade" = "unidadeOrgao_codigoUnidade",
  "data.unidadeOrgao.nomeUnidade"   = "unidadeOrgao_nomeUnidade",
  "data.unidadeOrgao.codigoIbge"    = "unidadeOrgao_codigoIbge",
  "data.unidadeOrgao.municipioNome" = "unidadeOrgao_municipioNome",
  "data.unidadeOrgao.ufSigla"       = "unidadeOrgao_ufSigla",
  "data.unidadeOrgao.ufNome"        = "unidadeOrgao_ufNome",
  
  "data.orgaoSubRogado.cnpj"            = "orgaoSubRogado_cnpj",
  "data.orgaoSubRogado.razaoSocial"     = "orgaoSubRogado_razaoSocial",
  "data.orgaoSubRogado.esferaId"        = "orgaoSubRogado_esferaId",
  "data.orgaoSubRogado.poderId"         = "orgaoSubRogado_poderId",
  "data.unidadeSubRogada.codigoUnidade" = "unidadeSubRogada_codigoUnidade",
  "data.unidadeSubRogada.nomeUnidade"   = "unidadeSubRogada_nomeUnidade",
  "data.unidadeSubRogada.codigoIbge"    = "unidadeSubRogada_codigoIbge",
  "data.unidadeSubRogada.municipioNome" = "unidadeSubRogada_municipioNome",
  "data.unidadeSubRogada.ufSigla"       = "unidadeSubRogada_ufSigla",
  "data.unidadeSubRogada.ufNome"        = "unidadeSubRogada_ufNome",
  
  "data.numeroControlePNCP"                = "numeroControlePNCP",
  "data.anoCompra"                         = "anoCompra",
  "data.sequencialCompra"                  = "sequencialCompra",
  "data.objetoCompra"                      = "objetoCompra",
  "data.dataAberturaProposta"              = "dataAberturaProposta",
  "data.dataEncerramentoProposta"          = "dataEncerramentoProposta",
  "data.valorTotalEstimado"                = "valorTotalEstimado",
  "data.valorTotalHomologado"              = "valorTotalHomologado",
  "data.srp"                               = "srp",
  "data.tipoInstrumentoConvocatorioCodigo" = "tipoInstrumentoConvocatorioCodigo",
  "data.tipoInstrumentoConvocatorioNome"   = "tipoInstrumentoConvocatorioNome",
  "data.modalidadeId"                      = "modalidadeId",
  "data.modalidadeNome"                    = "modalidadeNome",
  "data.amparoLegal.codigo"                = "amparoLegal_codigo",
  "data.amparoLegal.nome"                  = "amparoLegal_nome",
  "data.modoDisputaId"                     = "modoDisputaId",
  "data.modoDisputaNome"                   = "modoDisputaNome"
)

# Renomeia as colunas e seleciona somente as necessárias
contratacoes_coleta1 <- contratacoes_coleta1 %>% 
  rename(all_of(mapeamento_colunas)) %>%
  select(names(mapeamento_colunas))

contratacoes_coleta2 <- contratacoes_coleta2 %>% 
  rename(all_of(mapeamento_colunas)) %>%
  select(names(mapeamento_colunas))

contratacoes_coleta3 <- contratacoes_coleta3 %>% 
  rename(all_of(mapeamento_colunas)) %>%
  select(names(mapeamento_colunas))

# Certifica-se que os dataframes possuem colunas de mesmo tipo (para uní-los)
contratacoes_coleta1 <- map2_dfr(contratacoes_coleta1, contratacoes_coleta2, ~ as(.x, class(.y)))
contratacoes_coleta3 <- map2_dfr(contratacoes_coleta3, contratacoes_coleta2, ~ as(.x, class(.y)))

# Une os dados de contratações de todas as coletas.
contratacoes = bind_rows(contratacoes_coleta1, contratacoes_coleta2, contratacoes_coleta3)

# Salva o arquivo em formato rds
contratacoes %>% saveRDS(here("contratacoes.csv"))


