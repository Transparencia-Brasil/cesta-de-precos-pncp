library(tidyverse)
library(here)

options(width = 150)

# :: FILEPATHS E SETUP ---------------------------------------------------------

TMP_PATH <- Sys.getenv(
  "PNCP_DATA_ROOT",
  unset = "tasks/indicadores-MEL/tmp"
)

INPUT_PATH <- "tasks/indicadores-MEL/inputs"
TMP_PATH_ABS <- if_else(
  str_detect(TMP_PATH, "^([A-Za-z]:|/)"),
  TMP_PATH,
  here(TMP_PATH)
)

dir.create(here(INPUT_PATH), recursive = TRUE, showWarnings = FALSE)


# :: COLUNAS PNCP --------------------------------------------------------------

COLUNAS_CHAVE_ITENS <- c(
  "numeroItem",
  "endpoint"
)

COLUNAS_CHAVE_RESULTADOS <- c(
  "numeroControlePNCPCompra",
  "numeroItem",
  "endpoint",
  "sequencialResultado"
)

COLUNAS_CHAVE_CONTRATACOES <- c(
  "data.numeroControlePNCP"
)

COLUNAS_PNCP_ITENS <- c(
  "tipoBeneficio",
  "tipoBeneficioNome",
  "incentivoProdutivoBasico",
  "aplicabilidadeMargemPreferenciaNormal",
  "percentualMargemPreferenciaNormal",
  "aplicabilidadeMargemPreferenciaAdicional",
  "percentualMargemPreferenciaAdicional",
  "tipoMargemPreferencia.codigo",
  "tipoMargemPreferencia.nome",
  "exigenciaConteudoNacional",
  "materialOuServicoNome"
)

COLUNAS_PNCP_RESULTADOS <- c(
  "aplicacaoBeneficioMeEpp",
  "amparoLegalMargemPreferencia",
  "amparoLegalMargemPreferencia.id",
  "amparoLegalMargemPreferencia.nome",
  "amparoLegalMargemPreferencia.descricao",
  "amparoLegalMargemPreferencia.statusAtivo"
)

COLUNAS_PNCP_CONTRATACOES <- c(
  "data.usuarioNome",
  "data.materialOuServico"
)


# :: FUNCOES AUXILIARES --------------------------------------------------------

make_id_pncp <- function(endpoint) {
  endpoint <- str_replace_all(endpoint, "\\\\", "/")

  cnpj <- str_match(endpoint, "orgaos/([^/]+)/compras/")[, 2]
  ano <- str_match(endpoint, "compras/(\\d{4})/")[, 2]
  sequencial <- str_match(endpoint, "compras/\\d{4}/([^/]+)")[, 2] |>
    str_pad(width = 6, pad = "0")

  if_else(
    is.na(cnpj) | is.na(ano) | is.na(sequencial),
    NA_character_,
    str_glue("{cnpj}-1-{sequencial}/{ano}")
  )
}

make_anomes_coleta_pncp <- function(path) {
  path <- str_replace_all(path, "\\\\", "/")

  anomes_hifen <- str_extract(path, "202[0-9]-\\d{2}")
  anomes_barra <- str_extract(path, "202[0-9]/\\d{1,2}")

  case_when(
    !is.na(anomes_hifen) ~ ym(anomes_hifen),
    !is.na(anomes_barra) ~ ym(str_replace(anomes_barra, "/", "-")),
    .default = as.Date(NA)
  )
}

make_id_coleta_pncp <- function(path) {
  path <- str_replace_all(path, "\\\\", "/")

  id_tmp <- str_match(path, "(Coletas - 202[0-9]/[^/]+/[^/]+)")[, 2]
  id_coleta <- str_match(path, "(202[0-9]-\\d{2}/[^/]+)")[, 2]
  id_datapackage <- str_match(path, "(202[0-9]/[^/]+/[^/]+)/(DATA|LOG)")[, 2]

  coalesce(id_tmp, id_coleta, id_datapackage, dirname(path))
}

ensure_cols <- function(dados, colunas) {
  faltantes <- setdiff(colunas, names(dados))

  if (length(faltantes) > 0) {
    dados[faltantes] <- NA_character_
  }

  dados
}

empty_pncp_tbl <- function(colunas, colunas_data = character()) {
  dados <- set_names(
    rep(list(character()), length(colunas)),
    colunas
  ) |>
    as_tibble()

  for (coluna in colunas_data) {
    dados[[coluna]] <- as.Date(dados[[coluna]])
  }

  dados
}

empty_itens_pncp <- function() {
  empty_pncp_tbl(
    c(
      "path_itens",
      "anomes_coleta",
      "id_coleta",
      "numeroControlePNCP",
      COLUNAS_CHAVE_ITENS,
      COLUNAS_PNCP_ITENS
    ),
    colunas_data = "anomes_coleta"
  )
}

empty_resultados_pncp <- function() {
  empty_pncp_tbl(
    c(
      "path_resultados",
      "anomes_coleta",
      "id_coleta",
      "numeroControlePNCP",
      COLUNAS_CHAVE_RESULTADOS,
      COLUNAS_PNCP_RESULTADOS
    ),
    colunas_data = "anomes_coleta"
  )
}

empty_contratacoes_pncp <- function() {
  empty_pncp_tbl(
    c(
      "path_contratacoes",
      "anomes_coleta",
      "id_coleta",
      "numeroControlePNCP",
      COLUNAS_CHAVE_CONTRATACOES,
      COLUNAS_PNCP_CONTRATACOES
    ),
    colunas_data = "anomes_coleta"
  )
}

read_pncp_csv <- function(path, colunas) {
  message("Lendo: ", path)

  read_csv(
    file = path,
    col_types = cols(.default = "c"),
    col_select = any_of(colunas),
    show_col_types = FALSE
  ) |>
    ensure_cols(colunas)
}

classifica_arquivo_pncp <- function(path) {
  path_normalizado <- str_replace_all(path, "\\\\", "/")
  arquivo <- basename(path_normalizado)

  case_when(
    arquivo == "contratacoes.csv" ~ "contratacoes",
    arquivo == "dados.csv" & str_detect(path_normalizado, "/contratacoes/") ~ "contratacoes",
    arquivo == "itens.csv" ~ "itens",
    arquivo == "dados.csv" & str_detect(path_normalizado, "/itens/") ~ "itens",
    str_detect(arquivo, "^itens-.*resultados.*\\.csv$") ~ "resultados",
    arquivo == "itens-resultados.csv" ~ "resultados",
    arquivo == "dados.csv" & str_detect(path_normalizado, "/resultados/") ~ "resultados",
    .default = "outros"
  )
}

carrega_itens_pncp <- function(path) {
  read_pncp_csv(path, c(COLUNAS_CHAVE_ITENS, COLUNAS_PNCP_ITENS)) |>
    mutate(
      path_itens = path,
      anomes_coleta = make_anomes_coleta_pncp(path),
      id_coleta = make_id_coleta_pncp(path),
      numeroControlePNCP = make_id_pncp(endpoint)
    ) |>
    select(
      path_itens,
      anomes_coleta,
      id_coleta,
      numeroControlePNCP,
      all_of(COLUNAS_CHAVE_ITENS),
      all_of(COLUNAS_PNCP_ITENS)
    )
}

carrega_contratacoes_pncp <- function(path) {
  read_pncp_csv(path, c(COLUNAS_CHAVE_CONTRATACOES, COLUNAS_PNCP_CONTRATACOES)) |>
    mutate(
      path_contratacoes = path,
      anomes_coleta = make_anomes_coleta_pncp(path),
      id_coleta = make_id_coleta_pncp(path),
      numeroControlePNCP = .data[["data.numeroControlePNCP"]]
    ) |>
    select(
      path_contratacoes,
      anomes_coleta,
      id_coleta,
      numeroControlePNCP,
      all_of(COLUNAS_CHAVE_CONTRATACOES),
      all_of(COLUNAS_PNCP_CONTRATACOES)
    )
}

carrega_resultados_pncp <- function(path) {
  read_pncp_csv(path, c(COLUNAS_CHAVE_RESULTADOS, COLUNAS_PNCP_RESULTADOS)) |>
    mutate(
      path_resultados = path,
      anomes_coleta = make_anomes_coleta_pncp(path),
      id_coleta = make_id_coleta_pncp(path),
      numeroControlePNCP = coalesce(
        numeroControlePNCPCompra,
        make_id_pncp(endpoint)
      )
    ) |>
    select(
      path_resultados,
      anomes_coleta,
      id_coleta,
      numeroControlePNCP,
      all_of(COLUNAS_CHAVE_RESULTADOS),
      all_of(COLUNAS_PNCP_RESULTADOS)
    )
}

carrega_arquivos_pncp <- function(paths, leitor, empty_tbl) {
  if (length(paths) == 0) {
    return(empty_tbl)
  }

  map_dfr(paths, leitor)
}


# :: DATA PATHS ----------------------------------------------------------------

DATA_PATHS <- TMP_PATH_ABS |>
  list.files(recursive = TRUE, full.names = TRUE, pattern = "\\.csv$") |>
  as_tibble_col("path") |>
  mutate(tipo = classifica_arquivo_pncp(path)) |>
  filter(tipo != "outros")


# :: LOAD DATA -----------------------------------------------------------------

itens_paths <- DATA_PATHS |>
  filter(tipo == "itens") |>
  pull(path)

resultados_paths <- DATA_PATHS |>
  filter(tipo == "resultados") |>
  pull(path)

contratacoes_paths <- DATA_PATHS |>
  filter(tipo == "contratacoes") |>
  pull(path)

itens_pncp <- carrega_arquivos_pncp(
  itens_paths,
  carrega_itens_pncp,
  empty_itens_pncp()
)

resultados_pncp <- carrega_arquivos_pncp(
  resultados_paths,
  carrega_resultados_pncp,
  empty_resultados_pncp()
)

contratacoes_pncp <- carrega_arquivos_pncp(
  contratacoes_paths,
  carrega_contratacoes_pncp,
  empty_contratacoes_pncp()
)

contratacoes_pncp_join <- contratacoes_pncp |>
  select(
    id_coleta,
    numeroControlePNCP,
    path_contratacoes,
    all_of(COLUNAS_PNCP_CONTRATACOES)
  ) |>
  distinct()

pncp_beneficios_margens <- itens_pncp |>
  left_join(
    resultados_pncp,
    by = c(
      "numeroControlePNCP",
      "numeroItem",
      "id_coleta"
    )
  ) |>
  left_join(
    contratacoes_pncp_join,
    by = c(
      "numeroControlePNCP",
      "id_coleta"
    )
  ) |>
  select(
    anomes_coleta = anomes_coleta.x,
    id_coleta,
    numeroControlePNCP,
    numeroItem,
    sequencialResultado,
    path_itens,
    path_resultados,
    path_contratacoes,
    endpoint_itens = endpoint.x,
    endpoint_resultados = endpoint.y,
    all_of(COLUNAS_PNCP_CONTRATACOES),
    all_of(COLUNAS_PNCP_ITENS),
    all_of(COLUNAS_PNCP_RESULTADOS)
  )


# :: SAVE ----------------------------------------------------------------------

saveRDS(
  itens_pncp,
  file = here(INPUT_PATH, "pncp_itens_beneficios_margens.rds")
)

saveRDS(
  resultados_pncp,
  file = here(INPUT_PATH, "pncp_resultados_beneficios_margens.rds")
)

saveRDS(
  contratacoes_pncp,
  file = here(INPUT_PATH, "pncp_contratacoes_beneficios_margens.rds")
)

saveRDS(
  pncp_beneficios_margens,
  file = here(INPUT_PATH, "pncp_beneficios_margens.rds")
)

message("Arquivos salvos em: ", here(INPUT_PATH))


chaves_material_contrata_brasil <- contratacoes_pncp |>
  filter(
    data.materialOuServico == "S",
    data.usuarioNome == "Contrata+Brasil"
  ) |>
  select(id_coleta, numeroControlePNCP) |>
  distinct()

itens_pncp_material_contrata_brasil <- itens_pncp |>
  semi_join(
    chaves_material_contrata_brasil,
    by = c("id_coleta", "numeroControlePNCP")
  )

resultados_pncp_material_contrata_brasil <- resultados_pncp |>
  semi_join(
    chaves_material_contrata_brasil,
    by = c("id_coleta", "numeroControlePNCP")
  )

contratacoes_pncp_material_contrata_brasil <- contratacoes_pncp |>
  semi_join(
    chaves_material_contrata_brasil,
    by = c("id_coleta", "numeroControlePNCP")
  )

itens_pncp_material_contrata_brasil |>
  glimpse()

resultados_pncp_material_contrata_brasil |>
  glimpse()

contratacoes_pncp_material_contrata_brasil |>
  glimpse()
