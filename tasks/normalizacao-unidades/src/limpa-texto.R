#' Este arquivo contém funções para a limpeza textual do campo unidadeMedida

library(dplyr)        # Data manipulation
library(stringr)      # String processing
library(stringi)      # String processing

#' Processa um vetor de strings com as seguintes operações:
#' 1. Substitui traços, barras e parênteses por espaço vazio 
#' 2. Todas os caracteres ficam minúsculos
#' 3. Remove acentos (Examplo: à á â ã torna-se 'a', ç torna-se c, etc.)
#' 4. Remove espaços em branco adicionais ("  a   b   c  " torna-se "a b c")
#' 
#' @param string_vector Um vetor de caracteres 
#'
#' @return O mesmo vetor com as strings transformadas.
clean_text <- function(character_vector) {
  result <- gsub("[-/()]", " ", character_vector) %>% # Substitui traços, barras e parênteses por espaço vazio 
    tolower() %>%                                # Todas os caracteres ficam minúsculos
    stri_trans_general(id = "Latin-ASCII") %>%   # Remove acentos
    str_replace_all("[[:punct:]]", " ") %>%  # Substitui qualquer pontuação por espaço vazio
    str_squish()                                 # Remove espaços em branco adicionais
  
  return(result)
}

#' Remove caracteres de pontuação de um vetor de strings
#' OBS: Essa etapa é separada de clean_text pois ao limpar o texto, não queremos
#' remover as vírgulas e pontos decimais.
#'
#' @param character_vector Um vetor de caracteres
#'
#' @return O mesmo vetor, porém sem caracteres de pontuação em seus elementos.
remove_pontuacao <- function(character_vector) {
  character_vector %>%
    str_replace_all("[[:punct:]]", " ") %>%  # Substitui qualquer pontuação por espaço vazio
    str_squish()                             # Remove espaços vazios adicionais 
}