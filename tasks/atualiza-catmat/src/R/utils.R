  COLUNAS_CATALOGO <- c(
    "codigo_classe",
    "nome_classe",
    "codigo_pdm",
    "nome_pdm",
    "codigo_br",
    "nome_item",
    "item_suspenso",
    "item_ativo",
    "item_sustentavel",
    "buscaItemCaracteristica",
    "unidadeFornecimento",
    "caracteristicas_ocds"
  )

# :: FUNCTIONS -----------------------------------------------------------------


#' Adiciona as características OCDS aos itens do catálogo
#'
#' @param catalogo Dataframe do catálogo CATMAT.
#' @param mapeamento Dataframe validado com o mapeamento OCDS.
#'
#' @return Catálogo enriquecido por `codigo_br = codigo_item`.
adiciona_caracteristicas_ocds <- function(
  catalogo,
  mapeamento = le_mapeamento_caracteristicas_ocds()
) {
  if ("caracteristicas_ocds" %in% names(catalogo)) {
    catalogo$caracteristicas_ocds <- NULL
  }

  dplyr::left_join(
    catalogo,
    mapeamento,
    by = c("codigo_br" = "codigo_item")
  )
}

#' Tidy the OCDS JSON data
#'
#' @param ocds_json A list containing the OCDS JSON data
#' @return A tidy data frame containing the relevant information from the OCDS JSON data
#'
tidy_ocds_json <- function(ocds_json) {
  ocds <- ocds_json |>
    enframe() |>
    pivot_wider() |>
    select(releases) |>
    unnest(releases) |>
    select(tender) |>
    unnest(tender) |>
    select(items) |>
    unnest(items)

  ocds <- ocds |>
    unnest_wider(classification, names_sep = "_") |>
    select(
      id_item = id,
      description = description,
      codigo_item = classification_id,
      dosageForm = dosageForm,
      administrationRoute = administrationRoute,
      activeIngredients = activeIngredients,
      attributes = attributes,
      immediateContainer = immediateContainer
    )
  ocds
}

#' Extrai a força do medicamento a partir dos ingredientes ativos
#'
#' @param active_ingredients Um data frame contendo os ingredientes ativos do medicamento
#' @return Uma string contendo a força do medicamento, ou NA se não houver força disponível
#'
extrai_strength <- function(active_ingredients) {
  if (!"strength" %in% names(active_ingredients)) return(NA_character_)

  strength <- active_ingredients |>
    select(strength) |>
    unnest(strength, keep_empty = TRUE)

  if (!"value" %in% names(strength)) return(NA_character_)

  if ("unit" %in% names(strength)) {
    strength <- strength |>
      unnest(unit, keep_empty = TRUE)
  } else {
    strength <- strength |>
      mutate(id = NA_character_)
  }

  if (!"id" %in% names(strength)) {
    strength <- strength |>
      mutate(id = NA_character_)
  }

  strength <- strength |>
    filter(!is.na(value)) |>
    mutate(
      value = as.character(value),
      id = replace_na(as.character(id), ""),
      strength = str_squish(paste(value, id))
    ) |>
    pull(strength)

  if (length(strength) == 0) {
    return(NA_character_)
  }

  paste(strength, collapse = " + ")
}

#' Extrai os nomes dos ingredientes ativos a partir do data frame de ingredientes ativos
#'
#' @param active_ingredients Um data frame contendo os ingredientes ativos do medicamento
#' @return Uma string contendo os nomes dos ingredientes ativos, ou NA se não houver nomes
#'
extrai_activeIngredients <- function(active_ingredients) {
  if (!"name" %in% names(active_ingredients)) return(NA_character_)

  active_ingredients_name <- active_ingredients |>
    filter(!is.na(name)) |>
    pull(name)

  if (length(active_ingredients_name) == 0) return(NA_character_)

  active_ingredients_name_main <- active_ingredients_name[[1]]
  active_ingredients_name_associated <- setdiff(active_ingredients_name, active_ingredients_name_main)

  active_ingredients_name <- paste(
    active_ingredients_name_main,
    paste(active_ingredients_name_associated, collapse = ", "),
    sep = "; "
  )

  str_replace(active_ingredients_name, "; $", "")
}



#' Lê e valida o mapeamento de características OCDS do catálogo
#'
#' @param caminho Caminho do CSV versionado com o mapeamento OCDS.
#'
#' @return Dataframe com `codigo_item` e `caracteristicas_ocds`.
le_mapeamento_caracteristicas_ocds <- function(
  caminho = here::here(
    "tasks/atualiza-catmat/outputs",
    "tabela-mapeamento-ocds.csv"
  )
) {
  colunas_esperadas <- c("codigo_item", "caracteristicas_ocds")

  mapeamento <- readr::read_csv(
    caminho,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE,
    progress = FALSE
  )

  colunas_ausentes <- setdiff(colunas_esperadas, names(mapeamento))
  if (length(colunas_ausentes) > 0) {
    stop(sprintf(
      "O mapeamento OCDS não contém as colunas obrigatórias: %s.",
      paste(colunas_ausentes, collapse = ", ")
    ))
  }

  mapeamento <- mapeamento[, colunas_esperadas, drop = FALSE]
  mapeamento$codigo_item <- trimws(mapeamento$codigo_item)
  mapeamento$caracteristicas_ocds <- trimws(mapeamento$caracteristicas_ocds)
  valores_vazios <- !is.na(mapeamento$caracteristicas_ocds) &
    mapeamento$caracteristicas_ocds == ""
  mapeamento$caracteristicas_ocds[valores_vazios] <- NA_character_

  if (any(is.na(mapeamento$codigo_item) | mapeamento$codigo_item == "")) {
    stop("O mapeamento OCDS contém codigo_item ausente ou vazio.")
  }

  codigos_duplicados <- unique(
    mapeamento$codigo_item[duplicated(mapeamento$codigo_item)]
  )
  if (length(codigos_duplicados) > 0) {
    stop(sprintf(
      "O mapeamento OCDS contém codigo_item duplicado: %s.",
      paste(utils::head(codigos_duplicados, 10), collapse = ", ")
    ))
  }

  preenchidos <- !is.na(mapeamento$caracteristicas_ocds)
  json_valido <- vapply(
    mapeamento$caracteristicas_ocds[preenchidos],
    jsonlite::validate,
    logical(1)
  )
  if (any(!json_valido)) {
    codigos_invalidos <- mapeamento$codigo_item[preenchidos][!json_valido]
    stop(sprintf(
      "O mapeamento OCDS contém JSON inválido para codigo_item: %s.",
      paste(utils::head(codigos_invalidos, 10), collapse = ", ")
    ))
  }

  mapeamento
}
