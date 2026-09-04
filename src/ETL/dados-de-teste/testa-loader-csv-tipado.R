# Este script testa a leitura tipada dos CSVs do loader com dados fictícios.
# Os arquivos são criados em um diretório temporário e nenhuma conexão com o
# PostgreSQL é aberta.

suppressPackageStartupMessages(library(here))
suppressPackageStartupMessages(library(readr))

source(here("src/ETL/loaders/utils.R"))

espera_erro <- function(expr, padroes) {
  mensagem <- NULL
  tryCatch(
    withCallingHandlers(
      force(expr),
      warning = function(w) invokeRestart("muffleWarning")
    ),
    error = function(e) {
      mensagem <<- conditionMessage(e)
    }
  )
  stopifnot(!is.null(mensagem))
  padroes_encontrados <- vapply(
    padroes,
    function(padrao) grepl(padrao, mensagem, fixed = TRUE),
    logical(1)
  )
  stopifnot(all(padroes_encontrados))
}

captura_aviso <- function(expr) {
  avisos <- character()
  valor <- withCallingHandlers(
    force(expr),
    warning = function(w) {
      avisos <<- c(avisos, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  list(valor = valor, avisos = avisos)
}

diretorio_teste <- tempfile("loader-csv-tipado-")
dir.create(diretorio_teste)
on.exit(unlink(diretorio_teste, recursive = TRUE), add = TRUE)

# Contratações: identificadores textuais, data/hora e coluna ainda desconhecida.
caminho_contratacoes <- file.path(diretorio_teste, "contratacoes.csv")
write_csv(
  data.frame(
    data.srp = TRUE,
    data.orgaoEntidade.cnpj = "00123456000199",
    data.dataAberturaProposta = "2026-05-18T08:00:00",
    colunaNova = "001",
    check.names = FALSE
  ),
  caminho_contratacoes,
  na = ""
)

leitura_contratacoes <- captura_aviso(
  le_csv_pncp(caminho_contratacoes, "contratacoes")
)
contratacoes <- leitura_contratacoes$valor
stopifnot(
  identical(contratacoes$data.orgaoEntidade.cnpj, "00123456000199"),
  inherits(contratacoes$data.dataAberturaProposta, "POSIXct"),
  identical(contratacoes$colunaNova, "001"),
  any(grepl("colunaNova", leitura_contratacoes$avisos, fixed = TRUE))
)

# Medicamentos: campos preenchidos somente após mais de mil linhas vazias e
# embedding com quebra de linha.
total_linhas <- 1002L
ultima_linha <- total_linhas
medicamentos_ficticios <- data.frame(
  numeroItem = seq_len(total_linhas),
  endpoint = paste0("https://exemplo.test/itens/", seq_len(total_linhas)),
  imagem = 0L,
  catalogo.descricao = NA_character_,
  catalogo.url = NA_character_,
  categoriaItemCatalogo.id = NA_real_,
  categoriaItemCatalogo.nome = NA_character_,
  categoriaItemCatalogo.dataInclusao = NA_character_,
  categoriaItemCatalogo.dataAtualizacao = NA_character_,
  catalogoCodigoItem = NA_character_,
  tipoBeneficio = rep("4.0", total_linhas),
  codigo_pdm = rep(363, total_linhas),
  embedding = rep("[0.1,\n0.2]", total_linhas),
  codigo_br = rep(268375L, total_linhas),
  similaridade = rep(0.75, total_linhas),
  medicamento = rep(TRUE, total_linhas),
  check.names = FALSE
)
medicamentos_ficticios$catalogo.descricao[ultima_linha] <-
  "Catálogo de bens e serviços"
medicamentos_ficticios$catalogo.url[ultima_linha] <-
  "https://catalogo.exemplo.test"
medicamentos_ficticios$categoriaItemCatalogo.id[ultima_linha] <- 1
medicamentos_ficticios$categoriaItemCatalogo.nome[ultima_linha] <- "Material"
medicamentos_ficticios$categoriaItemCatalogo.dataInclusao[ultima_linha] <-
  "2021-12-22T20:10:19"
medicamentos_ficticios$categoriaItemCatalogo.dataAtualizacao[ultima_linha] <-
  "2021-12-22T20:10:19"
medicamentos_ficticios$catalogoCodigoItem[ultima_linha] <- "024.003.003.000001"

caminho_medicamentos <- file.path(diretorio_teste, "medicamentos.csv")
write_csv(medicamentos_ficticios, caminho_medicamentos, na = "")
medicamentos <- le_csv_pncp(caminho_medicamentos, "medicamentos")

stopifnot(
  nrow(medicamentos) == total_linhas,
  is.integer(medicamentos$imagem),
  is.character(medicamentos$catalogo.descricao),
  is.double(medicamentos$categoriaItemCatalogo.id),
  inherits(medicamentos$categoriaItemCatalogo.dataInclusao, "POSIXct"),
  identical(
    medicamentos$catalogoCodigoItem[ultima_linha],
    "024.003.003.000001"
  ),
  identical(medicamentos$embedding[1], "[0.1,\n0.2]"),
  identical(medicamentos$tipoBeneficio[1], "4.0"),
  nrow(problems(medicamentos)) == 0
)

# Resultados: data, data/hora histórica e campos raros de amparo legal.
caminho_resultados <- file.path(diretorio_teste, "resultados.csv")
write_csv(
  data.frame(
    numeroControlePNCPCompra = "00123456000199-1-000001/2026",
    dataResultado = "2026-05-14",
    dataCancelamento = "0001-01-01T00:00:00",
    paisOrigemProdutoServico.id = "BRA",
    paisOrigemProdutoServico.nome = "Brasil",
    amparoLegalMargemPreferencia.id = 143,
    amparoLegalMargemPreferencia.nome = "Lei 14.133/2021",
    amparoLegalMargemPreferencia.descricao = "Margem de preferência",
    check.names = FALSE
  ),
  caminho_resultados,
  na = ""
)
resultados <- le_csv_pncp(caminho_resultados, "resultados")

stopifnot(
  inherits(resultados$dataResultado, "Date"),
  inherits(resultados$dataCancelamento, "POSIXct"),
  as.integer(format(resultados$dataCancelamento, "%Y", tz = "UTC")) == 1L,
  format(resultados$dataCancelamento, "%m-%d", tz = "UTC") == "01-01",
  identical(resultados$paisOrigemProdutoServico.id, "BRA"),
  is.double(resultados$amparoLegalMargemPreferencia.id),
  nrow(problems(resultados)) == 0
)

# Valor booleano incompatível deve interromper a leitura antes de qualquer
# etapa de transformação ou conexão com o banco.
caminho_invalido <- file.path(diretorio_teste, "contratacoes-invalidas.csv")
write_csv(
  data.frame(data.srp = "talvez", check.names = FALSE),
  caminho_invalido,
  na = ""
)
espera_erro(
  le_csv_pncp(caminho_invalido, "contratacoes"),
  c(
    "Falha ao interpretar o CSV de contratacoes",
    "linha 2, coluna 1",
    "esperado 1/0/T/F/TRUE/FALSE",
    "encontrado 'talvez'"
  )
)

message("Testes da leitura tipada dos CSVs do loader: OK")
