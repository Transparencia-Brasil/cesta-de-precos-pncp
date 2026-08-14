# Este script testa somente as funções de validação do loader de catálogo.
# Os dados usados abaixo são exemplos fictícios criados no próprio arquivo; não
# é necessário inserir dados reais. O teste não lê o catmat-1.rds, não abre
# conexão com o PostgreSQL e não grava nenhuma informação no banco.
#
# Para validar os 6.740 itens reais do CATMAT sem alterar o banco, execute:
# Rscript src/ETL/loaders/carrega-catalogo.R \
#   data/catmat/catmat-1.rds --validar-apenas

suppressPackageStartupMessages(library(here))

source(here("src/ETL/loaders/utils.R"))

espera_erro <- function(expr) {
  ocorreu_erro <- FALSE
  tryCatch(
    force(expr),
    error = function(e) {
      ocorreu_erro <<- TRUE
    }
  )
  stopifnot(ocorreu_erro)
}

fonte_valida <- data.frame(
  codigo_classe = 1L,
  nome_classe = "Classe",
  codigo_pdm = 10L,
  nome_pdm = "PDM",
  codigo_br = 100L,
  nome_item = "Item 100",
  item_suspenso = FALSE,
  item_ativo = TRUE,
  item_sustentavel = FALSE,
  stringsAsFactors = FALSE
)
fonte_valida$buscaItemCaracteristica <- list(data.frame())
fonte_valida$unidadeFornecimento <- list(list())

valida_catalogo_fonte(fonte_valida)

fonte_duplicada <- rbind(fonte_valida, fonte_valida)
espera_erro(valida_catalogo_fonte(fonte_duplicada))
espera_erro(valida_catalogo_fonte(fonte_valida[, -1]))

mapeamento_valido <- data.frame(
  codigo_item = "100",
  caracteristicas_ocds = "[]",
  stringsAsFactors = FALSE
)
valida_compatibilidade_mapeamento_ocds(fonte_valida, mapeamento_valido)

mapeamento_incompativel <- data.frame(
  codigo_item = "999",
  caracteristicas_ocds = "[]",
  stringsAsFactors = FALSE
)
espera_erro(valida_compatibilidade_mapeamento_ocds(
  fonte_valida,
  mapeamento_incompativel
))

tabela_valida <- data.frame(
  codigo_classe = 1L,
  nome_classe = "Classe",
  codigo_pdm = 10L,
  nome_pdm = "PDM",
  codigo_br = "100",
  nome_item = "Item 100",
  item_suspenso = FALSE,
  item_ativo = TRUE,
  item_sustentavel = FALSE,
  caracteristicas_ocds = "[]",
  caracteristicas = "[]",
  unidade_fornecimento = "[]",
  stringsAsFactors = FALSE
)
valida_tabela_catalogo(tabela_valida, 1L)

tabela_json_invalido <- tabela_valida
tabela_json_invalido$caracteristicas <- "{"
espera_erro(valida_tabela_catalogo(tabela_json_invalido, 1L))
espera_erro(valida_tabela_catalogo(tabela_valida, 2L))

message("Testes das validações do loader de catálogo: OK")
