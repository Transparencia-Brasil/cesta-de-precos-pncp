#' Script para Extração e Processamento de Endpoints
#' Este script realiza a extração e o processamento de endpoints válidos a partir de um arquivo CSV contendo dados inconsistentes.
#'
#' O fluxo do script é o seguinte:
#' - 1. Carrega bibliotecas necessárias e define os caminhos para os arquivos CSV de entrada e saída.
#' - 2. Define a função `extrai_endpoint_valido`, que identifica e extrai o primeiro endpoint válido em uma linha de dados.
#' - 3. Lê o arquivo CSV de entrada e aplica a função para extrair endpoints válidos, adicionando-os como uma nova coluna.
#' - 4. Filtra os dados para manter apenas as linhas com endpoints válidos.
#' - 5. Processa os endpoints para extrair o número do item e ajustar o formato do endpoint.
#' - 6. Salva os resultados processados em um novo arquivo CSV.

library(tidyverse)
library(here)

PATH_CSV <- here("coleta-resultados", "inconsistentes.csv")
PATH_CSV_ENDPOINT <- here("coleta-resultados", "endpoints.csv")

#' @title Extrai Endpoint Válido
#' @description Função para extrair o primeiro endpoint válido de uma linha de dados.
#' @param row Linha de dados (vetor) onde será buscado o padrão do endpoint.
#' @return O primeiro endpoint válido encontrado ou `NA` se nenhum for encontrado.
extrai_endpoint_valido <- function(row) {
  # Verifica se alguma coluna da linha contém o padrão
  match <- str_extract(row, "https...pncp\\.gov\\.br.api.pncp.v1.orgaos.\\d+.compras.\\d{4}.\\d+.itens.\\d+.resultados")
  # Retorna o primeiro match encontrado ou NA
  match[!is.na(match)][1]
}

# Lê o arquivo CSV de entrada e aplica a função `extrai_endpoint_valido` para extrair os endpoints válidos
endp <- read_csv(PATH_CSV) %>%
  mutate(endpoint_restaurado = apply(., 1, extrai_endpoint_valido))

# Filtra as linhas com endpoints válidos, processa os dados e salva em um novo arquivo CSV
endp <- endp %>%
  filter(!is.na(endpoint_restaurado)) %>%
  select(endpoint = endpoint_restaurado) %>%
  # Adiciona uma nova coluna com o número do item extraído do endpoint
  mutate(
    numeroItem = str_extract(endpoint, "(?<=\\/)[0-9]+(?=\\/resultados)"),
    endpoint = str_remove(endpoint, "\\/[0-9]+\\/resultados")
  )

# Salva os resultados processados no arquivo CSV de saída
write_csv(endp, PATH_CSV_ENDPOINT)
