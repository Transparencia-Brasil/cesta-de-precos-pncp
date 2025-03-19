#' Este script une os dados de contratações de medicamentos.
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

# FILEPATHS --------------------------------------------------------------------

# os arquivos de coleta foram baixados do google drive e salvos localmente com o script "download-de-dados.R"
INPUT_DIR <- "tasks/unifica-dados/input"

# os arquivos unificados ficarão salvos na pasta "output"
OUTPUT_DIR <- "tasks/unifica-dados/output"

# Arquivo: https://drive.google.com/file/d/1Al2pfTFfa_ODGgHlq7ApiyfAnpJpbuEK/view?usp=drive_link
CAMINHO_CONTRATACOES_COLETA2 <- here(INPUT_DIR, "contratacoes2.rds")
# Arquivo: https://drive.google.com/file/d/1VfrLyZoGOoc9ugF2lvLeKwcBbiReVpZm/view?usp=drive_link
CAMINHO_CONTRATACOES_COLETA3 <- here(INPUT_DIR, "contratacoes3.rds")

# CARREGA COLETAS --------------------------------------------------------------
contratacoes_coleta2 <- readRDS(CAMINHO_CONTRATACOES_COLETA2)
contratacoes_coleta3 <- readRDS(CAMINHO_CONTRATACOES_COLETA3)

# MAPPING ----------------------------------------------------------------------

# Mapeamento das colunas dos arquivos de contratações
mapeamento_colunas <- c(
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

# Renomeia as colunas e seleciona somente as necessárias
contratacoes_coleta2 <- contratacoes_coleta2 %>%
  rename(all_of(mapeamento_colunas)) %>%
  select(names(mapeamento_colunas))

contratacoes_coleta3 <- contratacoes_coleta3 %>%
  rename(all_of(mapeamento_colunas)) %>%
  select(names(mapeamento_colunas))

# Certifica-se que os dataframes possuem colunas de mesmo tipo (para uní-los)
contratacoes_coleta3 <- map2_dfr(contratacoes_coleta3, contratacoes_coleta2, ~ as(.x, class(.y)))

# Une os dados de contratações de todas as coletas.
contratacoes <- bind_rows(contratacoes_coleta2, contratacoes_coleta3)

# Salva o arquivo em formato rds
dir.create(here(OUTPUT_DIR))
saveRDS(contratacoes, here(OUTPUT_DIR, "contratacoes.csv"))
