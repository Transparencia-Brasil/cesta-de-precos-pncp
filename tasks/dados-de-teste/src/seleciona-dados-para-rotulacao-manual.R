#' Este script seleciona duas amostras dos dados de medicamentos do PNCP usando 
#' estratégias diferentes de amostragem. 
#' 
#' A primeira amostra é uma amostra aleatória de mil itens com descrições distintas.
#' 
#' A segunda amostra é uma amostra proposital dos itens que possuem o maior número
#' de descrições diferentes. Alguns deste itens são medicamentos, mas também são 
#' utilizados em outras atividades humanas. A ideia é testar se o modelo consegue
#' identificar bem quais itens são medicamentos e quais não são.
#' 

library(dplyr)
library(here)

medicamentos <- readRDS(here("data/pncp/medicamentos.rds"))

# AMOSTRA ALEATÓRIA -------------------------------------------------------

amostra_aleatória <- medicamentos %>% 
  distinct(descricao, .keep_all = TRUE) %>%
  sample_n(1000) %>%
  select(endpoint, numeroItem, codigo_pdm, descricao, unidadeMedida) %>%
  saveRDS(here("tasks/dados-de-teste/outputs/medicamentos-teste-aleatorio.rds"))

# AMOSTRA PROPOSITAL ------------------------------------------------------

mais_descricoes_diferentes <- medicamentos %>%
  group_by(codigo_pdm) %>%
  summarise(n_descricoes = n_distinct(clean_descricao)) %>%
  arrange(desc(n_descricoes))

#' O código 2259 é álool etílico (etanol). Usos: limpeza de ambiente, combustível,
#' bebida alcóolica.
#' O código 1289 é "soro". Soro é uma palavra muito genérica e qualquer coisa que
#' contenha soro será identificada como medicamento. Exemplos: suporte para soro,
#' biscoito com soro de leite, etc.
#' O código 8428 é "insulina". Qualquer material para aplicação de insulina como
#' agulhas, seringa, bomba, etc. também está sendo classificado como medicamento.
#' o código 8007 é "glicose".
#' o código 15458 é "vacina"
#' 
#' Ao todo são 10437 descrições diferentes 
#' Uma amostra aleatória será extraída a partir de uma pre-seleção de itens que
#' sejam de algum tipo acima.

amostra_proposital <- medicamentos %>% 
  filter(codigo_pdm %in% c("2259", "1289", "8428", "8007", "15458")) %>%
  distinct(descricao, .keep_all = TRUE) %>%
  sample_n(1000) %>%
  select(endpoint, numeroItem, codigo_pdm, descricao, unidadeMedida) %>%
  saveRDS(here("tasks/dados-de-teste/outputs/medicamentos-teste-proposital.rds"))
