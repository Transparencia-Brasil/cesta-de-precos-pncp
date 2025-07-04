library(tidyverse)
library(here)

# FILEPATHS --------------------------------------------------------------------

PATH_CONTRATACOES_2025 <- list.files(
  path = here("coleta/contratacoes"),
  pattern = "dados.csv",
  recursive = TRUE,
  full.names = TRUE
)

PATH_CONTRATACOES_2025 <- PATH_CONTRATACOES_2025[!grepl("TESTE", PATH_CONTRATACOES_2025)]


# LINHA DO TEMPO DA COLETA -----------------------------------------------------

atual <- file.info(PATH_CONTRATACOES_2025) %>%
  rownames_to_column("file") %>%
  as_tibble() %>%
  transmute(
    file,
    coleta = str_remove(file, "^.+itens/"),
    coleta = str_remove(coleta, "\\/dados\\.csv$"),
    coleta = str_remove(coleta, ".Q.*[12]$"),
    data_coleta = ym(coleta),
    # aponta qual é o arquivo mais recente
    atual = data_coleta == max(data_coleta)
  )


# READ DATA --------------------------------------------------------------------

contratacoes_2025 <- map(PATH_CONTRATACOES_2025, read_csv, col_types = list(.default = col_character())) %>%
  set_names(PATH_CONTRATACOES_2025) %>%
  enframe(name = "file", value = "data") %>%
  left_join(atual)

contratacoes_2025 <- contratacoes_2025 %>%
  unnest(cols = c(data))


# GET USUARIOS -----------------------------------------------------------------

usuarios <- contratacoes_2025 %>%
  select(
    numeroControlePNCPCompra = data.numeroControlePNCP,
    usuarioNome = data.usuarioNome
  )

INPUT_PATH <- "tasks/verifica-campos-com-catalogo-e-ncm/input"
if (!dir.exists(INPUT_PATH)) dir.create(INPUT_PATH)

saveRDS(usuarios, here(INPUT_PATH, "usuarios.rds"))
