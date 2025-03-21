

# TODO:
# - gerar chave ssh -> OK!
# - consertar ids de endpoints = NA
# - gerar embeddings desses endpoints = NA
# - reunir a base novamente
# - anti-join com resultados-tens para saber quais resultados serão consultados e coletados
# - fazer a recoleta (usar `src\ETL\coletores\coleta-resultados.R`)
# - reune recoleta de resultados com resultados previamente coletados
# - rodar coleta de janeiro/2025 (30 dias)
# - rodar coleta de fevereiro/2025 (2 coletas de 14 dias)

itens <- read_csv(here(OUTPUT_DIR, "itens.csv"))
resultados <- read_csv(here(OUTPUT_DIR, "itens-resultados.csv"))
medicamentos <- read_csv(here(OUTPUT_DIR, "medicamentos.csv"))

itens %>% glimpse()
resultados %>% glimpse()
medicamentos %>% glimpse()

medicamentos %>%
  filter(numeroControlePNCPCompra %in% unique(resultados$numeroControlePNCPCompra))

#' semi_join()' return all rows from 'x' with a match in 'y'.
medicamentos %>%
  semi_join(resultados, by = c("numeroControlePNCPCompra", "numeroItem"))

#' semi_join()' return all rows from 'x' with a match in 'y'.
medicamentos %>%
  anti_join(resultados, by = c("numeroControlePNCPCompra", "numeroItem"))