# :: CONTEXTO ------------------------------------------------------------------

#' O arquivo `caracteristicas-catmat.csv` foi enviado para o repositório `Transparencia-Brasil/medicine-extension-ocds`
#' Lá ele é utilizado para mapear as características dos medicamentos do Catmat com os campos do OCDS (Open Contracting Data Standard).
#' O resultado desse processamento está no arquivo `documento-ocds.json` (INPUT_PATH),
#' que é lido e processado neste script para gerar o arquivo `tabela-mapeamento-ocds.csv` (OUTPUT_PATH).


library(tidyverse)
library(here)
library(jsonlite)
library(dotenv)
library(httr2)
load_dot_env()


# :: FILE PATHS ----------------------------------------------------------------

GITHUB_TOKEN <- Sys.getenv("GITHUB_TOKEN_READ_FILES")
REPO <- "medicine-extension-ocds"

# `documento-ocds.json` resultante do processamento do arquivo `caracteristicas-catmat.csv`
INPUT_PATH <- str_glue(
  "https://api.github.com/repos/Transparencia-Brasil/{REPO}/",
  "contents/tasks/documento-ocds/outputs/documento-ocds.json",
  "?ref=main"
)

OUTPUT_PATH <- here("tasks/atualiza-catmat/outputs/tabela-mapeamento-ocds.csv")

UTILS_PATH <- here("tasks/atualiza-catmat/src/R/utils.R")


# :: MAIN ----------------------------------------------------------------------

source(UTILS_PATH)

# Parse the OCDS JSON data
ocds_json <- request(INPUT_PATH) |>
  req_headers(
    Authorization = paste("Bearer", GITHUB_TOKEN),
    Accept = "application/vnd.github.raw+json",
    `X-GitHub-Api-Version` = "2022-11-28"
  ) |>
  req_perform() |>
  resp_body_string() |>
  fromJSON()


# Tidy the OCDS JSON data and extract relevant information
ocds <- tidy_ocds_json(ocds_json) |>
  mutate(immediateContainer = pluck(immediateContainer, "name")) |>
  mutate(
    strength = map_chr(activeIngredients, extrai_strength),
    activeIngredients = map_chr(activeIngredients, extrai_activeIngredients)
  ) |>
  select(-attributes)


# Create the final data frame with the relevant information and write it to a CSV file
caracteristicas_ocds <- ocds |>
  mutate(
    across(
      c(dosageForm, administrationRoute, immediateContainer, activeIngredients, strength),
      \(x) replace_na(x, "")
    ),
    caracteristicas_ocds = pmap(
      list(dosageForm, administrationRoute, immediateContainer, activeIngredients, strength),
      function(dosageForm, administrationRoute, immediateContainer, activeIngredients, strength) {
        list(
          list(nomeCaracteristica = "dosageForm", nomeValorCaracteristica = dosageForm),
          list(nomeCaracteristica = "administrationRoute", nomeValorCaracteristica = administrationRoute),
          list(nomeCaracteristica = "immediateContainer", nomeValorCaracteristica = immediateContainer),
          list(nomeCaracteristica = "activeIngredients", nomeValorCaracteristica = activeIngredients),
          list(nomeCaracteristica = "strengthValue", nomeValorCaracteristica = strength)
        )
      }
    )
  )


# Wrap the caracteristicas_ocds column in a list column and convert it to JSON
caracteristicas_ocds <- caracteristicas_ocds |>
  mutate(
    caracteristicas_ocds = map(caracteristicas_ocds, discard, ~ .x$nomeValorCaracteristica == ""),
    caracteristicas_ocds = map(caracteristicas_ocds, toJSON, auto_unbox = TRUE)
  )

# Write the final data frame to a CSV file
caracteristicas_ocds |>
  select(codigo_item, caracteristicas_ocds) |>
  mutate(caracteristicas_ocds = as.character(caracteristicas_ocds)) |>
  write_csv(OUTPUT_PATH)
  # esse resultado deverá ser enviado para teste
