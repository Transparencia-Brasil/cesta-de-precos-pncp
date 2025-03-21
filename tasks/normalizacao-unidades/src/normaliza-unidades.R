#' Documentação do script
#' 

library(here)         # Referenciamento de arquivos
library(tidyr)        # Organiza dados bagunçados
library(dplyr)        # Manipulação de dados
library(purrr)        # Ferramentas de Programação Funcional

source(here("tasks/normalizacao-unidades/src/utils.R"))

# CARREGA OS DADOS --------------------------------------------------------

CAMINHO_CATALOGO <- here("data/catmat/catmat.rds")
catmat <- readRDS(CAMINHO_CATALOGO)


# LIMPA OS TEXTOS ---------------------------------------------------------

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
  "curie" =  "curies",
  "dose" =  "doses",
  "dragea" =  "drageas",
  "embalagem" = "embalagens",
  "emplastro" = "emplastros",
  "envelope" = "envelopes",
  "flaconete" =  "flaconetes",
  "frasco" =  "frascos",
  "frasco ampola" =  "frascos ampola",
  "galao" =  "galoes",
  "gigabecquerel" = "gigabecquerel", # invariável no plural
  "globulo" =  "globulos",
  "grama" = "gramas",
  "lata" =  "latas",
  "litro" = "litros",
  "megabecquerel" = "megabecquerel", # invariável no plural
  "micrograma" = "microgramas",
  "milhao unid intern" = "milhoes unid intern",
  "milheiro de cartelas" =  "milheiros de cartelas",
  "milheiro unid intern" =  "milheiros unid itern",
  "milicurie" = "milicuries",
  "miligrama" = "miligramas",
  "mililitro" = "mililitros",
  "pastilha" = "pastilhas",
  "pote" =  "potes",
  "quilograma" = "quilogramas",
  "rolo" =  "rolos",
  "sache" =  "saches",
  "seringa" =  "seringas",
  "supositorio" =  "supositorios",
  "tablete" =  "tabletes",
  "tambor" = "tambores",
  "tubete" = "tubetes",
  "tubo" = "tubos",
  "unid internacional" = "unid internacional",
  "unidade" = "unidades"
)

# Plurais das unidades de medida (um)
plurais_um <- c(
  "centimetro" = "centimetros",
  "dose" =  "doses",
  "grama" = "gramas",
  "litro" = "litros",
  "micrograma" = "microgramas",
  "microlitro" = "microlitros",
  "mil unid intern" = "mil unid intern",
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


# CRIA DICIONÁRIO DE CONSULTA ---------------------------------------------

#' Explicação:
#' Para agilizar a identificação de unidades de fornecimento, unidades de medida
#' e capacidades dos medicamentos, será criado um "dicionário" de consulta com a
#' seguinte hierarquia:
#'
#' [codigo br] > [unidade de fornecimento] > [unidade de medida] > [capacidades]
#'
#' Isto é, para acessar as unidades de fornecimento de um determinado codigo br,
#' pode-se pesquisar dic[<codigo br>]. Para acessar as unidades de medida para
#' determinada unidade de fornecimento de determinado codigo br, basta pesquisar
#' dic[<codigo br>][<unidade de fornecimento>]. E assim por diante.
#'
#' Primeiro o dicionário é estruturado como uma lista nomeada e depois é convertido
#' para `Environment`, que é uma estrutura de dados em R que funciona como Hashtable.
#'
#' Exemplo com o Petrolato, Aspecto Físico:Líquido, Tipo:Laxativo, Uso:Oral (233632)
#'
#' names(dic[['233632']])
#' [1] "bis"   "emb"   "fr"   "frasco"   "embalagem"   "bisnaga"   "frascos"
#' [8] "bisnagas"   "embalagens"
#'
#' names(dic[['233632']][['frascos']])
#' [1] "mililitros" "mililitro"  "ml"
#'
#' dic[['233632']][['frascos']][['ml']]
#' [1]  100  120  200 1000
#'

# Inicializa dicionário aninhado (vazio)
dic <- list()

# Renomeia o dataframe só para facilitar a escrita do algoritmo
df <- catmat_expandido

for (i in 1:nrow(df)) {
  item <- as.character(df$codigo_br[i])
  unidade_fornec <- df$nomeUnidadeFornecimento[i]
  sigla_fornec <- df$siglaUnidadeFornecimento[i]
  plural_fornec <- df$pluralUnidadeFornecimento[i]
  unidade_med <- df$nomeUnidadeMedida[i]
  sigla_med <- df$siglaUnidadeMedida[i]
  plural_med <- df$pluralUnidadeMedida[i]
  cap <- df$capacidadeUnidadeMedida[i]
  
  # Criar nível para o código do item, se ainda não existir
  if (!item %in% names(dic)) {
    dic[[item]] <- list()
  }
  
  # Criar nível para a unidade de fornecimento, sua sigla e seu plural
  for (uf in c(unidade_fornec, sigla_fornec, plural_fornec)) {
    if (!uf %in% names(dic[[item]])) {
      dic[[item]][[uf]] <- list()
    }
    
    # Criar nível para a unidade de medida, sua sigla e seu plural
    for (um in c(unidade_med, sigla_med, plural_med)) {
      if (!um %in% names(dic[[item]][[uf]])) {
        dic[[item]][[uf]][[um]] <- c()
      }
      
      # Adicionar capacidade à lista correspondente
      dic[[item]][[uf]][[um]] <- unique(c(dic[[item]][[uf]][[um]], cap))
    }
  }
  
  # Informa o progresso do algorritmo
  progresso = round(i / nrow(df) * 100)
  cat(sprintf("Gerando dicionário de unidades: %d%% concluído", progresso),
      "\r")
  flush.console()
}

# Remove a variável temporária da memória
rm(df)

# Converte a lista aninhada para uma estrutura de ambientes (hashtable).
dic <- list_to_env(dic) 
