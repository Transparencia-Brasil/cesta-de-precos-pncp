#' Este script é responsável pela normalização das unidades de medida dos itens
#' das contratações do PNCP.
#' A campo unidadeMedida idealmente seria composto por 3 elementos:
#' 1. O tipo de invólucro do medicamento, isto é, a unidade de fornecimento (Ex. ampola);
#' 2. A capacidade (quantidade) (Ex. 20);
#' 3. A unidade de medida (Ex. ml ou mililitros).
#' 
#' As unidades de fornecimento e de medida padrões vêm do catálogo de materiais (CATMAT)
#' 

library(dplyr)        # Data manipulation
library(tidyr)        # Tidy messy data
library(here)         # File referencing
library(stringr)      # String processing

source(here("tasks/normalizacao-unidades/src/limpa-texto.R"))
source(here("tasks/normalizacao-unidades/src/define-unidades-padronizadas.R"))

# OBTÉM DADOS -------------------------------------------------------------

caminho_medicamentos <- here("data/pncp/medicamentos.rds")
medicamentos_df <- readRDS(caminho_medicamentos)

# LIMPA O TEXTO -----------------------------------------------------------

# Limpa o campo textual unidadeMedida
medicamentos_df$clean_unidadeMedida = clean_text(medicamentos_df$unidadeMedida)

# SEPARA OS ELEMENTOS QUE COMPÕEM O CAMPO unidadeMedida -------------------

#' OBS: As unidades de fornecimento "frasco-ampola", milheiro de cartelas" e 
#' "milheiro unid.intern" serão tratadas de forma diferente pois o algoritmo 
#' só funciona para palavras individuais.

#' OBS: As unidades de medida "mil unid. intern.", "unid. internacional" e 
#' "milhao unid. intern." serão tratadas de forma diferente pois o algoritmo só 
#' funciona para palavras individuais.

## CAPACIDADE -------------------------------------------------------------

# Extrai o último número encontrado em unidadeMedida usando expressão regular
# O último número é selecionado pois as vezes a capacidade aparece repetida,
# por exemplo: fr 10ml (fr 10ml)
medicamentos_df <- medicamentos_df %>%
  mutate(
    capacidadeUnidadeMedida = str_extract_all(clean_unidadeMedida, "\\d+([.,]\\d+)?") %>% # Encontra todos os números
      lapply(tail, 1) %>%   # Obtém apenas o último número encontrado
      sapply(function(x) ifelse(length(x) == 0, NA, x)) %>%  # Substitui valores vazios por NA
      str_replace(",", ".") %>%   # Substitui vírgula por ponto
      as.numeric()   # Converte para numérico
  )

print(
  paste(
    "Porcentagem de valores NÃO vazios em capacidadeUnidadeMedida",
    sum(!is.na(medicamentos_df$capacidadeUnidadeMedida))/nrow(medicamentos_df) # 24%
  )
)

# Remove os números da unidadeMedida para analisar apenas os tokens restantes
medicamentos_df$clean_unidadeMedida <- gsub("\\d+([.,]\\d+)?", " ", medicamentos_df$clean_unidadeMedida) %>%
  str_replace_all("[[:punct:]]", " ") %>% # Remove qualquer pontuação restante
  str_squish() # Remove espaços vazios adicionais
  

## UNIDADE DE FORNECIMENTO -----------------------------------------------

### PROCESSA AS EXCEÇÕES -------------------------------------------------
#' As exceções são frasco-ampola (fr-am), milheiro de cartelas (mil cte) e 
#' milheiro unid. intern (mil ui)

#cria a coluna nomeUnidadeFornecimento
medicamentos_df$nomeUnidadeFornecimento <- NA

# Identifica os casos de frasco-ampola (fr-am)
medicamentos_df <- medicamentos_df %>% 
  mutate(
    nomeUnidadeFornecimento = ifelse(
      grepl("frasco ampola|fr am|frascos ampola", clean_unidadeMedida, ignore.case = TRUE),
      "frasco-ampola",
      nomeUnidadeFornecimento
    )
  )

# Identifica os casos de milheiro de cartelas (mil cte)
medicamentos_df <- medicamentos_df %>% 
  mutate(
    nomeUnidadeFornecimento = ifelse(
      grepl("milheiro de cartelas|mil cte|milheiros de cartelas", clean_unidadeMedida, ignore.case = TRUE),
      "milheiro de cartelas",
      nomeUnidadeFornecimento
    )
  )

# Identifica os casos de milheiro unid. intern (mil ui)
medicamentos_df <- medicamentos_df %>% 
  mutate(
    nomeUnidadeFornecimento = ifelse(
      grepl("milheiro unid intern|mil ui|milheiros unid intern", clean_unidadeMedida, ignore.case = TRUE),
      "milheiro unid. intern",
      nomeUnidadeFornecimento
    )
  )

### PROCESSA OS DEMAIS CASOS ----------------------------------------------

#' Detecta se alguma unidade de fornecimento padrão (do CATMAT) está presente 
#' em uma string.
#' 
#' @param texto A string na qual será procurada as unidades de fornecimento. 
#' Tipicamente deve ser uma valor do campo unidadeMedida do PNCP.
#'
#' @return Uma string contendo a unidade de fornecimento encontrada ou NA caso nenhuma
#' unidade de fornecimento seja encontrada.
#'
#' @examples
#' extrai_unidade_fornecimento("Frasco 1000 ML")
#' Retorna: [1] "frasco"
extrai_unidade_fornecimento <- function(texto) {
  lookup_map <- uf_env                    # Lookup hashtable (cópia no escopo local)
  tokens <- strsplit(texto, " ")           # Separa o texto em tokens
  
  unidade_fornecimento <- NA
  
  for (token in unlist(tokens)) {         # itera sobre a lista de tokens
    if (!is.null(lookup_map[[token]])) {   # Se o token estiver no mapa de pesquisa retorna a unidade de fornecimento
      unidade_fornecimento <- lookup_map[[token]]
    } 
  }
  
  return(unidade_fornecimento)
}

# Identifica as unidades de fornecimento para os casos que ainda não foram identificados
medicamentos_df <- medicamentos_df %>% 
  rowwise() %>%
  mutate(
    nomeUnidadeFornecimento = ifelse(
      is.na(nomeUnidadeFornecimento),
      extrai_unidade_fornecimento(clean_unidadeMedida),
      nomeUnidadeFornecimento
    )
  ) %>%
  ungroup()

print(
  paste(
    "Porcentagem de valores NÃO vazios em nomeUnidadeFornecimento",
    sum(!is.na(medicamentos_df$nomeUnidadeFornecimento))/nrow(medicamentos_df) # 61%
  )
)

## UNIDADE DE MEDIDA -----------------------------------------------------

### PROCESSA AS EXCEÇÕES -------------------------------------------------
#' As exceções são mil unid. intern. (kui), unid. internacional (ui) e 
#' milhao unid. intern. (mui)

#cria a coluna nomeUnidadeMedida
medicamentos_df$nomeUnidadeMedida <- NA

# Identifica os casos de mil unid. intern. (kui)
medicamentos_df <- medicamentos_df %>% 
  mutate(
    nomeUnidadeMedida = ifelse(
      grepl("mil unid intern|kui", clean_unidadeMedida, ignore.case = TRUE),
      "mil unid. intern.",
      nomeUnidadeMedida
    )
  )

# Identifica os casos de unid. internacional (ui)
# Como a string "ui" pode ser bem comum iremos nos certificar de que ela aparece
# rodeada por espaços vazios para garantir que é realmente a palavra "ui"
medicamentos_df <- medicamentos_df %>% 
  mutate(
    clean_unidadeMedida = paste0(clean_unidadeMedida, " "), # adiciona espaco vazio ao final
    nomeUnidadeMedida = ifelse(
      grepl("unid internacional| ui ", clean_unidadeMedida, ignore.case = TRUE),
      "unid. internacional",
      nomeUnidadeMedida
    ),
    clean_unidadeMedida = str_squish(clean_unidadeMedida) # remove espaços vazios adicionais
  )

# Identifica os casos de milhao unid. intern. (mui)
medicamentos_df <- medicamentos_df %>% 
  mutate(
    nomeUnidadeMedida = ifelse(
      grepl("milhao unid intern|mui|milhoes unid intern", clean_unidadeMedida, ignore.case = TRUE),
      "milheiro unid. intern",
      nomeUnidadeMedida
    )
  )

### PROCESSA OS DEMAIS CASOS ----------------------------------------------

#' Detecta se alguma unidade de medida padrão (do CATMAT) está presente 
#' em uma string.
#' 
#' @param texto A string na qual será procurada as unidades de medida. 
#' Tipicamente deve ser uma valor do campo unidadeMedida do PNCP.
#'
#' @return Uma string contendo a unidade de medida encontrada ou NA caso nenhuma
#' unidade de medida seja encontrada.
#'
#' @examples
#' extrai_unidade_medida("Frasco 1000 ML")
#' Retorna: [1] "mililitro"
extrai_unidade_medida <- function(texto) {
  lookup_map <- um_env                    # Lookup hashtable (cópia no escopo local)
  tokens <- strsplit(texto, " ")           # Separa o texto em tokens
  
  unidade_medida <- NA
  
  for (token in unlist(tokens)) {         # itera sobre a lista de tokens
    if (!is.null(lookup_map[[token]])) {   # Se o token estiver no mapa de pesquisa retorna a unidade de medida
      unidade_medida <- lookup_map[[token]]
    } 
  }

  return(unidade_medida)
}

# Identifica as unidades de medida para os casos que ainda não foram identificados
medicamentos_df <- medicamentos_df %>% 
  rowwise() %>%
  mutate(
    nomeUnidadeMedida = ifelse(
      is.na(nomeUnidadeMedida),
      extrai_unidade_medida(clean_unidadeMedida),
      nomeUnidadeMedida
    )
  )

print(
  paste(
    "Porcentagem de valores NÃO vazios em nomeUnidadeMedida",
    sum(!is.na(medicamentos_df$nomeUnidadeMedida))/nrow(medicamentos_df) # 44%
  )
)


# SALVA RESULTADOS --------------------------------------------------------

medicamentos_df %>% 
  select(-clean_unidadeMedida) %>%
  saveRDS(here("tasks/normalizacao-unidades/outputs/medicamentos.rds"))
