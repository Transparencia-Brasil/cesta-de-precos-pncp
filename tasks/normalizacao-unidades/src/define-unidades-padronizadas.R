#' Este script organiza as unidades de fornecimento e de medida padrões provenientes
#' do catálogo de materiais. 
#' As unidades são disponibilizadas através de environments (equivalente a um dicionário,
#' mapa ou tabela hash).
#' 

library(dplyr)        # Data manipulation
library(here)         # File referencing

source(here("tasks/normalizacao-unidades/src/limpa-texto.R"))

caminho_catalogo <- here("data/catmat/catmat.rds")
catmat <- readRDS(caminho_catalogo)

# Desaninha a coluna unidadeFornecimento do catmat
catmat_expandido <- catmat %>% unnest(unidadeFornecimento)

# PASSO 1: Separa os valores únicos de unidade de fornecimento (uf)
uf_df <- catmat_expandido %>%
  select(siglaUnidadeFornecimento, nomeUnidadeFornecimento) %>%
  unique() %>%
  drop_na() %>%
  mutate(siglaUnidadeFornecimento = remove_pontuacao(clean_text(siglaUnidadeFornecimento)),  
         nomeUnidadeFornecimento = remove_pontuacao(clean_text(nomeUnidadeFornecimento)))

# PASSO 2: separa valores únicos de unidade de medida (um)
um_df <- catmat_expandido %>%
  select(siglaUnidadeMedida, nomeUnidadeMedida) %>%
  unique() %>%
  drop_na() %>%
  mutate(siglaUnidadeMedida = remove_pontuacao(clean_text(siglaUnidadeMedida)),
         nomeUnidadeMedida = remove_pontuacao(clean_text(nomeUnidadeMedida)))
# Substitui "dose s" por "dose" nas unidades de medida
um_df$siglaUnidadeMedida <- gsub("dose s", "dose", um_df$siglaUnidadeMedida)

# PASSO 3: Algumas unidades de medida estão como unidades de fornecimento, são elas:
unidades_medida_em_unidades_fornecimento <- data.frame(
  siglaUnidadeMedida = c("ci", "dose", "doses", "g", "gbq", "kg", "l", "mbq",
                         "mcg", "mcu", "mg", "ml", "mui", "ui", "un"),
  nomeUnidadeMedida = c("curie", "doses", "doses", "grama", "gigabecquerell",
                        "quilograma", "litro", "megabecquerel", "micrograma",
                        "milicurie", "miligrama", "mililitro", "milhao unid intern",
                        "unid internacional", "unidade")
)
# Adiciona as unidades de medida ao dataframe correto
um_df <- bind_rows(um_df, unidades_medida_em_unidades_fornecimento) %>% 
  distinct(nomeUnidadeMedida, .keep_all = TRUE)
# Remove as unidades de medida das unidades de fornecimento
uf_df <- uf_df %>%
  filter(!(nomeUnidadeFornecimento %in% unidades_medida_em_unidades_fornecimento$nomeUnidadeMedida))

# PASSO 4: Define os plurais das unidades de fornecimento e medida
# Garante que o dataframe está ordenado alfabeticamente
uf_df <- uf_df %>% arrange(nomeUnidadeFornecimento)
uf_df$pluralUnidadeFornecimento <- c("ampolas", "bisnagas", "blisteres", "bolsas",
                                     "bombonas", "capsulas", "cartuchos", "comprimidos",
                                     "conjuntos", "dageas", "embalagens", "emplastros",
                                     "envelopes", "flaconetes", "frascos", "frascos ampola",
                                     "galoes", "globulos", "latas", "milheiros de cartelas",
                                     "milheiros unid itern", "pastilhas", "potes", "rolos",
                                     "saches", "seringas", "supositorios", "tabletes",
                                     "tambores", "tubetes", "tubos")

um_df <- um_df %>% arrange(nomeUnidadeMedida)
um_df$pluralUnidadeMedida <- c("centimetros", "curies", "doses", "gigabecquerels",
                               "gramas", "litros", "megabecquerels", "microgramas",
                               "microlitros", "mil unid intern", "milhoes unid intern",
                               "milicuries", "miligramas", "mililitros", "quilogramas",
                               "unid internacional", "unidades")

# PASSO 5: Corrige erros ortográficos nas unidades de fornecimento e medida
um_df <- um_df %>%
  mutate( # gigabecquerel só tem 1 "l"
    nomeUnidadeMedida = gsub("gigabecquerell", "gigabecquerel", nomeUnidadeMedida) 
  )

# PASSO 6: Cria dicionários de unidades de fornecimento (uf) e unidades de medida (um)
# para agilizar a pesquisa
uf_env <- new.env()
for (i in 1:nrow(uf_df)) {
  # Adiciona as siglas como chaves do dicionário e o nome como valor
  uf_env[[uf_df$siglaUnidadeFornecimento[i]]] <- uf_df$nomeUnidadeFornecimento[i]
  # Adiciona o nome também como chave e como valor (para ser possível pesquisar por sigla e nome)
  uf_env[[uf_df$nomeUnidadeFornecimento[i]]] <- uf_df$nomeUnidadeFornecimento[i]
  # Adiciona o plural como chave e o nome como valor
  uf_env[[uf_df$pluralUnidadeFornecimento[i]]] <- uf_df$nomeUnidadeFornecimento[i]
}

um_env <- new.env()
for (i in 1:nrow(um_df)) {
  # Adiciona as siglas como chaves do dicionário e o nome como valor
  um_env[[um_df$siglaUnidadeMedida[i]]] <- um_df$nomeUnidadeMedida[i]
  # Adiciona o nome também como chave e como valor (para ser possível pesquisar por sigla e nome)
  um_env[[um_df$nomeUnidadeMedida[i]]] <- um_df$nomeUnidadeMedida[i]
  # Adiciona o plural como chave e o nome como valor
  um_env[[um_df$pluralUnidadeMedida[i]]] <- um_df$nomeUnidadeMedida[i]
}

