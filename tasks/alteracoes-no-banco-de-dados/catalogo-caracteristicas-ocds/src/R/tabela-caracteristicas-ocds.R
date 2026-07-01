library(tidyverse)
library(here)
library(jsonlite)
library(dotenv)
load_dot_env()


# :: FILE PATHS ----------------------------------------------------------------

GITHUB_TOKEN <- Sys.getenv("GITHUB_TOKEN")

REMOTE_DOCUMENT_JSON_URL <- "https://raw.githubusercontent.com/Transparencia-Brasil/medicine-extension-ocds/refs/heads/main/tasks/documento-ocds/outputs/documento-ocds.json?token="

INPUT_PATH <- paste0(REMOTE_DOCUMENT_JSON_URL, GITHUB_TOKEN)

OUTPUT_PATH <- here("tasks/alteracoes-no-banco-de-dados/catalogo-caracteristicas-ocds/outputs/tabela-mapeamento-ocds.csv")

UTILS_PATH <- here("tasks/alteracoes-no-banco-de-dados/catalogo-caracteristicas-ocds/src/R/utils.R")

# :: MAIN ----------------------------------------------------------------------

source(UTILS_PATH)

# Parse the OCDS JSON data
ocds_json <- fromJSON(INPUT_PATH)

# Tidy the OCDS JSON data and extract relevant information
ocds <- tidy_ocds_json(ocds_json) |>
  mutate(
    strength = map_chr(activeIngredients, extrai_strength),
    activeIngredients = map_chr(activeIngredients, extrai_activeIngredients),
    immediateContainer = map_chr(immediateContainer, extrai_immediateContainer)
  ) |>
  select(-attributes)

# Create the final data frame with the relevant information and write it to a CSV file
caracteristicas_ocds <- ocds |>
  mutate(
    across(
      c(dosageForm, administrationRoute, immediateContainer, activeIngredients, strength),
      function(x) replace_na(x, "")
    ),
    caracteristicas_ocds = pmap(
      list(dosageForm, administrationRoute, immediateContainer, activeIngredients, strength),
      function(dosageForm, administrationRoute, immediateContainer, activeIngredients, strength) {
        list(
          list(nomeCaracteristica = "dosageForm", nomeValorCaracteristica = dosageForm),
          list(nomeCaracteristica = "administrationRoute", nomeValorCaracteristica = administrationRoute),
          list(nomeCaracteristica = "immediateContainer", nomeValorCaracteristica = immediateContainer),
          list(nomeCaracteristica = "activeIngredients", nomeValorCaracteristica = activeIngredients),
          list(nomeCaracteristica = "strength", nomeValorCaracteristica = strength)
        )
      }
    )
  )

# Wrap the caracteristicas_ocds column in a list column and convert it to JSON
caracteristicas_ocds <- caracteristicas_ocds |>
  mutate(
    caracteristicas_ocds = map(caracteristicas_ocds, discard, ~ .x$nomeValorCaracteristica == ""),
    caracteristicas_ocds = map(caracteristicas_ocds, toJSON)
  )

# Write the final data frame to a CSV file
caracteristicas_ocds |>
  select(codigo_item, caracteristicas_ocds) |>
  mutate(caracteristicas_ocds = as.character(caracteristicas_ocds)) |>
  write_csv(OUTPUT_PATH)
