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


# :: VERSIONAMENTO E PROVENIÊNCIA ---------------------------------------------

MEDICINE_EXTENSION_REPO <- "Transparencia-Brasil/medicine-extension-ocds"

# Caminhos dos artefatos no repositório `medicine-extension-ocds`
MEDICINE_EXTENSION_DOCUMENTO_OCDS <- "tasks/documento-ocds/outputs/documento-ocds.json"
MEDICINE_EXTENSION_DICIONARIO_OCDS <- "tasks/dicionario-ocds/outputs/dicionario-ocds.csv"

# Cabeçalho esperado do dicionário OCDS consumido por
# `tasks/mapeamento-ocds/src/mapeamento-pncp-ocds.py`
COLUNAS_DICIONARIO_OCDS <- c(
  "desc_item",
  "codigo_br",
  "nome_pdm",
  "activeIngredients.name",
  "dosageForm",
  "administrationRoute",
  "activeIngredients.strengthValue",
  "activeIngredients.strengthUnit",
  "immediateContainer",
  "caracteristicaFaltante",
  "attributes",
  "origem_activeIngredients",
  "origem_dosageForm",
  "origem_administrationRoute",
  "origem_strength",
  "origem_immediateContainer"
)

COLUNAS_VERSOES <- c(
  "versao",
  "arquivo",
  "sha256",
  "linhas",
  "origem_repo",
  "origem_caminho",
  "origem_commit",
  "registrado_em"
)


#' Carrega o `.env` sem sobrescrever variáveis já definidas no ambiente
#'
#' `dotenv::load_dot_env()` sobrescreve o ambiente; aqui, valores já definidos
#' (ex.: `GITHUB_TOKEN_READ_FILES=... Rscript.exe ...`) têm precedência sobre o
#' arquivo, como em `tasks/mapeamento-ocds/src/upload-zips-s3.py`.
#'
#' @param caminho Caminho do arquivo `.env`.
carrega_env <- function(caminho = here::here(".env")) {
  if (!file.exists(caminho)) return(invisible(NULL))

  ambiente <- Sys.getenv()
  ja_definidas <- names(ambiente)[ambiente != ""]

  dotenv::load_dot_env(caminho)

  if (length(ja_definidas) > 0) {
    do.call(Sys.setenv, as.list(ambiente[ja_definidas]))
  }
  invisible(NULL)
}

#' Monta uma requisição autenticada para a API do GitHub
#'
#' @param url URL da API do GitHub.
#' @param accept Valor do cabeçalho `Accept`.
#'
#' @return Objeto `httr2_request`.
requisicao_github <- function(url, accept = "application/vnd.github+json") {
  token <- Sys.getenv("GITHUB_TOKEN_READ_FILES")
  if (token == "") {
    stop("Variável GITHUB_TOKEN_READ_FILES não definida (ver .env.example).")
  }

  httr2::request(url) |>
    httr2::req_headers(
      Authorization = paste("Bearer", token),
      Accept = accept,
      `X-GitHub-Api-Version` = "2022-11-28"
    )
}

#' Resolve uma referência (branch, tag ou SHA) do `medicine-extension-ocds`
#'
#' @param ref Branch, tag ou SHA (curto ou completo).
#'
#' @return SHA completo do commit.
resolve_commit_medicine_extension <- function(ref = "main") {
  url <- sprintf(
    "https://api.github.com/repos/%s/commits/%s",
    MEDICINE_EXTENSION_REPO,
    ref
  )

  requisicao_github(url) |>
    httr2::req_perform() |>
    httr2::resp_body_json() |>
    purrr::pluck("sha")
}

#' Baixa um arquivo do `medicine-extension-ocds` em um commit específico
#'
#' @param caminho Caminho do arquivo no repositório remoto.
#' @param commit SHA completo do commit (ver `resolve_commit_medicine_extension()`).
#' @param destino Caminho local opcional; se informado, grava o conteúdo byte a byte.
#'
#' @return Vetor `raw` com o conteúdo do arquivo (invisível se `destino` for informado).
baixa_arquivo_medicine_extension <- function(caminho, commit, destino = NULL) {
  url <- sprintf(
    "https://api.github.com/repos/%s/contents/%s?ref=%s",
    MEDICINE_EXTENSION_REPO,
    caminho,
    commit
  )

  conteudo <- requisicao_github(url, accept = "application/vnd.github.raw+json") |>
    httr2::req_perform() |>
    httr2::resp_body_raw()

  if (is.null(destino)) {
    return(conteudo)
  }

  dir.create(dirname(destino), recursive = TRUE, showWarnings = FALSE)
  writeBin(conteudo, destino)
  invisible(conteudo)
}

#' Valida o dicionário OCDS de medicamentos contra os códigos do catálogo
#'
#' Interrompe a execução se o cabeçalho divergir de `COLUNAS_DICIONARIO_OCDS`,
#' se `codigo_br` tiver valores ausentes ou duplicados, ou se o conjunto de
#' códigos não for idêntico ao do catálogo da mesma versão.
#'
#' @param caminho Caminho do CSV do dicionário.
#' @param codigos_catalogo Vetor com os `codigo_br` do catálogo CATMAT.
#'
#' @return Número de linhas do dicionário (invisível).
valida_dicionario_ocds <- function(caminho, codigos_catalogo) {
  dicionario <- readr::read_csv(
    caminho,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE,
    progress = FALSE
  )

  if (!identical(names(dicionario), COLUNAS_DICIONARIO_OCDS)) {
    stop(sprintf(
      "Cabeçalho do dicionário OCDS inesperado em %s. Ausentes: %s. Extras: %s.",
      caminho,
      paste(setdiff(COLUNAS_DICIONARIO_OCDS, names(dicionario)), collapse = ", "),
      paste(setdiff(names(dicionario), COLUNAS_DICIONARIO_OCDS), collapse = ", ")
    ))
  }

  codigos <- trimws(dicionario$codigo_br)
  if (any(is.na(codigos) | codigos == "")) {
    stop("O dicionário OCDS contém codigo_br ausente ou vazio.")
  }
  if (anyDuplicated(codigos) > 0) {
    stop(sprintf(
      "O dicionário OCDS contém codigo_br duplicado: %s.",
      paste(utils::head(unique(codigos[duplicated(codigos)]), 10), collapse = ", ")
    ))
  }

  codigos_catalogo <- unique(trimws(as.character(codigos_catalogo)))
  faltam_no_dicionario <- setdiff(codigos_catalogo, codigos)
  sobram_no_dicionario <- setdiff(codigos, codigos_catalogo)
  if (length(faltam_no_dicionario) > 0 || length(sobram_no_dicionario) > 0) {
    stop(sprintf(
      paste(
        "Os códigos do dicionário OCDS (%s) não coincidem com os do catálogo (%s):",
        "%s ausentes no dicionário (ex.: %s); %s ausentes no catálogo (ex.: %s)."
      ),
      length(codigos),
      length(codigos_catalogo),
      length(faltam_no_dicionario),
      paste(utils::head(faltam_no_dicionario, 5), collapse = ", "),
      length(sobram_no_dicionario),
      paste(utils::head(sobram_no_dicionario, 5), collapse = ", ")
    ))
  }

  message(sprintf("Dicionário OCDS válido: %s códigos (%s).", length(codigos), caminho))
  invisible(nrow(dicionario))
}

#' Calcula o SHA-256 de um arquivo versionado
#'
#' Para arquivos de texto (`.csv`, `.json`), converte CRLF em LF antes do
#' cálculo, de modo que o hash não dependa de `core.autocrlf` na máquina.
#' Arquivos binários (`.rds`) são calculados sobre os bytes.
#'
#' @param caminho Caminho do arquivo.
#'
#' @return String com o hash SHA-256 em hexadecimal.
sha256_normalizado <- function(caminho) {
  conteudo <- readBin(caminho, what = "raw", n = file.size(caminho))

  if (tolower(tools::file_ext(caminho)) %in% c("csv", "json")) {
    n <- length(conteudo)
    if (n > 1) {
      cr_antes_de_lf <- which(conteudo[-n] == as.raw(0x0d) & conteudo[-1] == as.raw(0x0a))
      if (length(cr_antes_de_lf) > 0) conteudo <- conteudo[-cr_antes_de_lf]
    }
  }

  digest::digest(conteudo, algo = "sha256", serialize = FALSE)
}

#' Conta as linhas de dados de um arquivo versionado
#'
#' @param caminho Caminho de um `.csv` ou `.rds`.
#'
#' @return Inteiro com o número de registros.
conta_linhas <- function(caminho) {
  if (tolower(tools::file_ext(caminho)) == "rds") {
    return(nrow(readRDS(caminho)))
  }

  nrow(readr::read_csv(
    caminho,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE,
    progress = FALSE
  ))
}

#' Monta o registro de um arquivo para o histórico de versões
#'
#' @param versao Número da versão do CATMAT.
#' @param caminho Caminho local do arquivo.
#' @param origem_repo,origem_caminho,origem_commit Proveniência (vazias se desconhecidas).
#'
#' @return Tibble de uma linha com as colunas de `COLUNAS_VERSOES`.
registro_versao <- function(
  versao,
  caminho,
  origem_repo = NA_character_,
  origem_caminho = NA_character_,
  origem_commit = NA_character_
) {
  tibble::tibble(
    versao = as.integer(versao),
    arquivo = basename(caminho),
    sha256 = sha256_normalizado(caminho),
    linhas = as.integer(conta_linhas(caminho)),
    origem_repo = origem_repo,
    origem_caminho = origem_caminho,
    origem_commit = origem_commit,
    registrado_em = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  )
}

#' Acrescenta registros ao histórico de versões (`data/catmat/versoes.csv`)
#'
#' Registros já presentes (mesma `versao` e `arquivo`) com o mesmo hash são
#' ignorados; com hash diferente, a execução é interrompida.
#'
#' @param registros Tibble com as colunas de `COLUNAS_VERSOES`.
#' @param caminho Caminho do histórico de versões.
#'
#' @return Histórico atualizado (invisível).
registra_versoes <- function(registros, caminho) {
  registros <- registros[, COLUNAS_VERSOES]

  if (file.exists(caminho)) {
    historico <- readr::read_csv(
      caminho,
      col_types = readr::cols(
        versao = readr::col_integer(),
        linhas = readr::col_integer(),
        .default = readr::col_character()
      ),
      show_col_types = FALSE,
      progress = FALSE
    )
  } else {
    historico <- registros[0, ]
  }

  existentes <- dplyr::inner_join(
    registros,
    historico,
    by = c("versao", "arquivo"),
    suffix = c("", "_historico")
  )
  conflitos <- existentes[existentes$sha256 != existentes$sha256_historico, ]
  if (nrow(conflitos) > 0) {
    stop(sprintf(
      "Histórico de versões já registra conteúdo diferente para: %s.",
      paste(conflitos$versao, conflitos$arquivo, sep = "/", collapse = ", ")
    ))
  }

  novos <- dplyr::anti_join(registros, historico, by = c("versao", "arquivo"))
  historico <- dplyr::bind_rows(historico, novos) |>
    dplyr::arrange(versao, arquivo)

  readr::write_csv(historico, caminho, na = "")
  message(sprintf("Histórico de versões: %s registro(s) novo(s) em %s.", nrow(novos), caminho))
  invisible(historico)
}
