#' Documentação do script
#' 

library(here)         # Referenciamento de arquivos
library(tidyr)        # Organiza dados bagunçados
library(dplyr)        # Manipulação de dados
library(purrr)        # Ferramentas de Programação Funcional
library(readr)        # Leitura de dados
library(progressr)    # Atualizações de progresso
library(stringr)      # Operações em string

# Funções úteis
source(here("tasks/normalizacao-unidades/src/utils.R"))

handlers(global = TRUE) # Ativa o progresso globalmente

# CARREGA OS DADOS --------------------------------------------------------

CAMINHO_CATALOGO <- here("data/catmat/catmat.rds")
CAMINHO_MEDICAMENTOS <- here("tasks/unifica-dados/output/medicamentos.csv")

catmat <- readRDS(CAMINHO_CATALOGO)
medicamentos <- read_csv(CAMINHO_MEDICAMENTOS) %>% select(-embedding)


# LIMPA OS TEXTOS DO CATMAT -----------------------------------------------

# Desaninha a coluna unidadeFornecimento do catmat
catmat_expandido <- catmat %>% unnest(unidadeFornecimento)

# Corrige erros ortográficos e redundâncias em unidades de fornecimento e medida
catmat_expandido <-  catmat_expandido %>%
  mutate(
    siglaUnidadeFornecimento = ifelse(
      siglaUnidadeFornecimento %in% c("DOSE(S)", "DOSES"),
      "DOSE",
      siglaUnidadeFornecimento
    ),
    nomeUnidadeFornecimento = case_when(
      nomeUnidadeFornecimento == "(Doses)" ~ "dose",
      nomeUnidadeFornecimento == "Doses" ~ "dose",
      nomeUnidadeFornecimento == "Gigabecquerell" ~ "gigabecquerel",
      TRUE ~ nomeUnidadeFornecimento
    ),
    siglaUnidadeMedida = ifelse(siglaUnidadeMedida %in% c("DOSE(S)", "DOSES"), "DOSE", siglaUnidadeMedida),
    nomeUnidadeMedida = ifelse(nomeUnidadeMedida %in% c("(Doses)", "Doses"), "Dose", nomeUnidadeMedida)
  )

# Limpa os textos da unidades de fornecimento, de medida e respectivas siglas
catmat_expandido <- catmat_expandido %>%
  mutate(
    siglaUnidadeFornecimento = limpa_texto(siglaUnidadeFornecimento),
    nomeUnidadeFornecimento = limpa_texto(nomeUnidadeFornecimento),
    siglaUnidadeMedida = limpa_texto(siglaUnidadeMedida),
    nomeUnidadeMedida = limpa_texto(nomeUnidadeMedida),
  )


# UNIDADES DE MEDIDA COMO UNIDADES DE FORNECIMENTO ------------------------

#' Algumas unidades de medida estão como unidades de fornecimento (e.g. mililitro).
#' Esta seção identifica estas unidades e as coloca na coluna unidade de medida.

unidades <- data.frame(
  siglaUnidadeMedida = c(
    "ci",
    "dose",
    "g",
    "gbq",
    "kg",
    "l",
    "mbq",
    "mcg",
    "mcu",
    "mg",
    "ml",
    "mui",
    "mil ui",
    "ui",
    "un"
  ),
  nomeUnidadeMedida = c(
    "curie",
    "dose",
    "grama",
    "gigabecquerel",
    "quilograma",
    "litro",
    "megabecquerel",
    "micrograma",
    "milicurie",
    "miligrama",
    "mililitro",
    "milhao unid intern",
    "milheiro unidintern",
    "unid internacional",
    "unidade"
  )
)

#' Corrige os dados
#' Caso a unidade de fornecimento indicada seja na verdade uma das unidades de medida
#' listadas acima, o valor será movido para a coluna `nomeUnidadeMedida`, e a coluna
#' `nomeUnidadefornecimento` ficará como `NA`. O mesmo é feito para as siglas.
catmat_expandido <- catmat_expandido %>%
  mutate(
    siglaUnidadeMedida = ifelse(
      siglaUnidadeFornecimento %in% unidades$siglaUnidadeMedida &
        is.na(siglaUnidadeMedida),
      siglaUnidadeFornecimento,
      siglaUnidadeMedida
    ),
    nomeUnidadeMedida = ifelse(
      nomeUnidadeFornecimento %in% unidades$nomeUnidadeMedida &
        is.na(nomeUnidadeMedida),
      nomeUnidadeFornecimento,
      nomeUnidadeMedida
    ),
    siglaUnidadeFornecimento = ifelse(
      siglaUnidadeFornecimento %in% unidades$siglaUnidadeMedida,
      NA,
      siglaUnidadeFornecimento
    ),
    nomeUnidadeFornecimento = ifelse(
      nomeUnidadeFornecimento %in% unidades$nomeUnidadeMedida,
      NA,
      nomeUnidadeFornecimento
    )
  )

# ADICIONA OS PLURAIS -----------------------------------------------------

# Plurais das unidades de fornecimento (uf)
plurais_uf <- c(
  "ampola" = "ampolas",
  "bisnaga" = "bisnagas",
  "blister" = "blisteres",
  "bolsa" = "bolsas",
  "bombona" = "bombonas",
  "capsula" = "capsulas",
  "cartucho" = "cartuchos",
  "comprimido" = "comprimidos",
  "conjunto" = "conjuntos",
  "dragea" =  "drageas",
  "embalagem" = "embalagens",
  "emplastro" = "emplastros",
  "envelope" = "envelopes",
  "flaconete" =  "flaconetes",
  "frasco" =  "frascos",
  "frascoampola" =  "frascosampola",
  "galao" =  "galoes",
  "globulo" =  "globulos",
  "lata" =  "latas",
  "milheiro de cartelas" =  "milheiros de cartelas",
  "pastilha" = "pastilhas",
  "pote" =  "potes",
  "rolo" =  "rolos",
  "sache" =  "saches",
  "seringa" =  "seringas",
  "supositorio" =  "supositorios",
  "tablete" =  "tabletes",
  "tambor" = "tambores",
  "tubete" = "tubetes",
  "tubo" = "tubos"
)

# Plurais das unidades de medida (um)
plurais_um <- c(
  "centimetro" = "centimetros",
  "curie" =  "curies",
  "dose" =  "doses",
  "gigabecquerel" = "gigabecquerel", # invariável no plural
  "grama" = "gramas",
  "litro" = "litros",
  "litro" = "litros",
  "megabecquerel" = "megabecquerel", # invariável no plural
  "micrograma" = "microgramas",
  "microlitro" = "microlitros",
  "mil unid intern" = "mil unid intern",
  "milhao unid intern" = "milhoes unid intern",
  "milheiro unidintern" =  "milheiros unid itern",
  "milicurie" = "milicuries",
  "miligrama" = "miligramas",
  "mililitro" = "mililitros",
  "quilograma" = "quilogramas",
  "unid internacional" = "unid internacional",
  "unidade" = "unidades"
)

# Adiciona a coluna de plural da unidade de fornecimento
catmat_expandido$pluralUnidadeFornecimento <- plurais_uf[catmat_expandido$nomeUnidadeFornecimento]

# Adiciona a coluna de plural da unidade de medida
catmat_expandido$pluralUnidadeMedida <- plurais_um[catmat_expandido$nomeUnidadeMedida]


# CRIA DICIONÁRIOS DE CONSULTA --------------------------------------------

#' Explicação:
#' Para agilizar a identificação de unidades de fornecimento e unidades de medida
#' dos medicamentos, serão criado "dicionários" de consulta. Os dicionários são 
#' mapas entre as siglas, nomes e plurais das unidades e o nome da unidade. 
#' 
#' Por exemplo, para a unidade de fornecimento "bisnaga", teríamos os seguintes
#' pares de chave-valor no dicionário:
#' 
#' bis: bisnaga (sigla: nome)
#' bisnaga: bisnaga (nome: nome)
#' bisnagas: bisnaga (plural: nome)
#' 
#' Dessa forma ao detectarmos a sigla, nome ou plural da unidade de fornecimento
#' no texto do PNCP, identificaremos que a unidade é "bisnaga".
#' 
#' O mesmo é feito para as unidades de medida. Ao final, hverá 2 dicionários: 
#' um para unidades de fornecimento e outro para unidades de medida.


# Unidades de fornecimento, siglas e plurais
uf <- catmat_expandido %>% 
  select(nomeUnidadeFornecimento, siglaUnidadeFornecimento, pluralUnidadeFornecimento) %>% 
  drop_na() %>%
  distinct()

# dicionário para as unidades de fornecimento
uf_env <- new.env()

for (i in seq_len(nrow(uf))) {
  # Adiciona as siglas como chaves do dicionário e o nome como valor
  uf_env[[uf$siglaUnidadeFornecimento[i]]] <- uf$nomeUnidadeFornecimento[i]
  # Adiciona o nome também como chave e como valor
  uf_env[[uf$nomeUnidadeFornecimento[i]]] <- uf$nomeUnidadeFornecimento[i]
  # Adiciona o plural como chave e o nome como valor
  uf_env[[uf$pluralUnidadeFornecimento[i]]] <- uf$nomeUnidadeFornecimento[i]
}

# Unidades de medida, siglas e plurais
um <- catmat_expandido %>% 
  select(nomeUnidadeMedida, siglaUnidadeMedida, pluralUnidadeMedida) %>% 
  drop_na() %>%
  distinct()

# dicionário para as unidades de medida
um_env <- new.env()

for (i in seq_len(nrow(um))) {
  # Adiciona as siglas como chaves do dicionário e o nome como valor
  um_env[[um$siglaUnidadeMedida[i]]] <- um$nomeUnidadeMedida[i]
  # Adiciona o nome também como chave e como valor
  um_env[[um$nomeUnidadeMedida[i]]] <- um$nomeUnidadeMedida[i]
  # Adiciona o plural como chave e o nome como valor
  um_env[[um$pluralUnidadeMedida[i]]] <- um$nomeUnidadeMedida[i]
}

# LIMPA OS TEXTOS DO PNCP -------------------------------------------------

# Limpa o texto da descrição dos itens do PNCP
medicamentos$descricao_limpa <- limpa_texto(medicamentos$descricao)

# Limpa o texto da unidade de medida dos itens do PNCP
medicamentos$unidadeMedida_limpa <- limpa_texto(medicamentos$unidadeMedida)


# IDENTIFICA UNIDADES DE FORNECIMENTO -------------------------------------

#' Explicação:
#'
#' Algoritmo:
#' 1. Separa o texto do PNCP em uma lista de palavras. Exemplo:
#'   "Frasco 1000 ML"   torna-se:   ['Frasco', '1000', 'ML']
#'
#' 2. Cada palavra é então buscada no dicionário de unidades de fornecimento. Se
#' a palavra estiver presente como chave do dicionário, a unidade de fornecimento
#' foi detectada.
#'
#' Caso mais de uma unidade de fornecimento for detectada, a unidade de fornecimento
#' será marcada como "incerteza".
#'
#' Primeiro a busca é feita no campo `unidadeMedida` e caso nada seja encontrado,
#' a busca é feita no campo `descricao` do item.
#'
#' O mesmo se repete para as unidades de medida.
#'
#' A capacidade/quantidade fica por último. Geralmente, a capacidade vem logo antes da unidade
#' de medida (e.g "1000 ml"). Após ter identificado as unidades de medida, procura-se
#' o número imediatamente antecedente da unidade de medida. Caso nenhum número tenha sido
#' encontrado, usa-se o valor do campo `quantidade`.


#' Extrai a unidade de fornecimento (UF) de um texto
#'
#' A função identifica e extrai a unidade de fornecimento (UF) de um texto,
#' verificando tokens individuais em um ambiente (`uf_env`) que contém as unidades reconhecidas.
#' Se mais de uma unidade for encontrada, retorna `"incerteza"`.
#'
#' @param texto Uma string contendo o texto a ser analisado.
#' @return Uma string com a unidade de fornecimento identificada, `"incerteza"` caso haja múltiplas correspondências,
#' ou `NA` se nenhuma unidade for encontrada.
#' @examples
#' # Supondo que uf_env contém "frasco" -> "frasco" e "caixa" -> "caixa"
#' extrai_uf("frasco de 500ml")  # Retorna "frasco"
#' extrai_uf("bolsa contendo 10 frascos")  # Retorna "incerteza"
#' extrai_uf("produto sem unidade específica")  # Retorna NA
#' @seealso tokeniza_unidades
#' @export
extrai_uf <- function(texto) {
  # Verifica se o parâmetro é vazio ou nulo
  if (is.na(texto) | texto == "") {
    return(NA)
  }
  
  # Separa o texto em tokens
  tokens <- tokeniza_unidades(texto)
  
  count_uf <- 0  # Contagem de unidades de fornecimento
  uf <- NA       # Unidade de fornecimento
  
  # Verifica se o `texto` possui unidades de fornecimento
  for (token in tokens) {
    if (!is.null(uf_env[[token]])) {
      uf <- token
      count_uf <- count_uf + 1
    }
  }
  
  # Se houver mais de uma unidade de fornecimento, retorna "incerteza"
  if (count_uf > 1) {
    uf <- "incerteza"
  }
  
  return(uf)
}

# Detecta as unidades de fornecimento a partir do campo `unidadeMedida`
with_progress({
  p <- progressor(steps = nrow(medicamentos)) # Define o total de passos
  medicamentos <- medicamentos %>%
    mutate(unidadeFornecimentoDetectada = {
      p() # Atualiza o progresso a cada linha
      extrai_uf(unidadeMedida_limpa)
    })
})

# Detecta as unidades de fornecimento faltantes a partir do campo `descricao`
with_progress({
  p <- progressor(steps = nrow(medicamentos)) # Define o total de passos
  medicamentos <- medicamentos %>%
    mutate(unidadeFornecimentoDetectada = {
      p() # Atualiza o progresso a cada linha
      ifelse(
        is.na(unidadeFornecimentoDetectada),
        extrai_uf(descricao_limpa),
        unidadeFornecimentoDetectada
      )
    })
})

# Adiciona o nome padrão da unidade de fornecimento
medicamentos <- medicamentos %>%
  mutate(nomeUnidadeFornecimento = map_chr(unidadeFornecimentoDetectada, ~ {
    if (is.na(.x))
      NA_character_
    else
      uf_env[[.x]] %||% NA_character_
  }))


# IDENTIFICA UNIDADES DE MEDIDA -------------------------------------------

#' Extrai a unidade de medida (UM) de um texto
#'
#' A função identifica e extrai a unidade de medida (UM) de um texto,
#' verificando tokens individuais em um ambiente (`um_env`) que contém as unidades reconhecidas.
#' Se mais de uma unidade for encontrada, retorna `"incerteza"`.
#'
#' @param texto Uma string contendo o texto a ser analisado.
#' @return Uma string com a unidade de medida identificada, `"incerteza"` caso haja múltiplas correspondências,
#' ou `NA` se nenhuma unidade for encontrada.
extrai_um <- function(texto) {
  # Verifica se o parâmetro é vazio ou nulo
  if (is.na(texto) | texto == "") {
    return(NA)
  }
  
  # Separa o texto em tokens
  tokens <- tokeniza_unidades(texto)
  
  count_um <- 0  # Contagem de unidades de medida
  um <- NA       # nome da unidade de medida
  
  # Verifica se o `texto` possui unidades de medida
  for (token in tokens) {
    if (!is.null(um_env[[token]])) {
      um <- token
      count_um <- count_um + 1
    }
  }
  
  # Se houver mais de uma unidade de medida, retorna "incerteza"
  if (count_um > 1) {
    um <- "incerteza"
  }
  
  return(um)
}

# Detecta as unidades de medida a partir do campo `unidadeMedida`
with_progress({
  p <- progressor(steps = nrow(medicamentos)) # Define o total de passos
  medicamentos <- medicamentos %>%
    mutate(unidadeMedidaDetectada = {
      p() # Atualiza o progresso a cada linha
      extrai_um(unidadeMedida_limpa)
    })
})

# Detecta as unidades de medida a partir do campo `descricao`
with_progress({
  p <- progressor(steps = nrow(medicamentos)) # Define o total de passos
  medicamentos <- medicamentos %>%
    mutate(unidadeMedidaDetectada = {
      p() # Atualiza o progresso a cada linha
      ifelse(
        is.na(unidadeMedidaDetectada),
        extrai_um(descricao_limpa),
        unidadeMedidaDetectada
      )
    })
})

# Adiciona o nome padrão da unidade de medida
medicamentos <- medicamentos %>%
  mutate(nomeUnidadeMedida = map_chr(unidadeMedidaDetectada, ~ {
    if (is.na(.x))
      NA_character_
    else
      um_env[[.x]] %||% NA_character_
  }))


# IDENTIFICA CAPACIDADES DAS UNIDADES DE MEDIDA ---------------------------

#' Extrai a capacidade de uma unidade de medida de uma descrição
#'
#' Esta função extrai a capacidade de uma unidade de medida (por exemplo, "ml", "mg")
#' a partir de uma descrição textual. Caso a unidade de medida não seja encontrada
#' na descrição, a função retorna NA.
#'
#' @param descricao Um vetor de caracteres contendo as descrições dos medicamentos.
#' @param unidadeMedida Um vetor de caracteres que especifica a unidade de medida
#'  a ser buscada na descrição (exemplo: "ml", "mg").
#'
#' @return Um vetor numérico com a capacidade extraída, ou NA caso a unidade de 
#' medida não seja encontrada na descrição.
#'
#' @examples
#' extrai_capacidade("paracetamol 750 mg/ml frasco 2.5 ml", "ml")
#' # Retorna 2.5
#'
#' extrai_capacidade("medicamento sem unidade", "mg")
#' # Retorna NA
#'
extrai_capacidade <- function(descricao, unidadeMedida) {
  
  capacidade <- NA
  
  # Se unidadeMedida for NA, retorna NA
  if (is.na(unidadeMedida)) {
    return(capacidade)
  }
  
  # Cria um padrão regex para capturar um número antes da unidade de medida,
  # aceitando ponto ou vírgula como separador decimal
  padrao <- paste0("(\\d+(?:[.,]\\d+)?)\\s*", unidadeMedida)
  match <- str_match(descricao, padrao)
  
  # Converte o número para numérico, substituindo vírgula por ponto
  if (!is.na(match[1, 2])) {
    capacidade <- as.numeric(gsub(",", ".", match[1, 2]))
  } 
  
  return(capacidade)
}


# Adiciona a capacidade da unidade de medida como coluna no dataframe
medicamentos <- medicamentos %>%
  rowwise() %>%
  mutate(capacidadeUnidadeMedida = extrai_capacidade(unidadeMedida_limpa, unidadeMedidaDetectada)) %>%
  mutate(capacidadeUnidadeMedida = ifelse(
    is.na(capacidadeUnidadeMedida),
    extrai_capacidade(descricao_limpa, unidadeMedidaDetectada),
    capacidadeUnidadeMedida
  ))


# SALVA OS RESULTADOS -----------------------------------------------------

CAMINHO_RESULTADOS <- here("tasks/normalizacao-unidades/outputs/medicamentos.rds")
medicamentos %>% saveRDS(CAMINHO_RESULTADOS)
