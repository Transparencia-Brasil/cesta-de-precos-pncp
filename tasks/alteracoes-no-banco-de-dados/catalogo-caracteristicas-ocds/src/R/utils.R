
# :: FUNCTIONS -----------------------------------------------------------------

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
