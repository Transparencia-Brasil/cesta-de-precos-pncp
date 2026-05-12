#' Helpers para registrar historico de cargas no CSV versionado.

HISTORICO_CARGAS_PATH <- here::here("src/ETL/loaders/historico-cargas.csv")

COLUNAS_HISTORICO_CARGAS <- c(
  "id_execucao",
  "executado_em",
  "rotina",
  "ano",
  "mes",
  "quinzena",
  "periodo_label",
  "tabela",
  "contagem_antes",
  "contagem_depois",
  "delta",
  "diretorio_data_package",
  "observacao"
)

TABELAS_HISTORICO_CARGAS <- c(
  "contratante",
  "fornecedor",
  "contratacao",
  "item_homologado",
  "item_licitado"
)

normaliza_caminho_historico <- function(caminho) {
  gsub("\\\\", "/", caminho)
}

cria_historico_cargas_vazio <- function() {
  data.frame(
    id_execucao = character(),
    executado_em = character(),
    rotina = character(),
    ano = integer(),
    mes = integer(),
    quinzena = character(),
    periodo_label = character(),
    tabela = character(),
    contagem_antes = integer(),
    contagem_depois = integer(),
    delta = integer(),
    diretorio_data_package = character(),
    observacao = character(),
    stringsAsFactors = FALSE
  )
}

normaliza_historico_cargas <- function(df) {
  for (col in setdiff(COLUNAS_HISTORICO_CARGAS, names(df))) {
    df[[col]] <- NA
  }

  df <- as.data.frame(df[COLUNAS_HISTORICO_CARGAS], stringsAsFactors = FALSE)

  colunas_inteiras <- c("ano", "mes", "contagem_antes", "contagem_depois", "delta")
  for (col in colunas_inteiras) {
    df[[col]] <- suppressWarnings(as.integer(df[[col]]))
  }

  colunas_texto <- setdiff(COLUNAS_HISTORICO_CARGAS, colunas_inteiras)
  for (col in colunas_texto) {
    df[[col]] <- as.character(df[[col]])
  }

  df
}

inferir_periodo_historico <- function(caminhos) {
  caminhos <- caminhos[!is.na(caminhos) & nzchar(caminhos)]

  if (length(caminhos) == 0) {
    return(data.frame(
      ano = NA_integer_,
      mes = NA_integer_,
      quinzena = NA_character_,
      periodo_label = NA_character_,
      diretorio_data_package = NA_character_,
      stringsAsFactors = FALSE
    ))
  }

  caminhos <- normaliza_caminho_historico(caminhos)
  diretorios <- ifelse(
    nzchar(tools::file_ext(basename(caminhos))),
    dirname(caminhos),
    caminhos
  )
  caminhos_busca <- unique(c(caminhos, diretorios))

  padrao_data_package <- paste0(
    "coleta/data-package/([0-9]{4})/",
    "([0-9]{1,2})(?:\\s*-\\s*[^/]+)?/",
    "(QUINZENA-[12])(?:/DATA)?"
  )

  for (caminho in caminhos_busca) {
    match <- regmatches(
      caminho,
      regexec(padrao_data_package, caminho, ignore.case = TRUE, perl = TRUE)
    )[[1]]

    if (length(match) > 0) {
      ano <- as.integer(match[2])
      mes <- as.integer(match[3])
      quinzena <- toupper(match[4])
      diretorio_data_package <- if (grepl("/DATA$", match[1], ignore.case = TRUE)) {
        match[1]
      } else {
        paste0(match[1], "/DATA")
      }

      return(data.frame(
        ano = ano,
        mes = mes,
        quinzena = quinzena,
        periodo_label = sprintf("%04d-%02d/%s", ano, mes, quinzena),
        diretorio_data_package = diretorio_data_package,
        stringsAsFactors = FALSE
      ))
    }
  }

  padrao_resultados <- "coleta/resultados/([0-9]{4})-([0-9]{2})/(QUINZENA-[12])"

  for (caminho in caminhos_busca) {
    match <- regmatches(
      caminho,
      regexec(padrao_resultados, caminho, ignore.case = TRUE, perl = TRUE)
    )[[1]]

    if (length(match) > 0) {
      ano <- as.integer(match[2])
      mes <- as.integer(match[3])
      quinzena <- toupper(match[4])

      return(data.frame(
        ano = ano,
        mes = mes,
        quinzena = quinzena,
        periodo_label = sprintf("%04d-%02d/%s", ano, mes, quinzena),
        diretorio_data_package = NA_character_,
        stringsAsFactors = FALSE
      ))
    }
  }

  data.frame(
    ano = NA_integer_,
    mes = NA_integer_,
    quinzena = NA_character_,
    periodo_label = paste(unique(diretorios), collapse = "; "),
    diretorio_data_package = NA_character_,
    stringsAsFactors = FALSE
  )
}

contar_tabela_historico <- function(con, tabela) {
  tryCatch({
    consulta <- paste(
      "SELECT COUNT(*) AS n FROM",
      DBI::dbQuoteIdentifier(con, tabela)
    )

    DBI::dbGetQuery(con, consulta)$n |>
      dplyr::first() |>
      as.integer()
  }, error = function(e) {
    message(sprintf("Falha ao contar a tabela %s: %s", tabela, e$message))
    NA_integer_
  })
}

contar_tabelas_historico <- function(con, tabelas = TABELAS_HISTORICO_CARGAS) {
  contagens <- vapply(
    tabelas,
    function(tabela) contar_tabela_historico(con, tabela),
    integer(1)
  )

  stats::setNames(contagens, tabelas)
}

criar_id_execucao_historico <- function(rotina, periodo_label, executado_em) {
  id <- paste(executado_em, rotina, periodo_label, sep = "_")
  id <- gsub("[^A-Za-z0-9]+", "_", id)
  gsub("^_+|_+$", "", id)
}

montar_linhas_historico <- function(rotina,
                                    contagens_antes,
                                    contagens_depois,
                                    caminhos_origem = character(),
                                    observacao = NA_character_) {
  tabelas <- names(contagens_depois)

  if (is.null(tabelas) || any(!nzchar(tabelas))) {
    stop("As contagens depois precisam ser um vetor nomeado por tabela.")
  }

  contagens_antes <- contagens_antes[tabelas]
  contagens_depois <- contagens_depois[tabelas]
  periodo <- inferir_periodo_historico(caminhos_origem)
  executado_em <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %z")
  id_execucao <- criar_id_execucao_historico(
    rotina = rotina,
    periodo_label = periodo$periodo_label,
    executado_em = executado_em
  )

  delta <- ifelse(
    is.na(contagens_antes) | is.na(contagens_depois),
    NA_integer_,
    contagens_depois - contagens_antes
  )

  if (length(observacao) == 1) {
    observacao <- rep(observacao, length(tabelas))
  }

  if (length(observacao) != length(tabelas)) {
    stop("observacao deve ter tamanho 1 ou o mesmo tamanho de contagens_depois.")
  }

  linhas <- data.frame(
    id_execucao = id_execucao,
    executado_em = executado_em,
    rotina = rotina,
    ano = periodo$ano,
    mes = periodo$mes,
    quinzena = periodo$quinzena,
    periodo_label = periodo$periodo_label,
    tabela = tabelas,
    contagem_antes = as.integer(contagens_antes),
    contagem_depois = as.integer(contagens_depois),
    delta = as.integer(delta),
    diretorio_data_package = periodo$diretorio_data_package,
    observacao = observacao,
    stringsAsFactors = FALSE
  )

  normaliza_historico_cargas(linhas)
}

registrar_historico_cargas <- function(linhas,
                                       caminho_historico = HISTORICO_CARGAS_PATH) {
  linhas <- normaliza_historico_cargas(linhas)

  historico <- if (file.exists(caminho_historico) && file.size(caminho_historico) > 0) {
    readr::read_csv(
      caminho_historico,
      col_types = readr::cols(
        id_execucao = readr::col_character(),
        executado_em = readr::col_character(),
        rotina = readr::col_character(),
        ano = readr::col_integer(),
        mes = readr::col_integer(),
        quinzena = readr::col_character(),
        periodo_label = readr::col_character(),
        tabela = readr::col_character(),
        contagem_antes = readr::col_integer(),
        contagem_depois = readr::col_integer(),
        delta = readr::col_integer(),
        diretorio_data_package = readr::col_character(),
        observacao = readr::col_character()
      ),
      na = c("", "NA"),
      show_col_types = FALSE
    ) |>
      normaliza_historico_cargas()
  } else {
    cria_historico_cargas_vazio()
  }

  historico <- rbind(historico, linhas)

  dir.create(dirname(caminho_historico), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(historico, caminho_historico, na = "")

  message(sprintf(
    "Historico de cargas atualizado em '%s' (%d linhas anexadas).",
    caminho_historico,
    nrow(linhas)
  ))

  invisible(linhas)
}
