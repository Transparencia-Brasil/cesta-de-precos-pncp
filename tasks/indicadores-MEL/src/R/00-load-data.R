options(width = 150)
source("tasks/indicadores-MEL/src/R/utils.R", encoding = "UTF-8")

medicamentos <- "coleta/itens" |>
  list.files(recursive = TRUE, full.names = TRUE, pattern = "medicamentos.csv") |>
  here() |>
  as_tibble_col("path") |>
  filter(!str_detect(path, "_TESTE")) |>
  mutate(
    dados = map(path, read_csv, col_types = cols(.default = "c")),
    anomes_coleta = make_anomes_coleta(path)
  ) |>
  unnest(dados) |>
  mutate(data.numeroControlePNCP = make_id(endpoint))


contratacoes <- "coleta/contratacoes" |>
  list.files(recursive = TRUE, full.names = TRUE, pattern = "dados.csv") |>
  here() |>
  as_tibble_col("path") |>
  filter(!str_detect(path, "_TESTE")) |>
   mutate(
    dados = map(path, read_csv, col_types = cols(.default = "c")),
    path = basename(dirname(path))
  ) |>
  unnest(dados)


resultados <- "coleta/resultados" |>
  list.files(recursive = TRUE, full.names = TRUE, pattern = "dados.csv") |>
  here() |>
  as_tibble_col("path") |>
  filter(!str_detect(path, "_TESTE")) |>
   mutate(
    dados = map(path, read_csv, col_types = cols(.default = "c")),
    anomes_coleta = make_anomes_coleta(path)
  ) |>
  unnest(dados) |>
  glimpse()


glimpse(medicamentos)
glimpse(contratacoes)
glimpse(resultados)

ids_validos <- medicamentos |>
  distinct(data.numeroControlePNCP)

count(medicamentos, situacaoCompraItemNome)

medicamentos |>
  count(anomes_coleta, situacaoCompraItemNome) |>
  ggplot(aes(x = anomes_coleta, y = n, color = situacaoCompraItemNome, group = situacaoCompraItemNome)) +
  geom_line() +
  scale_x_date(date_labels = "%b/%y", date_breaks = "month") +
  labs(
    title = "Número de medicamentos por situação de compra ao longo do tempo",
    x = "Ano-Mês da Coleta",
    y = "Número de Medicamentos"
  )

medicamentos |>
  count(anomes_coleta) |>
  ggplot(aes(x = anomes_coleta, y = n)) +
  geom_col() +
  geom_text(aes(label = n), vjust = -.2) +
  scale_x_date(date_labels = "%b/%y", date_breaks = "month")

medicamentos |>
  glimpse()

contratacoes |>
  count(data.orgaoEntidade.razaoSocial)
