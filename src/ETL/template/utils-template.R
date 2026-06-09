#' Utilitarios para carregar templates versionados dos coletores PNCP.

carrega_template_coleta <- function(alias, templates_dir = here::here("src/ETL/template/templates")) {
  templates <- list(
    contratacoes = "template-contratacoes.csv",
    itens = "template-itens.csv",
    resultados_itens = "template-resultados-itens.csv",
    resultados = "template-resultados-itens.csv"
  )

  alias_normalizado <- gsub("-", "_", tolower(alias))
  if (!alias_normalizado %in% names(templates)) {
    stop("Template desconhecido: ", alias)
  }

  path_template <- file.path(templates_dir, templates[[alias_normalizado]])
  if (!file.exists(path_template)) {
    stop("Arquivo de template nao encontrado: ", path_template)
  }

  metadados <- readr::read_csv(
    path_template,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE
  )

  colunas_obrigatorias <- c("coluna_template", "usar_no_template", "ordem_template")
  colunas_faltantes <- setdiff(colunas_obrigatorias, names(metadados))
  if (length(colunas_faltantes) > 0) {
    stop(
      "Template sem colunas obrigatorias: ",
      paste(colunas_faltantes, collapse = ", ")
    )
  }

  usar_no_template <- toupper(metadados$usar_no_template) %in% c("TRUE", "T", "1", "S", "SIM", "YES")
  ordem_template <- suppressWarnings(as.integer(metadados$ordem_template))
  manter <- usar_no_template &
    !is.na(metadados$coluna_template) &
    metadados$coluna_template != ""

  metadados <- metadados[manter, ]
  ordem_template <- ordem_template[manter]

  metadados <- metadados[order(ordem_template, metadados$coluna_template), ]
  colunas_template <- unique(metadados$coluna_template)

  tibble::as_tibble(stats::setNames(
    rep(list(character()), length(colunas_template)),
    colunas_template
  ))
}
