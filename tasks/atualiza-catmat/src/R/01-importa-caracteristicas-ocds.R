# :: CONTEXTO ------------------------------------------------------------------

#' O arquivo `caracteristicas-catmat.csv` foi enviado para o repositório `Transparencia-Brasil/medicine-extension-ocds`
#' Lá ele é utilizado para mapear as características dos medicamentos do Catmat com os campos do OCDS (Open Contracting Data Standard).
#' O resultado desse processamento está no arquivo `documento-ocds.json` (INPUT_PATH),
#' que é lido e processado neste script para gerar o arquivo `tabela-mapeamento-ocds.csv` (OUTPUT_PATH).
#'
#' O mesmo repositório gera o dicionário OCDS de medicamentos (`dicionario-ocds.csv`), consumido pelo
#' mapeamento PNCP -> OCDS (`tasks/mapeamento-ocds`). Ele é baixado no mesmo commit, validado contra o
#' catálogo atualizado e salvo em `DICIONARIO_OUTPUT_PATH`, para ser versionado por `03-versionamento.R`.
#'
#' O commit usado fica registrado em `PROVENIENCIA_OUTPUT_PATH`. Por padrão, usa a `main`; para fixar outra
#' referência (branch, tag ou SHA), defina `MEDICINE_EXTENSION_REF` no ambiente ou no `.env`.


library(tidyverse)
library(here)
library(jsonlite)
library(httr2)


# :: FILE PATHS ----------------------------------------------------------------

MEDICINE_EXTENSION_REF <- Sys.getenv("MEDICINE_EXTENSION_REF", "main")

OUTPUT_PATH <- here("tasks/atualiza-catmat/outputs/tabela-mapeamento-ocds.csv")
DICIONARIO_OUTPUT_PATH <- here("tasks/atualiza-catmat/outputs/dicionario-medicamentos-ocds.csv")
PROVENIENCIA_OUTPUT_PATH <- here("tasks/atualiza-catmat/outputs/proveniencia-ocds.csv")

# catálogo atualizado gerado por `00-coleta-catmat-com-cnbsr.R`
CATALOGO_ATUALIZADO_PATH <- here("tasks/atualiza-catmat/outputs/catmat.rds")

UTILS_PATH <- here("tasks/atualiza-catmat/src/R/utils.R")


# :: MAIN ----------------------------------------------------------------------

source(UTILS_PATH)
carrega_env()

MEDICINE_EXTENSION_COMMIT <- resolve_commit_medicine_extension(MEDICINE_EXTENSION_REF)
message(
  "medicine-extension-ocds: ref '", MEDICINE_EXTENSION_REF,
  "' -> commit ", MEDICINE_EXTENSION_COMMIT
)

# Parse the OCDS JSON data
ocds_json <- baixa_arquivo_medicine_extension(
  MEDICINE_EXTENSION_DOCUMENTO_OCDS,
  MEDICINE_EXTENSION_COMMIT
) |>
  (\(conteudo) {
    texto <- rawToChar(conteudo)
    Encoding(texto) <- "UTF-8"
    texto
  })() |>
  fromJSON()

# Dicionário OCDS de medicamentos (mapeamento PNCP -> OCDS), no mesmo commit
baixa_arquivo_medicine_extension(
  MEDICINE_EXTENSION_DICIONARIO_OCDS,
  MEDICINE_EXTENSION_COMMIT,
  destino = DICIONARIO_OUTPUT_PATH
)

valida_dicionario_ocds(
  DICIONARIO_OUTPUT_PATH,
  readRDS(CATALOGO_ATUALIZADO_PATH)$codigo_br
)

# Proveniência dos arquivos gerados, consumida por `03-versionamento.R`
tibble(
  arquivo = c("tabela-mapeamento-ocds.csv", "dicionario-medicamentos-ocds.csv"),
  origem_repo = MEDICINE_EXTENSION_REPO,
  origem_caminho = c(MEDICINE_EXTENSION_DOCUMENTO_OCDS, MEDICINE_EXTENSION_DICIONARIO_OCDS),
  origem_commit = MEDICINE_EXTENSION_COMMIT
) |>
  write_csv(PROVENIENCIA_OUTPUT_PATH)


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
