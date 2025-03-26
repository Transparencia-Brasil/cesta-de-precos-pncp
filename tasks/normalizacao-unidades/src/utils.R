#' Este arquivo contém funções úteis no destrinchamento das unidades

library(dplyr)        # Data manipulation
library(stringr)      # String processing
library(stringi)      # String processing

#' Limpa e normaliza um texto
#'
#' @description A função `limpa_texto` realiza a limpeza e normalização de um texto, 
#' removendo pontuações (exceto as usadas em números decimais), convertendo para 
#' minúsculas, removendo acentos e eliminando espaços extras e separando números de palavras.
#'
#' @param texto `character` String de entrada que será processada.
#'
#' @return Um vetor de caracteres (`character vector`) contendo o texto limpo.
#'
#' @details
#' O processamento da string ocorre em cinco etapas principais:
#' 1. **Remoção de pontuação**: Remove caracteres de pontuação, exceto ponto (`.`) e vírgula (`,`) 
#'    quando usados em números.
#' 2. **Separação de números e palavras**: Adiciona um espaço entre letras e números para garantir 
#'    que unidades de medida e valores numéricos sejam corretamente segmentados.
#' 3. **Conversão para minúsculas**: Todos os caracteres são convertidos para letras minúsculas.
#' 4. **Remoção de acentos**: Caracteres acentuados são convertidos para suas versões sem acento.
#' 5. **Remoção de espaços extras**: Espaços desnecessários no início, no final ou múltiplos espaços são eliminados.
#'
#' @examples
#' texto <- "Ácido Acetilsalicílico 500mg, comprimido!"
#' texto_limpo <- limpa_texto(texto)
#' print(texto_limpo)
#' # Saída: "acido acetilsalicilico 500 mg comprimido"
#'
#' @import stringr
#' @import stringi
limpa_texto <- function(texto) {
  result <-  gsub("(?<!\\d)[[:punct:]]|[[:punct:]](?!\\d)", "", texto, perl = TRUE) %>% # Remove pontuações, exceto em números
    gsub("(?<=[a-zA-Z])(?=\\d)", " ", ., perl = TRUE) %>%  # Adiciona espaço entre letras e números
    gsub("(?<=\\d)(?=[a-zA-Z])", " ", ., perl = TRUE) %>%  # Adiciona espaço entre números e letras
    tolower() %>%                              # Todas os caracteres ficam minúsculos
    stri_trans_general(id = "Latin-ASCII") %>% # Remove acentos
    str_squish()                               # Remove espaços em branco adicionais
  
  return(result)
}

#' Tokeniza um texto preservando termos compostos específicos
#'
#' @description A função `tokeniza_unidades` recebe uma string e a divide em palavras, 
#' preservando determinados termos compostos que devem manter o espaço entre suas palavras.
#' Isso é útil para garantir que certas expressões não sejam separadas durante a tokenização.
#'
#' @param texto `character` String de entrada contendo a descrição a ser tokenizada.
#'
#' @return Um vetor de caracteres (`character vector`), onde cada elemento representa uma 
#' palavra ou termo composto da string original.
#'
#' @details
#' O funcionamento da função ocorre em três etapas principais:
#' 1. **Lista de termos preservados**: Define uma lista de termos compostos que não devem ser separados.
#' 2. **Substituição temporária**: Substitui os espaços dentro desses termos por um marcador temporário (`"_"`).
#' 3. **Tokenização e restauração**: Divide o texto e substitui os marcadores temporários pelos espaços originais.
#'
#' @examples
#' texto <- "fornecimento de mil ui por embalagem"
#' tokens <- tokeniza_unidades(texto)
#' print(tokens)
#' # Saída: ["fornecimento", "de", "mil ui", "por", "embalagem"]
#'
#' @import stringr
tokeniza_unidades <- function(texto) {
  # Lista de termos que devem manter o espaço
  termos_preservados <- c("milheiro de cartelas", "mil cte", "milheiros de cartelas",
                          "mil unid intern", "milhao unid intern", "milhoes unid intern",
                          "milheiro unidintern", "mil ui", "milheiros unid itern",
                          "unid internacional")
  
  # Substituir os espaços dentro dos termos por um marcador temporário
  for (termo in termos_preservados) {
    texto <- str_replace_all(texto, termo, str_replace_all(termo, " ", "_"))
  }
  
  # Separar as palavras normalmente
  palavras <- unlist(str_split(texto, " "))
  
  # Restaurar os espaços nos termos preservados
  palavras <- str_replace_all(palavras, "_", " ")
  
  return(palavras)
}
