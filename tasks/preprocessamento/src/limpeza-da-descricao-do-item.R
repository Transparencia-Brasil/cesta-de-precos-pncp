#' Este script ...

library(dplyr)        # Data manipulation
library(here)         # File referencing
library(stringr)      # String processing
library(stringi)      # String processing
library(tm)           # Text mining

# OBTÉM DADOS -------------------------------------------------------------

caminho <- here("data/pncp/medicamentos.rds")
medicamentos_df <- readRDS(caminho)

# LIMPA OS DADOS TEXTUAIS -------------------------------------------------

#' Processa um vetor de strings com as seguintes operações:
#' 1. Todas os caracteres ficam minúsculos
#' 2. Remove acentos (Examplo: à á â ã torna-se 'a', ç torna-se c, etc.)
#' 3. Remove pontuação
#' 4. Remove caracteres numéricos 
#' 5. Remove espaços em branco adicionais ("  a   b   c  " torna-se "a b c")
#' 
#' @param string_vector Um vetor de caracteres 
#'
#' @return O mesmo vetor com as strings transformadas.
#' @noRd
clean_text <- function(character_vector) {
  result <- character_vector %>%
    tolower() %>%                                # Todas os caracteres ficam minúsculos
    stri_trans_general(id = "Latin-ASCII") %>%   # Remove acentos
    str_replace_all("[[:punct:]]", " ") %>%      # Remove pontuação
    { gsub("[0-9]", "", .) } %>%                 # Remove caracteres numéricos
    str_squish()                                 # Remove espaços em branco adicionais
  
  result <- sapply(result, remove_stopwords)     # Remove stopwords
  return(result)
}

# FUNÇÕES AUXILIARES ------------------------------------------------------

#' Remove Stopwords de um texto.
#'
#' Esta função remove stopwords de uma dado texto. O pacote `tm` é utilizado para
#' criar um corpus e aplicar  a função `removeWords` com a lista de stopwords da
#' lingua portuguesa.
#'
#' @param text Um objeto do tipo Character.
#'
#' @return Um objeto semelhante ao passado como argumento, porém sem stopwords.
#' @noRd
remove_stopwords <- function(text) {
  corpus <- Corpus(VectorSource(text))
  corpus_clean <- tm_map(corpus, removeWords, stopwords("pt"))
  cleaned_text <- as.character(corpus_clean[[1]]) %>% str_squish()
  return(cleaned_text)
}

# EXECUTA A LIMPEZA -------------------------------------------------------

medicamentos_df <- medicamentos_df %>%
  mutate(clean_descricao <- clean_text(descricao))

medicamentos_df %>% saveRDS(caminho)