#' Recupera os itens que a carga rejeitava por quantidade fracionária ou por
#' ncmNbsCodigo inválido, listados em `outputs/candidatos.csv`
#' (gerado por `lista-candidatos.R`).
#'
#' As linhas de item são montadas com as mesmas funções da carga regular
#' (`src/ETL/loaders/utils.R`), que agora truncam as quantidades e normalizam o
#' NCM. Para cada item, vale a versão do pacote mais recente.
#'
#' Garantias:
#' - só INSERE itens ausentes do banco; itens existentes não são alterados;
#' - não grava `contratacao` nem `contratante`: contratações reaparecem
#'   atualizadas em pacotes posteriores, e regravá-las a partir de um pacote
#'   antigo desfaria essas atualizações;
#' - insere `fornecedor` com a consulta da carga (ON CONFLICT DO NOTHING);
#' - item cuja contratação, contratante ou código de catálogo não existe no
#'   banco fica pendente e não é inserido;
#' - todas as inserções ocorrem em uma única transação (rollback em caso de erro).
#'
#' Leitura tolerante (somente nesta recuperação; o loader não muda):
#' - itens-medicamentos.csv com o artefato "FALSE,," em
#'   `exigenciaConteudoNacional` (jul/2025 a mar/2026) é lido com essa coluna como
#'   texto e normalizado para o primeiro valor ("FALSE");
#' - contratacoes.csv com linhas desalinhadas (fev a jun/2025) é lido como texto.
#'   Em todos os pacotes, uma contratação só é usada se `data.numeroControlePNCP`
#'   for coerente com CNPJ, ano e sequencial da própria linha.
#'
#' Uso (na raiz do projeto):
#'   Rscript.exe <tarefa>/src/R/recupera-itens.R --sem-banco   # só monta as linhas
#'   Rscript.exe <tarefa>/src/R/recupera-itens.R --dry-run     # + consultas de leitura no banco
#'   Rscript.exe <tarefa>/src/R/recupera-itens.R               # insere

suppressPackageStartupMessages(library(readr))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(purrr))
suppressPackageStartupMessages(library(here))
suppressPackageStartupMessages(library(DBI))

source(here("src/ETL/loaders/utils.R"))
source(here("src/ETL/loaders/utils-historico.R"))

DIR_TAREFA <- here("tasks/alteracoes-no-banco-de-dados/recupera-itens-quantidade-fracionaria")
CANDIDATOS <- file.path(DIR_TAREFA, "outputs", "candidatos.csv")
VERIFICACAO <- file.path(DIR_TAREFA, "outputs", "verificacao-banco.csv")
DIR_PACOTES <- here("coleta/data-package")
ROTINA <- "recuperacao_quantidade_fracionaria"

argumentos <- commandArgs(trailingOnly = TRUE)
SEM_BANCO <- "--sem-banco" %in% argumentos
DRY_RUN <- SEM_BANCO || "--dry-run" %in% argumentos


# LEITURA TOLERANTE -------------------------------------------------------

le_csv_texto <- function(caminho) {
  readr::read_csv(
    caminho,
    col_types = readr::cols(.default = readr::col_character()),
    locale = readr::locale(encoding = "UTF-8"),
    show_col_types = FALSE,
    progress = FALSE
  )
}

le_medicamentos_tolerante <- function(caminho) {
  tryCatch(
    suppressWarnings(le_csv_pncp(caminho, "medicamentos")),
    error = function(e) {
      tipos <- tipos_colunas_csv_pncp("medicamentos")
      cabecalho <- names(readr::read_csv(
        caminho, n_max = 0,
        col_types = readr::cols(.default = readr::col_character()),
        show_col_types = FALSE
      ))
      tipos$cols <- tipos$cols[names(tipos$cols) %in% cabecalho]
      tipos$cols[["exigenciaConteudoNacional"]] <- readr::col_character()

      dados <- suppressWarnings(readr::read_csv(
        caminho,
        col_types = tipos,
        locale = readr::locale(encoding = "UTF-8", tz = "UTC"),
        show_col_types = FALSE,
        progress = FALSE
      ))
      if (nrow(readr::problems(dados)) > 0) {
        stop(sprintf(
          "itens-medicamentos.csv ilegível mesmo com leitura tolerante (%d problema(s)).",
          nrow(readr::problems(dados))
        ))
      }

      # Artefato da coleta: "FALSE,," -> "FALSE".
      dados$exigenciaConteudoNacional <- sub(",.*$", "", dados$exigenciaConteudoNacional)
      message("  leitura tolerante: itens-medicamentos.csv (exigenciaConteudoNacional)")
      dados
    }
  )
}

le_contratacoes_tolerante <- function(caminho) {
  tryCatch(
    suppressWarnings(le_csv_pncp(caminho, "contratacoes")),
    error = function(e) {
      message("  leitura tolerante: contratacoes.csv como texto, com validação das chaves")
      le_csv_texto(caminho)
    }
  )
}

#' Uma contratação só é usada se o numeroControlePNCP for coerente com o
#' CNPJ, o ano e o sequencial da própria linha (detecta linhas desalinhadas).
marca_contratacao_valida <- function(contratacoes) {
  cnpj <- as.character(contratacoes$data.orgaoEntidade.cnpj)
  ano <- as.character(contratacoes$data.anoCompra)
  sequencial <- suppressWarnings(as.integer(contratacoes$data.sequencialCompra))
  esperado <- sprintf("%s-1-%06d/%s", cnpj, sequencial, ano)
  subrogado <- as.character(contratacoes$data.orgaoSubRogado.cnpj)

  contratacoes$contratacao_valida <-
    grepl("^[0-9]{14}$", cnpj) &
    !is.na(sequencial) &
    grepl("^[0-9]{4}$", ano) &
    as.character(contratacoes$data.numeroControlePNCP) == esperado &
    !is.na(contratacoes$data.unidadeOrgao.codigoUnidade) &
    (is.na(subrogado) | grepl("^[0-9]{14}$", subrogado))
  contratacoes$contratacao_valida[is.na(contratacoes$contratacao_valida)] <- FALSE
  contratacoes
}


# MONTAGEM DAS LINHAS -----------------------------------------------------

pendente <- function(pacote, alvo, motivo) {
  tibble(
    tabela = NA_character_,
    pacote = pacote,
    numero_controle_pncp = alvo$numero_controle_pncp,
    numero_item = alvo$numero_item,
    status = paste("pendente:", motivo)
  )
}

monta_pacote <- function(pacote, alvo) {
  dir_data <- file.path(DIR_PACOTES, pacote, "DATA")
  message("- ", pacote, ": ", nrow(alvo), " item(ns)")

  tryCatch({
    medicamentos <- le_medicamentos_tolerante(file.path(dir_data, "itens-medicamentos.csv")) |>
      normaliza_medicamentos_carga() |>
      filter(!is.na(endpoint)) |>
      adiciona_chaves_medicamentos() |>
      semi_join(alvo, by = c("endpoint", numeroItem = "numero_item"))

    contratacoes <- le_contratacoes_tolerante(file.path(dir_data, "contratacoes.csv")) |>
      filter(!is.na(endpoint)) |>
      adiciona_chaves_contratacoes() |>
      semi_join(medicamentos, by = join_by(endpoint == endpointContratacao)) |>
      marca_contratacao_valida() |>
      filter(contratacao_valida) |>
      distinct(endpoint, .keep_all = TRUE)

    resultados <- suppressWarnings(le_csv_pncp(file.path(dir_data, "itens-medicamentos-resultados.csv"), "resultados")) |>
      filter(!is.na(endpoint))

    sem_contratacao <- medicamentos |>
      anti_join(contratacoes, by = join_by(endpointContratacao == endpoint)) |>
      semi_join(x = alvo, by = c(endpoint = "endpoint", numero_item = "numeroItem"))

    list(
      item_homologado = monta_item_homologado(medicamentos, resultados, contratacoes) |> mutate(.pacote = pacote),
      item_licitado = monta_item_licitado(medicamentos, resultados, contratacoes) |> mutate(.pacote = pacote),
      fornecedor = resultados |>
        semi_join(medicamentos, by = join_by(endpoint == endpointResultado)) |>
        select(all_of(COLUNAS_FORNECEDOR)) |>
        distinct(niFornecedor, .keep_all = TRUE),
      pendentes = pendente(pacote, sem_contratacao, "contratação ausente ou com linha desalinhada no pacote")
    )
  }, error = function(e) {
    message("  ERRO: ", conditionMessage(e))
    list(pendentes = pendente(pacote, alvo, paste("pacote ilegível -", conditionMessage(e))))
  })
}

candidatos <- read_csv(CANDIDATOS, col_types = cols(.default = col_character())) |>
  mutate(numero_item = as.integer(numero_item))
pacotes <- unique(candidatos$pacote)  # já em ordem cronológica

message("Montando linhas de ", n_distinct(candidatos$endpoint, candidatos$numero_item),
        " itens candidatos em ", length(pacotes), " pacotes...")
montados <- map(pacotes, \(p) {
  monta_pacote(p, candidatos |> filter(pacote == p) |> distinct(numero_controle_pncp, endpoint, numero_item))
})

# Para cada item, vale a versão do pacote mais recente.
ultima_versao <- function(tabela) {
  map(montados, tabela) |>
    compact() |>
    list_rbind() |>
    mutate(.ordem = match(.pacote, pacotes)) |>
    arrange(.ordem) |>
    group_by(data.numeroControlePNCP, numeroItem) |>
    slice_tail(n = 1) |>
    ungroup()
}

item_homologado <- ultima_versao("item_homologado")
item_licitado <- ultima_versao("item_licitado")
fornecedor <- map(montados, "fornecedor") |> compact() |> list_rbind() |> distinct(niFornecedor, .keep_all = TRUE)
pendentes_montagem <- map(montados, "pendentes") |> compact() |> list_rbind()

message(sprintf(
  "Linhas montadas: item_homologado=%d, item_licitado=%d; pendentes na montagem=%d.",
  nrow(item_homologado), nrow(item_licitado), nrow(pendentes_montagem)
))

if (SEM_BANCO) {
  message("Modo --sem-banco: nenhuma consulta ao banco foi feita.")
  print(count(pendentes_montagem, status))
  quit(save = "no", status = 0)
}


# VERIFICAÇÃO NO BANCO (somente leitura) ----------------------------------

con <- conecta_bd_medicamentos_transparentes()
on.exit(dbDisconnect(con), add = TRUE)

consulta_em <- function(sql, valores) {
  valores <- unique(as.character(valores[!is.na(valores)]))
  if (length(valores) == 0) {
    return(NULL)
  }
  dbGetQuery(con, sprintf(sql, paste(dbQuoteString(con, valores), collapse = ", ")))
}

npc <- c(item_homologado$data.numeroControlePNCP, item_licitado$data.numeroControlePNCP)
existentes_homologado <- consulta_em(
  "SELECT numero_controle_pncp, numero_item FROM item_homologado WHERE numero_controle_pncp IN (%s)", npc
)
existentes_licitado <- consulta_em(
  "SELECT numero_controle_pncp, numero_item FROM item_licitado WHERE numero_controle_pncp IN (%s)", npc
)
contratacoes_banco <- consulta_em(
  "SELECT numero_controle_pncp FROM contratacao WHERE numero_controle_pncp IN (%s)", npc
)$numero_controle_pncp
catalogo_banco <- consulta_em(
  "SELECT codigo_item::text AS codigo_item FROM catalogo WHERE codigo_item::text IN (%s)",
  c(item_homologado$codigo_br, item_licitado$codigo_br)
)$codigo_item
contratantes_banco <- consulta_em(
  "SELECT cnpj, codigo_unidade::text AS codigo_unidade FROM contratante WHERE cnpj IN (%s)",
  c(
    item_homologado$data.orgaoEntidade.cnpj, item_homologado$data.orgaoSubRogado.cnpj,
    item_licitado$data.orgaoEntidade.cnpj, item_licitado$data.orgaoSubRogado.cnpj
  )
)
# contratante.cnpj é BIGINT: o banco devolve o CNPJ sem zeros à esquerda.
sem_zeros <- function(cnpj) sub("^0+", "", as.character(cnpj))
chaves_contratantes <- paste(sem_zeros(contratantes_banco$cnpj), contratantes_banco$codigo_unidade)

classifica <- function(tabela, existentes, nome) {
  chaves_existentes <- paste(existentes$numero_controle_pncp, existentes$numero_item)
  tabela |>
    mutate(
      status = case_when(
        paste(data.numeroControlePNCP, numeroItem) %in% chaves_existentes ~ "já existe no banco (não alterado)",
        !(data.numeroControlePNCP %in% contratacoes_banco) ~ "pendente: contratação ausente no banco",
        !is.na(codigo_br) & !(as.character(codigo_br) %in% catalogo_banco) ~ "pendente: código de catálogo ausente no banco",
        !(paste(sem_zeros(data.orgaoEntidade.cnpj), data.unidadeOrgao.codigoUnidade) %in% chaves_contratantes) ~
          "pendente: contratante ausente no banco",
        !is.na(data.orgaoSubRogado.cnpj) &
          !(paste(sem_zeros(data.orgaoSubRogado.cnpj), data.unidadeSubRogada.codigoUnidade) %in% chaves_contratantes) ~
          "pendente: contratante sub-rogado ausente no banco",
        TRUE ~ "inserir"
      ),
      .tabela = nome
    )
}

item_homologado <- classifica(item_homologado, existentes_homologado, "item_homologado")
item_licitado <- classifica(item_licitado, existentes_licitado, "item_licitado")

verificacao <- bind_rows(
  map(list(item_homologado, item_licitado), \(t) {
    t |> transmute(
      tabela = .tabela,
      pacote = .pacote,
      numero_controle_pncp = data.numeroControlePNCP,
      numero_item = numeroItem,
      status
    )
  }),
  pendentes_montagem
) |>
  arrange(tabela, pacote, numero_controle_pncp, numero_item)

write_csv(verificacao, VERIFICACAO, na = "")
message("Verificação salva em '", VERIFICACAO, "':")
print(count(verificacao, tabela, status))

inserir_homologado <- item_homologado |> filter(status == "inserir") |> select(all_of(COLUNAS_ITEM_HOMOLOGADO))
inserir_licitado <- item_licitado |> filter(status == "inserir") |> select(all_of(COLUNAS_ITEM_LICITADO))
inserir_fornecedor <- fornecedor |> filter(niFornecedor %in% inserir_homologado$niFornecedor)

if (DRY_RUN) {
  message(sprintf(
    "Modo --dry-run: seriam inseridos %d item_homologado, %d item_licitado (e até %d fornecedores). Nada foi gravado.",
    nrow(inserir_homologado), nrow(inserir_licitado), nrow(inserir_fornecedor)
  ))
  quit(save = "no", status = 0)
}


# INSERÇÃO (transação única) ----------------------------------------------

if (nrow(inserir_homologado) + nrow(inserir_licitado) == 0) {
  message("Nada a inserir.")
  quit(save = "no", status = 0)
}

contagens_antes <- contar_tabelas_historico(con)

dbBegin(con)
sucesso <- tryCatch({
  insere_tabela(con, inserir_fornecedor, CONSULTA_INSERIR_FORNECEDOR, interromper_em_erro = TRUE)
  insere_tabela(con, inserir_homologado, CONSULTA_INSERIR_ITEM_HOMOLOGADO, interromper_em_erro = TRUE)
  insere_tabela(con, inserir_licitado, CONSULTA_INSERIR_ITEM_LICITADO, interromper_em_erro = TRUE)
  dbCommit(con)
  TRUE
}, error = function(e) {
  dbRollback(con)
  message("ERRO: ", conditionMessage(e))
  message("Nenhuma linha foi gravada (rollback).")
  FALSE
})

if (!sucesso) {
  quit(save = "no", status = 1)
}

contagens_depois <- contar_tabelas_historico(con)
linhas_historico <- montar_linhas_historico(
  rotina = ROTINA,
  contagens_antes = contagens_antes,
  contagens_depois = contagens_depois,
  observacao = sprintf(
    "Recuperação de %d itens rejeitados por quantidade fracionária ou NCM inválido (tasks/alteracoes-no-banco-de-dados/recupera-itens-quantidade-fracionaria)",
    nrow(inserir_homologado) + nrow(inserir_licitado)
  )
)
registrar_historico_cargas(linhas_historico)

delta <- contagens_depois - contagens_antes[names(contagens_depois)]
print(delta)
esperado <- c(item_homologado = nrow(inserir_homologado), item_licitado = nrow(inserir_licitado), contratacao = 0, contratante = 0)
divergentes <- names(esperado)[delta[names(esperado)] != esperado]
if (length(divergentes) > 0) {
  warning("Delta diferente do esperado em: ", paste(divergentes, collapse = ", "),
          " (outra carga simultânea?). Confira historico-cargas.csv.", call. = FALSE)
}
message(sprintf(
  "Recuperação concluída: %d item_homologado e %d item_licitado inseridos.",
  nrow(inserir_homologado), nrow(inserir_licitado)
))
