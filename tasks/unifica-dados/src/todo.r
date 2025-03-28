

# TODO:
# - gerar chave ssh -> OK!
# - consertar ids de endpoints = NA -> OK!
# - Separar endpoints missing -> OK!
# - gerar embeddings desses endpoints = -> NA OK!
# - reunir a base novamente -> OK!
# - anti-join com resultados-tens para saber quais resultados serão consultados e coletados
# - fazer a recoleta (usar "src\ETL\coletores\coleta-resultados.R")
# - reune recoleta de resultados com resultados previamente coletados
# - rodar coleta de janeiro/2025 (30 dias)
# - rodar coleta de fevereiro/2025 (2 coletas de 14 dias)

itens <- read_csv(here(OUTPUT_DIR, "itens.csv"))
resultados <- read_csv(here(OUTPUT_DIR, "itens-resultados.csv"))
medicamentos <- read_csv(here(OUTPUT_DIR, "medicamentos.csv"))

itens %>% glimpse()
resultados %>% glimpse()
medicamentos %>% glimpse()

medicamentos %>%
  filter(numeroControlePNCPCompra %in% unique(resultados$numeroControlePNCPCompra))

#' semi_join()' return all rows from 'x' with a match in 'y'.
medicamentos %>%
  semi_join(resultados, by = c("numeroControlePNCPCompra", "numeroItem"))

#' 'anti_join()' return all rows from 'x' with*out* a match in 'y'.
medicamentos %>%
  anti_join(resultados, by = c("numeroControlePNCPCompra", "numeroItem"))
library(tidyverse)
read_csv(here::here("coleta/itens/itens.csv"))



pncp



# ITENS RESULTADOS INCONSISTENTES

library(tidyverse)
library(here)

# RDS's
ITENS_RESULTADOS2_PATH <- "tasks/unifica-dados/input/itens2-resultados.rds"
ITENS_RESULTADOS3_PATH <- "tasks/unifica-dados/input/itens3-resultados.rds"

# itens-resultados remanescentes
PATH_RESULTADOS_NOVOS <- here("coleta/resultados/dados.csv")

resultados <- map(c(ITENS_RESULTADOS2_PATH, ITENS_RESULTADOS3_PATH), readRDS) %>%
  set_names(c("itens2", "itens3"))

resultados$itensNovos <- read_csv(PATH_RESULTADOS_NOVOS)
resultados$itensSubset <- read_csv(PATH_RESULTADOS_NOVOS)

resultados$itens2 %>% glimpse()
resultados$itens3 %>% glimpse()
resultados$itensNovos %>% glimpse()


# os arquivos unificados ficarão salvos na pasta "output"
OUTPUT_DIR <- "tasks/unifica-dados/output"

itens_resultados <- read_csv(here(OUTPUT_DIR, "itens-resultados.csv"))


coleta1 <- resultados$itens2 %>%
  select(endpoint)

# separa as coletas que estão boas
coleta1_tratados <- itens_resultados %>% semi_join(coleta1)

# separa as coletas que estão ruins
inconsistentes <- itens_resultados %>% anti_join(coleta1)

tmp <- tempfile(pattern = "_inconsistentes", fileext = ".csv")

inconsistentes %>% write_csv(tmp)


coleta1_tratados %>% glimpse()

coleta1_tratados %>%
  count(situacaoCompraItemResultadoNome, sort = TRUE) %>%
  View()

coleta1_tratados %>%
  count(porteFornecedorId, porteFornecedorNome, sort = TRUE) %>%
  View()

coleta1_tratados %>%
  count(tipoPessoa, sort = TRUE) %>%
  View("tipoPessoa")

coleta1_tratados %>%
  count(codigoPais, sort = TRUE) %>%
  View("codigoPais")

resultados$itensNovos %>%
  count(porteFornecedorId, porteFornecedorNome, sort = TRUE) %>%
  View()

resultados$itensNovos %>%
  filter(porteFornecedorId == "BRA") %>%
  glimpse()



resultados$itensNovos %>%
  filter(numeroControlePNCPCompra == "18306662000150-1-000024/2023") %>%
  glimpse() %>%
  pull(endpoint)


# itens-resultados remanescentes
PATH_RESULTADOS_NOVOS_SUBSET <- here("coleta/resultados/dados.csv")

resultados$itensNovos %>%
  filter(numeroControlePNCPCompra == "18306662000150-1-000024/2023") %>%
  write_csv(PATH_RESULTADOS_NOVOS_SUBSET)

resultados$itensSubset

coleta("https://pncp.gov.br/api/pncp/v1/orgaos/18306662000150/compras/2023/24/itens/7/resultados", here())


resultados$itensNovos %>%
  filter(porteFornecedorId == "BRA") %>%
  slice(1:100) %>%
  pull(endpoint) %>%
  coleta(here(), tamanho_lote = 5)

resultados_100endp <- read_csv("dados.csv")

resultados_100endp %>%
  View()

resultados_100endp %>%
  count(situacaoCompraItemResultadoNome, sort = TRUE) %>%
  View()

resultados_100endp %>%
  count(porteFornecedorId, porteFornecedorNome, sort = TRUE) %>%
  View()

resultados_100endp %>%
  count(tipoPessoa, sort = TRUE) %>%
  View("tipoPessoa")

resultados_100endp %>%
  count(codigoPais, sort = TRUE) %>%
  View("codigoPais")

resultados_100endp %>%
  # count(porteFornecedorId, porteFornecedorNome, sort = TRUE) %>%
  View()


#
