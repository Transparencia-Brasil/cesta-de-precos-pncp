library(dplyr)

medicamentos <- readRDS("C:/Users/luiz_/tb/cesta-de-precos-pncp/data/pncp/medicamentos.rds")

maiores_descricoes <- medicamentos %>%
  mutate(tamanho_descricao = nchar(descricao)) %>%
  group_by(codigo_pdm) %>%
  summarise(tamanho_medio = mean(tamanho_descricao)) %>%
  arrange(desc(tamanho_medio))

mais_descricoes_diferentes <- medicamentos %>%
  group_by(codigo_pdm) %>%
  summarise(n_descricoes = n_distinct(clean_descricao)) %>%
  arrange(desc(n_descricoes))
  

#' O código 2259 é álool etílico (etanol). Usos: limpeza de ambiente, combustível, bebida alcóolica
#' O código 1289 é "soro". Soro é uma palavra muito genérica e qualquer coisa que contenha soro será
#' identificada como medicamento. Exemplos: suporte para soro, biscoito com soro de leite, etc.
#' O código 8428 é "insulina". Qualquer material para aplicação de insulina como agulhas, seringa, 
#' bomba, etc. também está sendo classificado como medicamento.
#' o código 8007 é "glicose".
#' o código 15458 é "vacina"
#' Ao todo são 10437 descrições diferentes 
#' 

# codigo 5116 é do cloreto de potássio (medicamento e fertilizante)