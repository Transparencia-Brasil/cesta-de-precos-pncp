#' Envia o data-package de um mês ao Google Drive, arquivo por arquivo.
#'
#' Uso (na raiz do projeto):
#'   Rscript.exe src/ETL/loaders/upload-datapackages.R <ANO> <MES> [--dry-run]
#'   Ex.: Rscript.exe src/ETL/loaders/upload-datapackages.R 2026 7 --dry-run
#'
#' Envia `coleta/data-package/<ANO>/<MES> - <Nome>/<intervalo>/<DATA|LOG>/<arquivo>`
#' para `Coletas - <ANO>/<MES> - <Nome>/<intervalo>/<DATA|LOG>/` no Drive:
#' - arquivo ausente no Drive: ENVIA;
#' - presente com o mesmo tamanho: PULA;
#' - presente com tamanho diferente (ex.: log que ganhou uma nota): ATUALIZA o
#'   conteúdo, mantendo o id do arquivo.
#' Pastas ausentes são criadas. Reexecutar é seguro: nada é duplicado. Com
#' `--dry-run`, o script só lista o que faria, sem criar ou enviar nada.
#'
#' Autenticação: service account em `drive-datapackage-upload.json` (raiz do
#' projeto, fora do git). Se a variável de ambiente DRIVE_AUTH_EMAIL estiver
#' definida, usa OAuth com essa conta (útil se a service account não tiver cota
#' de armazenamento na pasta de destino).

suppressPackageStartupMessages(library(googledrive))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(purrr))
suppressPackageStartupMessages(library(here))

options(googledrive_quiet = TRUE)

# Pasta que contém "Coletas - 2025", "Coletas - 2026", ...
DRIVE_RAIZ <- as_id("1lTEahEebtKeGG2Zjn7tn0Iu1pRkxi4OY")
DRIVE_CREDENCIAL <- here("drive-datapackage-upload.json")
DIR_LOCAL <- here("coleta/data-package")


# :: ARGUMENTOS -----------------------------------------------------------------

argumentos <- commandArgs(trailingOnly = TRUE)
DRY_RUN <- "--dry-run" %in% argumentos
periodo <- setdiff(argumentos, "--dry-run")

if (length(periodo) != 2 || !grepl("^[0-9]{4}$", periodo[1]) || !grepl("^[0-9]{1,2}$", periodo[2])) {
  stop("Uso: Rscript.exe src/ETL/loaders/upload-datapackages.R <ANO> <MES> [--dry-run]", call. = FALSE)
}

ANO <- periodo[1]
MES <- as.integer(periodo[2])

dir_mes <- list.dirs(file.path(DIR_LOCAL, ANO), recursive = FALSE)
dir_mes <- dir_mes[grepl(paste0("^", MES, " - "), basename(dir_mes))]
if (length(dir_mes) != 1) {
  stop(sprintf("Pasta local do mês não encontrada (ou ambígua) em '%s' para o mês %d.",
               file.path(DIR_LOCAL, ANO), MES), call. = FALSE)
}
NOME_MES <- basename(dir_mes)


# :: ARQUIVOS LOCAIS -----------------------------------------------------------

arquivos <- tibble(caminho = list.files(dir_mes, recursive = TRUE, full.names = TRUE)) |>
  mutate(
    relativo = substring(caminho, nchar(dir_mes) + 2),
    partes = strsplit(relativo, "/", fixed = TRUE),
    valido = map_lgl(partes, \(p) length(p) == 3 && p[2] %in% c("DATA", "LOG")),
    intervalo = map_chr(partes, 1),
    subpasta = map_chr(partes, \(p) if (length(p) >= 2) p[2] else NA_character_),
    nome = basename(caminho),
    tamanho = file.size(caminho)
  )

ignorados <- arquivos |> filter(!valido)
if (nrow(ignorados) > 0) {
  warning("Arquivos fora de <intervalo>/<DATA|LOG>/ ignorados: ",
          paste(ignorados$relativo, collapse = ", "), call. = FALSE)
}
arquivos <- arquivos |> filter(valido)
if (nrow(arquivos) == 0) {
  stop(sprintf("Nenhum arquivo para enviar em '%s'.", dir_mes), call. = FALSE)
}


# :: DRIVE ------------------------------------------------------------------------

email <- Sys.getenv("DRIVE_AUTH_EMAIL")
if (nzchar(email)) {
  drive_auth(email = email)
} else {
  drive_auth(path = DRIVE_CREDENCIAL)
}

#' Lista o conteúdo de uma pasta do Drive.
#'
#' Usa drive_find em "allDrives" em vez de drive_ls: as pastas ficam num Drive
#' compartilhado do qual a service account não é membro (ela tem acesso só às
#' pastas), e drive_ls falha ao consultar esse Drive compartilhado.
lista_pasta <- function(pasta, tipo = NULL) {
  drive_find(
    q = sprintf("'%s' in parents and trashed = false", as_id(pasta)),
    type = tipo,
    corpus = "allDrives"
  )
}

#' Retorna a pasta `nome` dentro de `pai`, criando-a se não existir.
#' Retorna NULL quando a pasta não existe e o modo é --dry-run.
obtem_ou_cria_pasta <- function(nome, pai, rotulo) {
  if (is.null(pai)) {
    message("CRIA PASTA ", rotulo)
    return(NULL)
  }

  existentes <- lista_pasta(pai, tipo = "folder") |> filter(name == nome)
  if (nrow(existentes) > 1) {
    stop(sprintf("Há %d pastas chamadas '%s' no Drive; resolva a duplicata antes.", nrow(existentes), rotulo),
         call. = FALSE)
  }
  if (nrow(existentes) == 1) {
    return(existentes)
  }

  message("CRIA PASTA ", rotulo)
  if (DRY_RUN) {
    return(NULL)
  }
  drive_mkdir(nome, path = pai, overwrite = FALSE)
}

tamanho_drive <- function(arquivos_drive) {
  as.numeric(map_chr(arquivos_drive$drive_resource, \(r) r$size %||% NA_character_))
}

pasta_ano <- obtem_ou_cria_pasta(paste("Coletas -", ANO), DRIVE_RAIZ, paste("Coletas -", ANO))
pasta_mes <- obtem_ou_cria_pasta(NOME_MES, pasta_ano, file.path(paste("Coletas -", ANO), NOME_MES))

acoes <- character()
pastas_intervalo <- list()

for (grupo in split(arquivos, list(arquivos$intervalo, arquivos$subpasta), drop = TRUE)) {
  intervalo <- grupo$intervalo[1]
  subpasta <- grupo$subpasta[1]
  rotulo_intervalo <- file.path(NOME_MES, intervalo)

  if (!intervalo %in% names(pastas_intervalo)) {
    pastas_intervalo[intervalo] <- list(obtem_ou_cria_pasta(intervalo, pasta_mes, rotulo_intervalo))
  }
  pasta_intervalo <- pastas_intervalo[[intervalo]]
  pasta_destino <- obtem_ou_cria_pasta(subpasta, pasta_intervalo, file.path(rotulo_intervalo, subpasta))

  no_drive <- if (is.null(pasta_destino)) {
    tibble(name = character(), id = character(), drive_resource = list())
  } else {
    lista_pasta(pasta_destino) |> filter(map_chr(drive_resource, "mimeType") != "application/vnd.google-apps.folder")
  }
  no_drive$tamanho <- tamanho_drive(no_drive)

  for (i in seq_len(nrow(grupo))) {
    arquivo <- grupo[i, ]
    remoto <- no_drive |> filter(name == arquivo$nome)

    acao <- if (nrow(remoto) == 0) {
      "ENVIA"
    } else if (nrow(remoto) > 1) {
      "DUPLICADO"
    } else if (isTRUE(remoto$tamanho == arquivo$tamanho)) {
      "PULA"
    } else {
      "ATUALIZA"
    }

    message(sprintf("%-9s %s", acao, arquivo$relativo))
    acoes <- c(acoes, acao)

    if (DRY_RUN) next
    if (acao == "ENVIA") {
      drive_upload(media = arquivo$caminho, path = pasta_destino, name = arquivo$nome, overwrite = FALSE)
    } else if (acao == "ATUALIZA") {
      drive_update(file = as_id(remoto$id), media = arquivo$caminho)
    }
  }
}

resumo <- table(factor(acoes, levels = c("ENVIA", "ATUALIZA", "PULA", "DUPLICADO")))
message(sprintf(
  "\n%s%s: %d enviados, %d atualizados, %d pulados, %d duplicados no Drive (não tocados).",
  if (DRY_RUN) "[--dry-run] " else "",
  file.path(paste("Coletas -", ANO), NOME_MES),
  resumo[["ENVIA"]], resumo[["ATUALIZA"]], resumo[["PULA"]], resumo[["DUPLICADO"]]
))
if (resumo[["DUPLICADO"]] > 0) {
  warning("Há arquivos com o mesmo nome repetido no Drive; remova as cópias e rode de novo.", call. = FALSE)
}
