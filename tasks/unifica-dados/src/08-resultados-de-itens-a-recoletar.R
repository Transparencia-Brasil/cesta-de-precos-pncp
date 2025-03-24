library(tidyverse)
library(here)

# os arquivos unificados ficarão salvos na pasta "output"
OUTPUT_DIR <- "tasks/unifica-dados/output"

resultados <- read_csv(here(OUTPUT_DIR, "itens-resultados.csv"))
medicamentos <- read_csv(here(OUTPUT_DIR, "medicamentos.csv"))

#' 'anti_join()' return all rows from 'x' with*out* a match in 'y'.
recoleta_resultados <- medicamentos %>%
  anti_join(resultados, by = c("numeroControlePNCPCompra", "numeroItem"))

recoleta_resultados %>%
  write_csv(here("coleta/itens/itens.csv"))
