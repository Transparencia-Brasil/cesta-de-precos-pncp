# LIBRARIES --------------------------------------------------------------------
library(here)
library(tidyverse)


# INPUTS -----------------------------------------------------------------------
PATH_ITEM_HOMOLOGADO <- here("tasks/verifica-descontos/outputs/item_homologado.csv")
PATH_ITEM_LICITADO <- here("tasks/verifica-descontos/outputs/item_licitado.csv")


# UTILS ------------------------------------------------------------------------

#' Parse a character vector into boolean values (TRUE/FALSE/NA).
#' @param x Character vector to parse.
#' @param coluna Name of the column being parsed (for error messages).
#' @return A logical vector (TRUE/FALSE/NA).
parse_booleano <- function(x, coluna) {

  # normaliza valores para comparação
  x_norm <- str_squish(x) |> str_to_lower()

  # define valid boolean values
  valores_verdadeiros <- c("true", "t", "1", "sim", "s", "yes", "y", "verdadeiro", "v")
  valores_falsos <- c("false", "f", "0", "nao", "não", "n", "no", "falso")

  # define invalid values
  valores <- c(valores_verdadeiros, valores_falsos)
  valores_invalidos <- unique(x[!(is.na(x_norm) | x_norm %in% valores)])

  # stop if there are invalid values
  if (length(valores_invalidos) > 0) {
    val_inv <- paste(sprintf("'%s'", valores_invalidos), collapse = ", ")
    msg <- sprintf("Valores booleanos inválidos na coluna '%s': %s", coluna, val_inv)
    stop(msg, call. = FALSE)
  }

  # atribui TRUE/FALSE/NA based on normalized values
  case_when(
    is.na(x_norm) ~ NA,
    x_norm %in% valores_verdadeiros ~ TRUE,
    x_norm %in% valores_falsos ~ FALSE
  )
}

#' Read a CSV file defensively, checking for expected columns and parsing boolean columns.
#' @param caminho Path to the CSV file.
#' @param tipos Column types for readr::read_csv.
#' @param colunas_esperadas Expected column names.
#' @param colunas_booleanas Columns that should be parsed as boolean.
#' @return A tibble with the data from the CSV file.
ler_csv_defensivo <- function(caminho, tipos, colunas_esperadas, colunas_booleanas) {
  # read the CSV file
  dados <- read_csv(
    caminho,
    col_types = tipos,
    na = c("", "NA", "N/A", "NULL", "null"),
    trim_ws = TRUE,
    name_repair = "check_unique",
    show_col_types = FALSE,
    progress = FALSE
  )

  # check for expected columns
  colunas_ausentes <- setdiff(colunas_esperadas, names(dados))
  colunas_extras <- setdiff(names(dados), colunas_esperadas)

  # stop if there are missing or extra columns
  if (length(colunas_ausentes) > 0 || length(colunas_extras) > 0) {
    detalhes <- c(
      if (length(colunas_ausentes) > 0) paste0("Ausentes: ", paste(colunas_ausentes, collapse = ", "), "."),
      if (length(colunas_extras) > 0) paste0("Extras: ", paste(colunas_extras, collapse = ", "), ".")
    )

    stop(
      paste("Schema inesperado em", shQuote(caminho), paste(detalhes, collapse = " ")),
      call. = FALSE
    )
  }

  # check for parsing problems
  problemas_leitura <- problems(dados)

  # stop if there are parsing problems
  if (nrow(problemas_leitura) > 0) {
    primeiro_problema <- problemas_leitura[1, ]
    stop(
      sprintf(
        "Falha ao ler '%s' (linha %s, coluna %s): esperado %s; encontrado '%s'.",
        caminho,
        primeiro_problema$row,
        primeiro_problema$col,
        primeiro_problema$expected,
        primeiro_problema$actual
      ),
      call. = FALSE
    )
  }

  # parse boolean columns
  dados |>
    mutate(across(all_of(colunas_booleanas), ~ parse_booleano(.x, cur_column())))
}


# COLUNAS ESPERADAS ------------------------------------------------------------

COLUNAS_ITEM_HOMOLOGADO <- c(
  "numero_controle_pncp",
  "numero_item",
  "aplicacao_beneficio_me_epp",
  "aplicacao_margem_preferencia",
  "amparo_legal_margem_preferencia_id",
  "amparo_legal_margem_preferencia_nome",
  "amparo_legal_margem_preferencia_descricao",
  "aplicacao_criterio_desempate",
  "amparo_legal_criterio_desempate_id",
  "amparo_legal_criterio_desempate_nome",
  "amparo_legal_criterio_desempate_descricao",
  "percentual_desconto"
)

COLUNAS_BOOLEANAS_ITEM_HOMOLOGADO <- c(
  "aplicacao_beneficio_me_epp",
  "aplicacao_margem_preferencia",
  "aplicacao_criterio_desempate"
)

COLUNAS_ITEM_LICITADO <- c(
  "numero_controle_pncp",
  "numero_item",
  "incentivo_produtivo_basico",
  "exigencia_conteudo_nacional",
  "aplicabilidade_margem_preferencia_normal",
  "aplicabilidade_margem_preferencia_adicional",
  "percentual_margem_preferencia_normal",
  "percentual_margem_preferencia_adicional",
  "tipo_margem_preferencia_codigo",
  "tipo_margem_preferencia_nome",
  "n"
)

COLUNAS_BOOLEANAS_ITEM_LICITADO <- c(
  "incentivo_produtivo_basico",
  "exigencia_conteudo_nacional",
  "aplicabilidade_margem_preferencia_normal",
  "aplicabilidade_margem_preferencia_adicional"
)

# CARREGAR DADOS ---------------------------------------------------------------

item_homologado <- ler_csv_defensivo(
  PATH_ITEM_HOMOLOGADO,
  tipos = cols(
    .default = col_character(),
    numero_controle_pncp = col_character(),
    numero_item = col_integer(),
    aplicacao_beneficio_me_epp = col_character(),
    aplicacao_margem_preferencia = col_character(),
    amparo_legal_margem_preferencia_id = col_integer(),
    amparo_legal_margem_preferencia_nome = col_character(),
    amparo_legal_margem_preferencia_descricao = col_character(),
    aplicacao_criterio_desempate = col_character(),
    amparo_legal_criterio_desempate_id = col_integer(),
    amparo_legal_criterio_desempate_nome = col_character(),
    amparo_legal_criterio_desempate_descricao = col_character(),
    percentual_desconto = col_double()
  ),
  colunas_esperadas = COLUNAS_ITEM_HOMOLOGADO,
  colunas_booleanas = COLUNAS_BOOLEANAS_ITEM_HOMOLOGADO
)

item_licitado <- ler_csv_defensivo(
  PATH_ITEM_LICITADO,
  tipos = cols(
    .default = col_character(),
    numero_controle_pncp = col_character(),
    numero_item = col_integer(),
    incentivo_produtivo_basico = col_character(),
    exigencia_conteudo_nacional = col_character(),
    aplicabilidade_margem_preferencia_normal = col_character(),
    aplicabilidade_margem_preferencia_adicional = col_character(),
    percentual_margem_preferencia_normal = col_double(),
    percentual_margem_preferencia_adicional = col_double(),
    tipo_margem_preferencia_codigo = col_integer(),
    tipo_margem_preferencia_nome = col_character(),
    n = col_integer()
  ),
  colunas_esperadas = COLUNAS_ITEM_LICITADO,
  colunas_booleanas = COLUNAS_BOOLEANAS_ITEM_LICITADO
)


# JOIN -------------------------------------------------------------------------
descontos <- item_homologado |>
  full_join(
    item_licitado,
    by = c("numero_controle_pncp", "numero_item")
  ) |>
  select(
    # ID's--------------------------------------
    numero_controle_pncp,
    numero_item,
    # BENEFÍCIO ME/EPP -------------------------
    # "codigo_tipo_beneficio"
    # "nome_tipo_beneficio"
    aplicacao_beneficio_me_epp, #boolean
    incentivo_produtivo_basico, #boolean
    exigencia_conteudo_nacional, #boolean
    # MARGEM DE PREFERÊNCIA --------------------
    aplicabilidade_margem_preferencia_normal, #boolean
    aplicabilidade_margem_preferencia_adicional, #boolean
    tipo_margem_preferencia_codigo, #integer
    tipo_margem_preferencia_nome, #string
    percentual_margem_preferencia_normal, #double
    percentual_margem_preferencia_adicional, #double
    aplicacao_margem_preferencia, #boolean
    amparo_legal_margem_preferencia_id, #integer
    amparo_legal_margem_preferencia_nome, #string
    amparo_legal_margem_preferencia_descricao, #string
    # CRITÉRIO DE DESEMPATE ---------------------
    # aplicacao_criterio_desempate, #boolean
    # amparo_legal_criterio_desempate_id, #integer
    # amparo_legal_criterio_desempate_nome, #string
    # amparo_legal_criterio_desempate_descricao, #string
    # DESCONTO ----------------------------------
    percentual_desconto #double
  )

# exporta exemplo para definir exibição no front
descontos |>
  filter(
    if_any(-c(numero_controle_pncp, numero_item), ~ !is.na(.))
  ) |>
  filter(!is.na(tipo_margem_preferencia_codigo)) |>
  googlesheets4::write_sheet(
    ss = "https://docs.google.com/spreadsheets/d/1iLyuwjUpE-ruMUSL-X8LvaLkHekf_B3m619XZnCly4M",
    sheet = "descontos"
  )

OUTPUT <- here("tasks/alteracoes-no-banco-de-dados/descontos/src/inputs/descontos.csv")
write_csv(descontos, OUTPUT, na = "")
unlink(PATH_ITEM_HOMOLOGADO)
unlink(PATH_ITEM_LICITADO)
