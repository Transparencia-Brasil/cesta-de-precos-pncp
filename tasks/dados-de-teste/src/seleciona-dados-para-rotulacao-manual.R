#' Este script seleciona amostras aleatórias dos dados de medicamentos do PNCP.

library(dplyr)
library(here)

medicamentos <- readRDS(here("data/pncp/medicamentos.rds"))
catmat <- readRDS(here("data/catmat/catmat.rds"))

# AMOSTRAS ALEATÓRIAS -----------------------------------------------------

# Defina a semente sempre antes de executar o código abaixo para garantir o 
# mesmos resultados aleatórios.
set.seed(180596)  
amostra1 <- medicamentos %>% 
  distinct(descricao, .keep_all = TRUE) %>%
  sample_n(1000) %>%
  select(endpoint, numeroItem, codigo_pdm, descricao, unidadeMedida) 

amostra1 %>%
  write.csv(here("tasks/dados-de-teste/outputs/medicamentos-teste-aleatorio-1.csv"), row.names = F)

amostra2 <- medicamentos %>% 
  distinct(descricao, .keep_all = TRUE) %>%
  anti_join(amostra1, by = "endpoint") %>%
  sample_n(1000) %>%
  select(endpoint, numeroItem, codigo_pdm, descricao, unidadeMedida) 

amostra2 %>%
  write.csv(here("tasks/dados-de-teste/outputs/medicamentos-teste-aleatorio-2.csv"), row.names = F)

# CATÁLOGO DE REFERÊNCIA (CATMAT) -----------------------------------------

catmat %>%
  select(codigo_pdm, nome_pdm, codigo_br, nome_item) %>%
  write.csv(here("tasks/dados-de-teste/outputs/catmat-para-rotulagem.csv"), row.names = F)

