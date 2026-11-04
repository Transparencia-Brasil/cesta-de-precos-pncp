# :: CONTEXTO ------------------------------------------------------------------

#' Execução única: inclui o dicionário OCDS de medicamentos no versionamento
#' do CATMAT e cria o histórico de versões `data/catmat/versoes.csv`.
#'
#' Até a versão 1, o dicionário consumido pelo mapeamento PNCP -> OCDS
#' (`tasks/mapeamento-ocds/input/dicionario-medicamentos-ocds.csv`) era uma
#' cópia manual do `dicionario-ocds.csv` do repositório `medicine-extension-ocds`
#' e ficava fora do versionamento de `03-versionamento.R`. Este script preenche
#' os slots já existentes, sem criar uma nova versão:
#'
#' - v0: o dicionário efetivamente usado nas publicações OCDS de 2025/01 a
#'   2026/04 (cópia local, idêntica ao upstream no commit 15d5f37).
#' - v1: o dicionário do upstream no commit 9b4c3d1, gerado a partir do
#'   CATMAT v1 (6.740 códigos).
#'
#' É idempotente: se os destinos já existirem com o mesmo conteúdo, nada muda;
#' se existirem com conteúdo diferente, a execução é interrompida.
#'
#' Uso (a partir da raiz do repositório):
#'   Rscript.exe tasks/atualiza-catmat/src/R/backfill-dicionario-ocds.R


library(here)

source(here("tasks/atualiza-catmat/src/R/utils.R"))
carrega_env()


# :: PARÂMETROS ----------------------------------------------------------------

CATMAT_DIR <- here("data/catmat")
CAMINHO_VERSOES <- here(CATMAT_DIR, "versoes.csv")

COMMIT_DICIONARIO_V0 <- "15d5f37d5306469a0a142fae0f1bdd74129f35cb"
COMMIT_DICIONARIO_V1 <- "9b4c3d150a605f085611a6359e94382c86bc8ff4"
COMMIT_DOCUMENTO_V1 <- COMMIT_DICIONARIO_V1  # mesmo commit gerou o documento-ocds.json da v1

ORIGEM_DICIONARIO_V0 <- here("tasks/mapeamento-ocds/input/dicionario-medicamentos-ocds.csv")

DESTINO_DICIONARIO_V0 <- here(CATMAT_DIR, "OLD", "0", "dicionario-medicamentos-ocds-0.csv")
DESTINO_DICIONARIO_V1 <- here(CATMAT_DIR, "dicionario-medicamentos-ocds-1.csv")


# :: FUNÇÕES -------------------------------------------------------------------

#' Grava `conteudo` em `destino` apenas se ele não existir ou já for idêntico
grava_se_ausente <- function(conteudo, destino) {
  temporario <- tempfile(fileext = paste0(".", tools::file_ext(destino)))
  on.exit(unlink(temporario))
  writeBin(conteudo, temporario)

  if (file.exists(destino)) {
    if (sha256_normalizado(destino) != sha256_normalizado(temporario)) {
      stop(sprintf("%s já existe com conteúdo diferente; abortando.", destino))
    }
    message(sprintf("Já existe e é idêntico: %s", destino))
    return(invisible(destino))
  }

  dir.create(dirname(destino), recursive = TRUE, showWarnings = FALSE)
  writeBin(conteudo, destino)
  message(sprintf("Gravado: %s", destino))
  invisible(destino)
}

codigos_catmat <- function(caminho_csv) {
  readr::read_csv(
    caminho_csv,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE,
    progress = FALSE
  )$codigo_br
}


# :: v0 ------------------------------------------------------------------------

message("== v0: dicionário usado nas publicações OCDS até 2026/04")

conteudo_v0_local <- readBin(ORIGEM_DICIONARIO_V0, what = "raw", n = file.size(ORIGEM_DICIONARIO_V0))
conteudo_v0_upstream <- baixa_arquivo_medicine_extension(
  MEDICINE_EXTENSION_DICIONARIO_OCDS,
  COMMIT_DICIONARIO_V0
)

# confirma a proveniência: cópia local == upstream no commit informado
arquivo_upstream_v0 <- tempfile(fileext = ".csv")
writeBin(conteudo_v0_upstream, arquivo_upstream_v0)
if (sha256_normalizado(ORIGEM_DICIONARIO_V0) != sha256_normalizado(arquivo_upstream_v0)) {
  stop("A cópia local do dicionário não coincide com o upstream no commit ", COMMIT_DICIONARIO_V0)
}
unlink(arquivo_upstream_v0)

grava_se_ausente(conteudo_v0_local, DESTINO_DICIONARIO_V0)
valida_dicionario_ocds(
  DESTINO_DICIONARIO_V0,
  codigos_catmat(here(CATMAT_DIR, "OLD", "0", "catmat-0.csv"))
)


# :: v1 ------------------------------------------------------------------------

message("== v1: dicionário gerado a partir do CATMAT v1")

conteudo_v1 <- baixa_arquivo_medicine_extension(
  MEDICINE_EXTENSION_DICIONARIO_OCDS,
  COMMIT_DICIONARIO_V1
)

grava_se_ausente(conteudo_v1, DESTINO_DICIONARIO_V1)
valida_dicionario_ocds(
  DESTINO_DICIONARIO_V1,
  codigos_catmat(here(CATMAT_DIR, "catmat-1.csv"))
)


# :: HISTÓRICO DE VERSÕES ------------------------------------------------------

message("== Histórico de versões")

registro_dicionario <- function(versao, caminho, commit) {
  registro_versao(
    versao,
    caminho,
    origem_repo = MEDICINE_EXTENSION_REPO,
    origem_caminho = MEDICINE_EXTENSION_DICIONARIO_OCDS,
    origem_commit = commit
  )
}

registro_tabela <- function(versao, caminho, commit = NA_character_) {
  # gerada por 01-importa-caracteristicas-ocds.R a partir do documento-ocds.json
  registro_versao(
    versao,
    caminho,
    origem_repo = MEDICINE_EXTENSION_REPO,
    origem_caminho = MEDICINE_EXTENSION_DOCUMENTO_OCDS,
    origem_commit = commit
  )
}

# Origem da tabela v0: não registrada à época e não reproduzível hoje.
# Origem da tabela v1: `01-importa-caracteristicas-ocds.R` rodado sobre o
# documento-ocds.json do commit 9b4c3d1 (último a alterá-lo) reproduz
# `tabela-mapeamento-ocds-1.csv` byte a byte (verificado em 04/11/2026).
registros <- dplyr::bind_rows(
  registro_versao(0, here(CATMAT_DIR, "OLD", "0", "catmat-0.rds")),
  registro_versao(0, here(CATMAT_DIR, "OLD", "0", "catmat-0.csv")),
  registro_tabela(0, here(CATMAT_DIR, "OLD", "0", "tabela-mapeamento-ocds-0.csv")),
  registro_dicionario(0, DESTINO_DICIONARIO_V0, COMMIT_DICIONARIO_V0),
  registro_versao(1, here(CATMAT_DIR, "catmat-1.rds")),
  registro_versao(1, here(CATMAT_DIR, "catmat-1.csv")),
  registro_tabela(1, here(CATMAT_DIR, "tabela-mapeamento-ocds-1.csv"), COMMIT_DOCUMENTO_V1),
  registro_dicionario(1, DESTINO_DICIONARIO_V1, COMMIT_DICIONARIO_V1)
)

registra_versoes(registros, CAMINHO_VERSOES)

print(readr::read_csv(CAMINHO_VERSOES, show_col_types = FALSE), width = Inf)
