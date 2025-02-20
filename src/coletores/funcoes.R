#' Este arquivo contém as funções base que serão utilizadas para coletar os dados
#' de contratações, itens e resultados da API do PNCP. A função principal a ser 
#' evocada é `coleta()`, passando uma lista de endpoints a coletar como parâmetro.
#' As demais funções são utilizadas dentro de `coleta`.
#' 

library(dplyr)
library(httr2)
library(here)
library(lubridate)
library(jsonlite)
library(readr)
library(data.table)

#' Faz uma requisição a um endpoint e retorna os dados em formato de dataframe
#'
#' @description
#' Esta função realiza uma requisição HTTP GET para o endpoint fornecido, captura possíveis erros
#' e retorna os dados da resposta em um dataframe.
#'
#' @param endpoint Uma string contendo a URL do endpoint a ser consultado.
#'
#' @return Um dataframe contendo os dados retornados pelo endpoint, acrescido de uma coluna:
#'   - `endpoint`: a URL do endpoint consultado.
#'
#' @details
#' A função utiliza a biblioteca `httr2` para realizar a requisição. O corpo da resposta é
#' convertido de JSON para um dataframe. Em caso de erro na requisição, a função captura
#' automaticamente a falha com `req_error()`.
#'
#' @import httr2 jsonlite
#' @export
#'
#' @examples
#' 
#' # Exemplo de uso da função
#' df <- coleta_endpoint("https://api.exemplo.com/dados")
#' print(df)
coleta_endpoint <- function(endpoint) {
  # Faz a requisição ao endpoint
  resposta <- request(endpoint) %>%
    req_method("GET") %>%
    req_headers(accept = "*/*") %>%
    req_error() %>%  # Captura erros se houver
    req_perform()
  
  # Converte a resposta da requisicao em um dataframe
  df_itens <- resp_body_string(resposta) %>% fromJSON(flatten = TRUE) %>% as.data.frame()
  df_itens$endpoint <- endpoint
  return(df_itens)
}


#' Salva os resultados da coleta no diretório passado como argumento.
#'
#' A função `salva_resultados()` coloca os três arquivos CSV resultantes da coleta
#' contendo dados, erros e monitoramento dentro de `output_dir`.
#'
#' @param output_dir Caminho base onde os arquivos serão armazenados.
#' Se o diretório não existir, ele será criado.
#'
#' @details
#' - A função verifica se o diretório correspondente à `output_dir` já existe.
#' - Se o diretório não existir, ele será criado.
#' - Os arquivos são armazenados em `output_dir`.
#'
#' @return A função não retorna valores diretamente. Os arquivos são salvos no disco.
#'
#' @note Certifique-se de que `PATH_DADOS`, `PATH_ERROS` e `PATH_MONITORAMENTO` estão definidos antes de chamar a função.
#' 
#' @examples
#' # Exemplo de uso:
#' salva_resultados("meu_diretorio")
salva_resultados <- function(output_dir) {
  
  # Cria o diretório de saída, caso não exista
  if (!dir.exists(output_dir)) { 
    dir.create(output_dir, recursive = TRUE) 
  }
  
  file.copy(PATH_DADOS, here(output_dir, "dados.csv"), overwrite = TRUE)
  file.copy(PATH_ERROS, here(output_dir, "erros.csv"), overwrite = TRUE)
  file.copy(PATH_MONITORAMENTO, here(output_dir, "monitoramento.csv"), overwrite = TRUE)
  
  # Apaga o diretório temporário
  unlink(PATH_DIR_TEMP, recursive = TRUE, force = TRUE)
}


#' Coleta dados de uma lista de endpoints e salva os resultados
#'
#' A função `coleta()` acessa uma lista de endpoints, recupera os dados e armazena os resultados em arquivos `.csv` e `.rds`. 
#' Também registra erros e monitoramento do processo.
#'
#' @param endpoints Vetor de URLs ou identificadores dos endpoints a serem coletados.
#' @param output_dir Caminho do diretório onde os resultados serão salvos. O padrão é `"coleta"` na raiz do projeto.
#' @param tamanho_lote Número de requisições processadas antes de salvar os dados no disco. O padrão é 1000.
#'
#' @details
#' - A coleta é retomada de onde parou, verificando quais endpoints já foram processados.
#' - Os dados são salvos em arquivos `.csv` e, ao final, convertidos para `.rds`.
#' - Registra logs de monitoramento e erros durante a execução.
#' - A cada lote, os dados são salvos e a memória é liberada para otimizar o desempenho.
#'
#' @return A função não retorna valores diretamente, mas salva os dados coletados no diretório especificado.
#'
#' @examples
#' # Coletar dados de uma lista de endpoints
#' endpoints <- c("https://api.example.com/dado1", "https://api.example.com/dado2")
#' coleta(endpoints, output_dir = "dados_coletados", tamanho_lote = 500)
coleta <- function(endpoints, output_dir = here("coleta"), tamanho_lote = 1000) {
  
  #' Verifica o progresso da coleta de dados e retorna endpoints pendentes
  #'
  #' A função `checkpoint()` cria um diretório temporário se ele não existir e verifica 
  #' se já há dados coletados previamente. Caso existam, identifica quais endpoints ainda 
  #' não foram processados e retorna apenas os pendentes.
  #'
  #' @return Vetor de endpoints que ainda não foram coletados.
  #' Se nenhum dado prévio for encontrado, retorna a lista completa de endpoints.
  #' 
  #' @details 
  #' - Se o diretório temporário (`PATH_DIR_TEMP`) não existir, ele será criado.
  #' - Se o arquivo com dados (`PATH_DADOS`) existir, ele será lido para verificar os endpoints já coletados.
  #' - Apenas os endpoints ainda não processados serão retornados.
  #'
  #' @examples
  #' # Exemplo de uso:
  #' endpoints_pendentes <- checkpoint()
  #' print(endpoints_pendentes)
  #'
  #' @note Certifique-se de que `PATH_DIR_TEMP`, `PATH_DADOS` e `endpoints` estão definidos antes de chamar a função.
  checkpoint <- function() {
    # Cria o diretório temporário caso não exista
    if (!dir.exists(PATH_DIR_TEMP)) { 
      dir.create(PATH_DIR_TEMP, recursive = TRUE) 
    } else {
      # Verifica se já existe um arquivo com resultados anteriores
      if (file.exists(PATH_DADOS)) {
        dados_coletados <- read.csv(PATH_DADOS, stringsAsFactors = FALSE)
        
        # Identifica os endpoints que ainda não foram coletados
        endpoints_coletados <- unique(dados_coletados$endpoint)
        endpoints_restantes <- setdiff(endpoints, endpoints_coletados)
        return(endpoints_restantes)
      }
    }
    return(endpoints)
  }
  
  # Cria o diretório de saída, caso não exista
  if (!dir.exists(output_dir)) { 
    dir.create(output_dir, recursive = TRUE) 
  }
  
  # Caminho para o diretório temporário de resultados parciais
  PATH_DIR_TEMP <<- here(output_dir, "temp")
  
  # Caminho para o arquivo de dados coletados
  PATH_DADOS <<- here(PATH_DIR_TEMP, "dados.csv")
  
  # Caminho para o arquivo de requisições com erro
  PATH_ERROS <<- here(PATH_DIR_TEMP, "erros.csv")
  
  # Caminho para o arquivo de monitoramento da coleta
  PATH_MONITORAMENTO <<- here(PATH_DIR_TEMP, "monitoramento.csv")
  
  # Retoma a coleta de onde parou
  endpoints_restantes <- checkpoint()
  
  # Inicializa dataframe para armazenar dados
  df_dados <- data.frame()
  
  # Inicializa dataframe para armazenar erros
  df_erros <- data.frame()
  
  # Inicializa dataframe para monitoramento da coleta
  df_monitoramento <- data.frame()
  
  # Total de lotes restantes
  total_lotes <- ceiling(length(endpoints_restantes) / tamanho_lote)
  
  # Marca o tempo inicial do lote
  inicio_lote <- Sys.time()
  
  # Loop para processar os endpoints pendentes
  for (i in seq_along(endpoints_restantes)) {
    endpoint <- endpoints_restantes[i]
    
    # Tenta coletar os dados e trata erros
    tryCatch({
      resposta <- coleta_endpoint(endpoint)
      # Adiciona os dados coletados ao dataframe de dados
      df_dados <- bind_rows(df_dados, resposta)
      
    }, error = function(e) {
      # Se houve erro, adicionar ao dataframe de erros
      print(e$message)
      df_erros <<- bind_rows(df_erros, data.frame(
        endpoint = endpoint,
        mensagem_erro = as.character(e$message),
        stringsAsFactors = FALSE
      ))
    })
    
    # A cada fim de lote, salvar os resultados no disco
    if (i %% tamanho_lote == 0 || i == length(endpoints_restantes)) {
      # Marca o fim do lote
      fim_lote <- Sys.time()
      
      # Salvar o monitoramento do tempo
      df_monitoramento <- bind_rows(df_monitoramento, data.frame(
        lote = ceiling(i / tamanho_lote),
        tamanho = tamanho_lote,
        inicio = inicio_lote,
        fim = fim_lote,
        duracao = as.numeric(difftime(fim_lote, inicio_lote, units = "secs")),
        stringsAsFactors = FALSE
      ))
      
      # Salva os resultados parciais
      fwrite(df_dados, PATH_DADOS, sep = ",", row.names = FALSE, col.names = !file.exists(PATH_DADOS), append = TRUE, quote = TRUE)
      fwrite(df_erros, PATH_ERROS, sep = ",", row.names = FALSE, col.names = !file.exists(PATH_ERROS), append = TRUE, quote = TRUE)
      fwrite(df_monitoramento, PATH_MONITORAMENTO, sep = ",", row.names = FALSE, col.names = !file.exists(PATH_MONITORAMENTO), append = TRUE, quote = TRUE)
      
      # Limpa a memoria antes do garbage collector
      rm(df_dados)
      rm(df_erros)
      rm(df_monitoramento)
      
      # Reinicializa os dataframes de dados, erros e monitoramento
      df_dados <- data.frame()
      df_erros <- data.frame()
      df_monitoramento <- data.frame()
      
      # Monitoramento do progresso
      lotes_restantes <- total_lotes - ceiling(i / tamanho_lote)
      cat("Salvo o lote até o endpoint número:", i, "\n")
      cat("Lotes restantes:", lotes_restantes, "\n")
      inicio_lote <- Sys.time()
    }
    
    # Informa o progresso da coleta
    cat(sprintf("Endpoint %d coletado", i), "\r")
    flush.console()
    # Pausar brevemente entre as requisições para evitar sobrecarregar o servidor
    Sys.sleep(0.5)
  }
  
  # Ao final da coleta, transfere os arquivos .csv para o diretório de saída
  salva_resultados(output_dir)
}
