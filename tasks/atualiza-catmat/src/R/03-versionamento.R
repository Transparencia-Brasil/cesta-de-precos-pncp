library(tidyverse)
library(here)

# :: DIRETÓRIOS ----------------------------------------------------------------

CATMAT_DIR <- "data/catmat"
ATUALIZACAO_DIR <- "tasks/atualiza-catmat/outputs"


# :: VERSIONAMENTO -------------------------------------------------------------

get_current_version <- function(CATMAT_DIR) {

  CATMAT_DIR <- here(CATMAT_DIR)

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

OLD_DIR <- here(CATMAT_DIR, "OLD", OLD_VERSION)

OLD_FILE_OCDS <- sprintf("tabela-mapeamento-ocds-%s.csv", OLD_VERSION)
OLD_FILE_CATALOGO <- sprintf("catmat-%s.rds", OLD_VERSION)

# cria diretório OLD
if (!dir.exists(OLD_DIR)) dir.create(OLD_DIR, recursive = TRUE)

# :: NEW PATHS -----------------------------------------------------------------

NEW_FILE_OCDS <- sprintf("tabela-mapeamento-ocds-%s.csv", NEW_VERSION)
NEW_FILE_CATALOGO <- sprintf("catmat-%s.rds", NEW_VERSION)


# :: MOVIMENTA ARQUIVOS ANTIGOS ------------------------------------------------

pivot_old <- tibble(
  from = c(
    here(CATMAT_DIR, OLD_FILE_OCDS),
    here(CATMAT_DIR, OLD_FILE_CATALOGO)
  ),
  to = c(
    here(OLD_DIR, OLD_FILE_OCDS),
    here(OLD_DIR, OLD_FILE_CATALOGO)
  )
)

# move arquivos antigos para o diretório OLD
pmap(pivot_old, file.copy)

# deleta arquivos antigos do diretório principal
unlink(pivot_old$from)


# :: MOVIMENTA ARQUIVOS NOVOS --------------------------------------------------

pivot_new <- tibble(
  from = c(
    here(ATUALIZACAO_DIR, "tabela-mapeamento-ocds.csv"),
    here(ATUALIZACAO_DIR, "catmat.rds")
  ),
  to = c(
    here(CATMAT_DIR, NEW_FILE_OCDS),
    here(CATMAT_DIR, NEW_FILE_CATALOGO)
  )
)

# move arquivos novos para o diretório CATMAT
pmap(pivot_new, file.copy)

# deleta arquivos novos do diretório de atualização
unlink(pivot_new$from)

readRDS(here(CATMAT_DIR, NEW_FILE_CATALOGO))
