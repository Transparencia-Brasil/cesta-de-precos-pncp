#' Este arquivo contém funções para a limpeza textual do campo unidadeMedida

library(dplyr)        # Data manipulation
library(stringr)      # String processing
library(stringi)      # String processing

#' Limpeza de Texto
#'
#' Esta função realiza a limpeza de um texto, removendo caracteres numéricos e acentos,
#' convertendo para minúsculas, eliminando pontuações e espaços extras.
#'
#' @param texto Uma string ou vetor de strings a serem limpas.
#' @return Uma string ou vetor de strings com o texto limpo.
#' @import stringi stringr dplyr
#' @examples
#' limpa_texto("Exemplo: João comprou pão (e leite) - incrível!")
#' # Retorna: "exemplo joao comprou pao e leite incrivel"
limpa_texto <- function(texto) {
  result <-  gsub("(?<!\\d)[[:punct:]]|[[:punct:]](?!\\d)", "", texto, perl = TRUE) %>% # Remover pontuações, exceto ponto e vírgula decimais
    tolower() %>%                              # Todas os caracteres ficam minúsculos
    stri_trans_general(id = "Latin-ASCII") %>% # Remove acentos
    str_squish()                               # Remove espaços em branco adicionais
  
  return(result)
}


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

#' Converte uma Lista Aninhada em uma Estrutura de Ambientes (hashtable).
#'
#' Esta função converte recursivamente uma lista aninhada em uma estrutura de 
#' ambientes (environments), onde cada nível da lista é mapeado para um ambiente.
#'
#' @param lst Uma lista nomeada, que pode conter outras listas aninhadas.
#' @return Um ambiente (`environment`) onde cada chave corresponde a um elemento 
#'         da lista original. Listas aninhadas são transformadas em ambientes,
#'         enquanto valores atômicos (ex.: vetores) são armazenados diretamente.
#' @examples
#' # Exemplo de lista aninhada
#' lista_aninhada <- list(
#'   "item1" = list(
#'     "frasco" = list("ml" = c(20, 50)),
#'     "cx" = list("kg" = c(10))
#'   ),
#'   "item2" = list(
#'     "galão" = list("l" = c(5)),
#'     "caixa" = list("un" = c(100))
#'   )
#' )
#'
#' # Converter a lista em uma estrutura de ambientes
#' estrutura_env <- list_to_env(lista_aninhada)
#'
#' # Acessando valores
#' get("item1", estrutura_env)  # Ambiente contendo "frasco" e "cx"
#' get("frasco", get("item1", estrutura_env))  # Ambiente contendo "ml"
#' get("ml", get("frasco", get("item1", estrutura_env)))  # c(20, 50)
#' 
list_to_env <- function(lst) {
  env <- new.env(hash = TRUE, parent = emptyenv())
  
  for (key in names(lst)) {
    value <- lst[[key]]
    
    if (is.list(value)) {
      assign(key, list_to_env(value), envir = env)  # Recursão para sub-listas
    } else {
      assign(key, value, envir = env)  # Atribuição direta para valores simples
    }
  }
  
  return(env)
}
