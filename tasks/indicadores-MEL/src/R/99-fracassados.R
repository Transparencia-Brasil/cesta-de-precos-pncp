
library(tidyverse)
library(here)

TASK <- here("tasks/indicadores-MEL/inputs")
INPUT_FILES <- list.files(TASK, full.names = TRUE, pattern = "rds")
FILENAMES <- str_remove(basename(INPUT_FILES), "\\.rds$")


pncp <- map(INPUT_FILES, readRDS) |>
  set_names(FILENAMES)

pncp$medicamentos |>
  mutate(
    situacao = case_when(
      situacaoCompraItemNome %in% c("Homologado", "Em andamento") ~ situacaoCompraItemNome,
      .default = "Insucesso"
  )) |>
  filter(situacao != "Em andamento") |>
  count(anomes_coleta, situacao) |>
  ggplot(aes(x = anomes_coleta, y = n, color = situacao, group = situacao)) +
  geom_line() +
  scale_x_date(date_labels = "%b/%y", date_breaks = "month") +
  labs(
    title = "Número de medicamentos por situação de compra ao longo do tempo",
    x = "Ano-Mês da Coleta",
    y = "Número de Medicamentos",
    caption = "*inclui as seguintes situações: Anulado, Revogado, Cancelado e Fracassado"
  )


pncp$medicamentos |>
  mutate(
    situacao = case_when(
      situacaoCompraItemNome %in% c("Homologado", "Em andamento") ~ situacaoCompraItemNome,
      .default = "Insucesso"
    )
  ) |>
  filter(situacao != "Em andamento") |>
  count(anomes_coleta, situacao) |>
  group_by(anomes_coleta) |>
  mutate(percentual = n / sum(n)) |>
  ungroup() |>
  ggplot(aes(x = anomes_coleta, y = percentual, color = situacao, group = situacao)) +
  geom_line() +
  scale_x_date(date_labels = "%b/%y", date_breaks = "month") +
  scale_y_continuous(labels = scales::label_percent(accuracy = 1)) +
  labs(
    title = "Percentual de medicamentos por situação de compra ao longo do tempo",
    x = "Ano-Mês da Coleta",
    y = "Percentual de Medicamentos",
    caption = "*inclui as seguintes situações: Anulado, Revogado, Cancelado e Fracassado"
  )



pncp$medicamentos |>
  count(anomes_coleta) |>
  ggplot(aes(x = anomes_coleta, y = n)) +
  geom_col() +
  geom_text(aes(label = n), vjust = -.2) +
  scale_x_date(date_labels = "%b/%y", date_breaks = "month") +
  labs(
    title = "Número total de contratações de medicamentos coletados por mês",
    x = "Ano-Mês da Coleta",
    y = "Número de Medicamentos"
  )
