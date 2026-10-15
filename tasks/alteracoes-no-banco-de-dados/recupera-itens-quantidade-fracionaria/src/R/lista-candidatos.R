#' Lista os itens dos data-packages que a carga rejeitava.
#'
#' Até a correção do loader, uma linha era rejeitada pelo PostgreSQL quando:
#' - `quantidade` ou `quantidadeHomologada` era fracionária (colunas INTEGER);
#' - `ncmNbsCodigo` não era numérico (o PNCP já enviou o literal "false").
#'
#' Este script percorre todos os pacotes em `coleta/data-package/` e grava os
#' itens nessas condições em `outputs/candidatos.csv`. Não acessa o banco.
#'
#' A varredura lê os CSVs como texto, porque parte dos pacotes antigos não passa
#' na leitura tipada atual (`le_csv_pncp()`). A coluna `leitura_tipada` informa,
#' por pacote, se os 3 CSVs são legíveis pelo loader atual.
#'
#' Uso (na raiz do projeto):
#'   Rscript.exe tasks/alteracoes-no-banco-de-dados/recupera-itens-quantidade-fracionaria/src/R/lista-candidatos.R

suppressPackageStartupMessages(library(readr))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(purrr))
suppressPackageStartupMessages(library(here))

source(here("src/ETL/loaders/utils.R"))

DIR_TAREFA <- here("tasks/alteracoes-no-banco-de-dados/recupera-itens-quantidade-fracionaria")
SAIDA <- file.path(DIR_TAREFA, "outputs", "candidatos.csv")
DIR_PACOTES <- here("coleta/data-package")
ARQUIVOS_PACOTE <- c(
  contratacoes = "contratacoes.csv",
  medicamentos = "itens-medicamentos.csv",
  resultados = "itens-medicamentos-resultados.csv"
)


eh_fracionaria <- function(x) {
  valor <- suppressWarnings(as.numeric(x))
  !is.na(valor) & valor != trunc(valor)
}

# Mesma regra de normaliza_medicamentos_carga(): "30041012.0" é válido.
eh_ncm_invalido <- function(x) {
  valor <- normaliza_nulo_pncp(x)
  numero <- suppressWarnings(as.numeric(valor))
  !is.na(valor) & (is.na(numero) | numero != trunc(numero))
}

#' Ordena pacotes cronologicamente: ano, mês e dia inicial do intervalo
#' (QUINZENA-1 = 1, QUINZENA-2 = 16, DIAS-16-A-25 = 16, DIA-01-ATE-05 = 1).
ordena_pacotes <- function(pacotes) {
  partes <- strsplit(pacotes, "/", fixed = TRUE)
  ano <- as.integer(map_chr(partes, 1))
  mes <- as.integer(sub(" .*", "", map_chr(partes, 2)))
  intervalo <- map_chr(partes, 3)
  dia_dias <- suppressWarnings(as.integer(sub("^DIAS?-(\\d+).*", "\\1", intervalo)))
  inicio <- ifelse(
    grepl("^QUINZENA-2", intervalo), 16L,
    ifelse(grepl("^DIAS?-", intervalo), dia_dias, 1L)
  )
  pacotes[order(ano, mes, inicio)]
}

le_csv_texto <- function(caminho) {
  readr::read_csv(
    caminho,
    col_types = readr::cols(.default = readr::col_character()),
    locale = readr::locale(encoding = "UTF-8"),
    show_col_types = FALSE,
    progress = FALSE
  )
}

#' Informa se os 3 CSVs do pacote passam na leitura tipada do loader atual.
leitura_tipada <- function(dir_data) {
  falhas <- names(ARQUIVOS_PACOTE)[!map_lgl(names(ARQUIVOS_PACOTE), \(ds) {
    tryCatch({
      suppressWarnings(le_csv_pncp(file.path(dir_data, ARQUIVOS_PACOTE[[ds]]), ds))
      TRUE
    }, error = function(e) FALSE)
  })]
  if (length(falhas) == 0) "ok" else paste("falha:", paste(falhas, collapse = ", "))
}

lista_pacotes <- function() {
  dirs <- list.dirs(DIR_PACOTES, recursive = TRUE)
  dirs <- dirs[basename(dirs) == "DATA"]
  completos <- map_lgl(dirs, \(d) all(file.exists(file.path(d, ARQUIVOS_PACOTE))))
  if (any(!completos)) {
    message("Pacotes ignorados por não terem os 3 CSVs: ", paste(dirs[!completos], collapse = "; "))
  }
  pacotes <- sub(paste0("^", DIR_PACOTES, "/"), "", dirname(dirs[completos]))
  ordena_pacotes(pacotes)
}

candidatos_pacote <- function(pacote) {
  dir_data <- file.path(DIR_PACOTES, pacote, "DATA")

  contratacoes <- le_csv_texto(file.path(dir_data, ARQUIVOS_PACOTE[["contratacoes"]])) |>
    filter(!is.na(endpoint)) |>
    adiciona_chaves_contratacoes() |>
    distinct(endpoint, .keep_all = TRUE) |>
    select(endpoint, numero_controle_pncp = data.numeroControlePNCP)

  medicamentos <- le_csv_texto(file.path(dir_data, ARQUIVOS_PACOTE[["medicamentos"]])) |>
    filter(!is.na(endpoint)) |>
    adiciona_chaves_medicamentos()

  resultados <- le_csv_texto(file.path(dir_data, ARQUIVOS_PACOTE[["resultados"]])) |>
    filter(!is.na(endpoint))

  colunas <- c("endpoint", "numeroItem", "endpointContratacao")
  ncm <- if ("ncmNbsCodigo" %in% names(medicamentos)) medicamentos$ncmNbsCodigo else rep(NA, nrow(medicamentos))

  candidatos <- bind_rows(
    medicamentos |>
      filter(eh_fracionaria(quantidade)) |>
      transmute(across(all_of(colunas)), motivo = "quantidade fracionária", valor_original = as.character(quantidade)),
    medicamentos[eh_ncm_invalido(ncm), , drop = FALSE] |>
      transmute(across(all_of(colunas)), motivo = "ncmNbsCodigo inválido", valor_original = as.character(ncmNbsCodigo)),
    medicamentos |>
      inner_join(
        resultados |> filter(eh_fracionaria(quantidadeHomologada)) |> select(endpoint, quantidadeHomologada),
        by = join_by(endpointResultado == endpoint)
      ) |>
      transmute(across(all_of(colunas)), motivo = "quantidadeHomologada fracionária", valor_original = as.character(quantidadeHomologada))
  )

  if (nrow(candidatos) == 0) {
    return(NULL)
  }

  candidatos |>
    left_join(contratacoes, by = join_by(endpointContratacao == endpoint)) |>
    transmute(
      pacote = pacote,
      leitura_tipada = leitura_tipada(dir_data),
      numero_controle_pncp,
      numero_item = numeroItem,
      endpoint,
      motivo,
      valor_original
    )
}


pacotes <- lista_pacotes()
message("Pacotes analisados: ", length(pacotes))

candidatos <- map(pacotes, \(p) {
  resultado <- candidatos_pacote(p)
  if (!is.null(resultado)) {
    message(sprintf("- %s: %d ocorrência(s); leitura tipada %s", p, nrow(resultado), resultado$leitura_tipada[1]))
  }
  resultado
}) |>
  list_rbind()

dir.create(dirname(SAIDA), recursive = TRUE, showWarnings = FALSE)
write_csv(candidatos, SAIDA, na = "")

message(sprintf(
  "Ocorrências: %d em %d pacotes; itens distintos: %d. Salvo em '%s'.",
  nrow(candidatos),
  n_distinct(candidatos$pacote),
  nrow(distinct(candidatos, numero_controle_pncp, numero_item)),
  SAIDA
))
print(count(candidatos, motivo))
print(
  candidatos |>
    distinct(leitura_tipada, numero_controle_pncp, numero_item) |>
    count(leitura_tipada, name = "itens")
)
