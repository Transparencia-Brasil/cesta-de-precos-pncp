library(tidyverse)
library(here)

source(here("tasks/atualiza-catmat/src/R/utils.R"))

# :: DIRETÓRIOS ----------------------------------------------------------------

# Caminhos relativos são resolvidos a partir da raiz do projeto. As variáveis de
# ambiente permitem rodar o versionamento sobre uma cópia (ex.: em testes).
resolve_dir <- function(caminho) {
  if (fs::is_absolute_path(caminho)) caminho else here(caminho)
}

CATMAT_DIR <- resolve_dir(Sys.getenv("CATMAT_DIR", "data/catmat"))
ATUALIZACAO_DIR <- resolve_dir(Sys.getenv("ATUALIZACAO_DIR", "tasks/atualiza-catmat/outputs"))

# Histórico de versões (um registro por arquivo versionado)
CAMINHO_VERSOES <- file.path(CATMAT_DIR, "versoes.csv")


# :: VERSIONAMENTO -------------------------------------------------------------

get_current_version <- function(CATMAT_DIR) {

  CATMAT_FILE <- list.files(CATMAT_DIR, pattern = "catmat-\\d+\\.rds")

  CURRENT_VERSION <- CATMAT_FILE |>
    str_extract("\\d+") |>
    as.integer() |>
    max(na.rm = TRUE)

  CURRENT_VERSION
}

OLD_VERSION <- get_current_version(CATMAT_DIR)
NEW_VERSION <- OLD_VERSION + 1

message("Versão antiga: ", OLD_VERSION, " será substituída pela nova: ", NEW_VERSION)


# :: OLD PATHS -----------------------------------------------------------------

OLD_DIR <- file.path(CATMAT_DIR, "OLD", OLD_VERSION)

OLD_FILE_OCDS <- sprintf("tabela-mapeamento-ocds-%s.csv", OLD_VERSION)
OLD_FILE_CATALOGO <- sprintf("catmat-%s.rds", OLD_VERSION)
OLD_FILE_CLASSIFICADOR <- sprintf("catmat-%s.csv", OLD_VERSION)
OLD_FILE_DICIONARIO <- sprintf("dicionario-medicamentos-ocds-%s.csv", OLD_VERSION)


# :: NEW PATHS -----------------------------------------------------------------

NEW_FILE_OCDS <- sprintf("tabela-mapeamento-ocds-%s.csv", NEW_VERSION)
NEW_FILE_CATALOGO <- sprintf("catmat-%s.rds", NEW_VERSION)
NEW_FILE_CLASSIFICADOR <- sprintf("catmat-%s.csv", NEW_VERSION)
NEW_FILE_DICIONARIO <- sprintf("dicionario-medicamentos-ocds-%s.csv", NEW_VERSION)

# Proveniência gerada por `01-importa-caracteristicas-ocds.R`
CAMINHO_PROVENIENCIA <- file.path(ATUALIZACAO_DIR, "proveniencia-ocds.csv")


# :: GERA CATÁLOGO DO CLASSIFICADOR -------------------------------------------

CATMAT_CLASSIFICADOR_COLUNAS <- c(
  "codigo_pdm",
  "nome_pdm",
  "codigo_br",
  "nome_item"
)

CAMINHO_CATALOGO_ATUALIZADO <- file.path(ATUALIZACAO_DIR, "catmat.rds")
CAMINHO_CATALOGO_CLASSIFICADOR <- file.path(ATUALIZACAO_DIR, "catmat.csv")
CAMINHO_DICIONARIO_ATUALIZADO <- file.path(ATUALIZACAO_DIR, "dicionario-medicamentos-ocds.csv")

catalogo_atualizado <- readRDS(CAMINHO_CATALOGO_ATUALIZADO)

catalogo_atualizado |>
  select(all_of(CATMAT_CLASSIFICADOR_COLUNAS)) |>
  write_csv(CAMINHO_CATALOGO_CLASSIFICADOR)


# :: VERIFICAÇÕES PRÉVIAS ------------------------------------------------------

pivot_new <- tibble(
  from = c(
    file.path(ATUALIZACAO_DIR, "tabela-mapeamento-ocds.csv"),
    CAMINHO_CATALOGO_ATUALIZADO,
    CAMINHO_CATALOGO_CLASSIFICADOR,
    CAMINHO_DICIONARIO_ATUALIZADO
  ),
  to = c(
    file.path(CATMAT_DIR, NEW_FILE_OCDS),
    file.path(CATMAT_DIR, NEW_FILE_CATALOGO),
    file.path(CATMAT_DIR, NEW_FILE_CLASSIFICADOR),
    file.path(CATMAT_DIR, NEW_FILE_DICIONARIO)
  )
)

# Nada é movido se faltar algum arquivo da nova versão: mover a versão antiga
# para OLD/ sem ter a nova completa deixaria `data/catmat/` inconsistente.
arquivos_ausentes <- pivot_new$from[!file.exists(pivot_new$from)]
if (length(arquivos_ausentes) > 0) {
  stop(
    "Arquivos da nova versão ausentes (rode 00 e 01 antes): ",
    paste(arquivos_ausentes, collapse = ", ")
  )
}

destinos_existentes <- pivot_new$to[file.exists(pivot_new$to)]
if (length(destinos_existentes) > 0) {
  stop("A nova versão já existe: ", paste(destinos_existentes, collapse = ", "))
}

# o dicionário OCDS precisa cobrir exatamente os códigos do novo catálogo
valida_dicionario_ocds(CAMINHO_DICIONARIO_ATUALIZADO, catalogo_atualizado$codigo_br)

if (file.exists(CAMINHO_PROVENIENCIA)) {
  proveniencia <- read_csv(
    CAMINHO_PROVENIENCIA,
    col_types = cols(.default = col_character()),
    show_col_types = FALSE
  )
} else {
  warning("Proveniência não encontrada em ", CAMINHO_PROVENIENCIA, "; origem ficará vazia no histórico.")
  proveniencia <- tibble(
    arquivo = character(),
    origem_repo = character(),
    origem_caminho = character(),
    origem_commit = character()
  )
}


# :: MOVIMENTA ARQUIVOS ANTIGOS ------------------------------------------------

copia_arquivos <- function(pivot) {
  copiados <- pmap_lgl(pivot, file.copy)
  if (!all(copiados)) {
    stop("Falha ao copiar: ", paste(pivot$from[!copiados], collapse = ", "))
  }
  unlink(pivot$from)
}

# cria diretório OLD
if (!dir.exists(OLD_DIR)) dir.create(OLD_DIR, recursive = TRUE)

pivot_old <- tibble(
  from = c(
    file.path(CATMAT_DIR, OLD_FILE_OCDS),
    file.path(CATMAT_DIR, OLD_FILE_CATALOGO),
    file.path(CATMAT_DIR, OLD_FILE_CLASSIFICADOR),
    file.path(CATMAT_DIR, OLD_FILE_DICIONARIO)
  ),
  to = c(
    file.path(OLD_DIR, OLD_FILE_OCDS),
    file.path(OLD_DIR, OLD_FILE_CATALOGO),
    file.path(OLD_DIR, OLD_FILE_CLASSIFICADOR),
    file.path(OLD_DIR, OLD_FILE_DICIONARIO)
  )
)

# move arquivos antigos para o diretório OLD
pivot_old |>
  filter(file.exists(from)) |>
  copia_arquivos()


# :: MOVIMENTA ARQUIVOS NOVOS --------------------------------------------------

# move arquivos novos para o diretório CATMAT
copia_arquivos(pivot_new)


# :: HISTÓRICO DE VERSÕES ------------------------------------------------------

origem_de <- function(arquivo_atualizacao, campo) {
  valor <- proveniencia[[campo]][proveniencia$arquivo == arquivo_atualizacao]
  if (length(valor) == 0) NA_character_ else valor[[1]]
}

registro_com_origem <- function(caminho, arquivo_atualizacao = NA_character_) {
  registro_versao(
    NEW_VERSION,
    caminho,
    origem_repo = origem_de(arquivo_atualizacao, "origem_repo"),
    origem_caminho = origem_de(arquivo_atualizacao, "origem_caminho"),
    origem_commit = origem_de(arquivo_atualizacao, "origem_commit")
  )
}

bind_rows(
  registro_com_origem(file.path(CATMAT_DIR, NEW_FILE_CATALOGO)),
  registro_com_origem(file.path(CATMAT_DIR, NEW_FILE_CLASSIFICADOR)),
  registro_com_origem(file.path(CATMAT_DIR, NEW_FILE_OCDS), "tabela-mapeamento-ocds.csv"),
  registro_com_origem(file.path(CATMAT_DIR, NEW_FILE_DICIONARIO), "dicionario-medicamentos-ocds.csv")
) |>
  registra_versoes(CAMINHO_VERSOES)

unlink(CAMINHO_PROVENIENCIA)

readRDS(file.path(CATMAT_DIR, NEW_FILE_CATALOGO))
