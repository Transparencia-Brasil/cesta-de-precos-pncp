#' @title Unificação de resultados de itens das contratações após recoleta
#' ---
#' @description Este script unifica a coleta de resultados de itens remanescentes com a base de dados das coletas anteriores. Ele garante que os dados estejam alinhados em termos de colunas e tipos, e salva o arquivo unificado em formato CSV.
#'
#' @details O script realiza as seguintes etapas:
#' 1. Carrega os resultados de itens já unificados e os resultados de itens remanescentes.
#' 2. Compara as colunas dos dataframes com um template para garantir que estejam alinhados.
#' 3. Ordena as colunas para garantir que estejam na mesma ordem.
#' 4. Coerção de tipos para garantir que todas as colunas sejam do
#' mesmo tipo (caracteres).
#' 5. Une os dataframes de resultados unificados e remanescentes, removendo duplicatas.
#' 6. Salva o arquivo unificado em formato CSV, criando um backup do arquivo original.
#'
#' @return O arquivo unificado de resultados de itens, salvo em "tasks/unifica-dados/output/itens-resultados.csv", e um backup do arquivo original salvo como "tasks/unifica-dados/output/itens-resultados.csv.old".
#'

library(here)
library(tidyverse)

source(here("tasks/unifica-dados/src/01-mapeamento.R"))


# :: FILEPATHS -----------------------------------------------------------------

# os arquivos unificados ficarão salvos na pasta "output"
OUTPUT_DIR <- "tasks/unifica-dados/output"

# itens-resultados já coletados
PATH_RESULTADOS_UNIFICADOS <- here(OUTPUT_DIR, "itens-resultados.csv")

# itens-resultados remanescentes
PATH_RESULTADOS_NOVOS <- here("coleta/resultados/remanescentes/dados.csv")

# dados de teste
CAMINHO_DADOS_DE_TESTE <- here("src/ETL/dados-de-teste/amostra_resultados.csv")


# :: CARREGA COLETAS -----------------------------------------------------------

resultados_unificados <- read_csv(PATH_RESULTADOS_UNIFICADOS)
resultados_novos <- read_csv(PATH_RESULTADOS_NOVOS)

# dados de teste:
# Serve como referência para preencher nome de colunas e garantir que os dataframes possuem colunas de mesmo tipo
template <- read_csv(CAMINHO_DADOS_DE_TESTE, col_types = cols(.default = col_character()))[1:5, ] %>%
  mutate(endpoint = NA_character_)


# :: MAPPING -------------------------------------------------------------------

# executa rotina de mapeamento
# compara colunas com template ->> expected: `faltando` e `extras`` vazios e `comuns` com 39 elementos

resultados_unificados # já foi mapeada
comparar_colunas(resultados_unificados, template)

resultados_novos <- mapeamento_colunas_resultado_coleta_remanescente(resultados_novos)
comparar_colunas(resultados_novos, template)


# :: ORDENAR COLUNA ------------------------------------------------------------

# Alinhar perfeitamente as colunas
ordenar_colunas <- \(coleta, template) select(coleta, names(template))

resultados_unificados <- ordenar_colunas(resultados_unificados, template)
resultados_novos <- ordenar_colunas(resultados_novos, template)


# :: FORÇA TIPO DE TEMPLATE ----------------------------------------------------

# Certifica-se que os dataframes possuem colunas de mesmo tipo (para uní-los)
coerce_class <- \(coleta) mutate(coleta, across(everything(), \(x) as.character(x)))

resultados_unificados <- coerce_class(resultados_unificados)
resultados_novos <- coerce_class(resultados_novos)


# :: UNIFICA COLETAS -----------------------------------------------------------

file.rename(
  here(OUTPUT_DIR, "itens-resultados.csv"),
  here(OUTPUT_DIR, "itens-resultados.csv.old")
)

# Une os dados de contratações de todas as coletas.
itens_resultados <- bind_rows(resultados_unificados, resultados_novos)
itens_resultados <- distinct(itens_resultados)

# Salva o arquivo em formato rds
write_csv(itens_resultados, here(OUTPUT_DIR, "itens-resultados.csv"))
