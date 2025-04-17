library(tidyverse)
library(here)

source(here("setup/rsetup.R"))


# FILEPATHS --------------------------------------------------------------------

PATH_ITENS_2024 <- here("tasks/unifica-dados/output/itens.csv")

PATH_ITENS_2025 <- list.files(
  path = here("coleta/itens"),
  pattern = "dados.csv",
  recursive = TRUE,
  full.names = TRUE
)[-5]


# READ DATA --------------------------------------------------------------------

itens_2024 <- read_csv(PATH_ITENS_2024, col_types = list(.default = col_character())) %>%
  select(
    endpoint, numeroControlePNCPCompra,
    dataInclusao, dataAtualizacao,
    numeroItem, descricao, unidadeMedida, valorTotal, quantidade,
    categoriaItemCatalogo,
    catalogo,
    catalogoCodigoItem,
    informacaoComplementar,
    ncmNbsCodigo,
    ncmNbsDescricao
  )

itens_2025 <- map_df(PATH_ITENS_2025, read_csv, col_types = list(.default = col_character())) %>%
  select(
    endpoint, numeroItem, dataInclusao, dataAtualizacao,
    descricao, unidadeMedida, valorTotal, quantidade,
    unidadeMedida,
    contains("atalogo"),
    informacaoComplementar,
    starts_with("ncm"),
  )

itens_2024 <- itens_2024 %>%
  mutate(
    endpoint = sprintf("%s/%s", endpoint, numeroItem),
    id = "itens_2024"
  )

itens_2025 <- itens_2025 %>%
  mutate(
    endpoint = sprintf("%s/%s", endpoint, numeroItem),
    id = "itens_2025"
  )

glimpse(itens_2024)
glimpse(itens_2025)


# COUNT ALL --------------------------------------------------------------------

itens <- bind_rows(itens_2024, itens_2025)

quantidades <- itens %>%
  count(id, ano = year(dataInclusao), mes = month(dataInclusao)) %>%
  mutate(data = my(sprintf("%s/%s", mes, ano))) %>%
  summarise(.by = c(id, data), n = sum(n))

quantidades %>%
  mutate(id = fct_reorder(id, -as.numeric(str_remove(id, "itens_")))) %>%
  ggplot(aes(x = data, y = n, fill = id)) +
  geom_col() +
  labs(
    title = "Quantidade de itens coletados do PNCP - por mês",
    subtitle = "Ex: https:\\/\\/pncp.gov.br\\/api\\/pncp\\/v1\\/orgaos\\/**{cnpj}**\\/compras\\/**{ano}**\\/**{sequencial}**\\/itens/**{numeroItem}**",
    x = NULL,
    y = "<br>Quantidade de itens coletados", fill = "Coleta"
  ) +
  scale_x_date(date_labels = "%b-%y", date_breaks = "1 months", expand = c(0, 0)) +
  scale_y_continuous(labels = numero, breaks = seq(0, 2.5e5, length.out = 6), limits = c(0, 3e5), expand = c(0, 0), position = "right") +
  theme(
    axis.text.x = ggtext::element_markdown(angle = 45, hjust = 1),
    legend.position = c(.15, .92),
    legend.direction = "horizontal",
    legend.title.position = "top"
  )


# FILTER -----------------------------------------------------------------------

rm(itens)
rm(quantidades)

itens_2024_filtrado <- itens_2024 %>%
  filter(year(dataInclusao) == 2024) %>%
  filter(month(dataInclusao) >= 10)

itens_2025_filtrado <- itens_2025 %>%
  filter(
    (year(dataInclusao) >= 2024 &
      month(dataInclusao) %in% c(10, 11, 12)) |
      (year(dataInclusao) >= 2025)
  ) %>%
  mutate(id = "itens_2025")


itens <- bind_rows(itens_2024_filtrado, itens_2025_filtrado)


# COUNT FILTRADO ---------------------------------------------------------------

quantidades <- itens %>%
  count(id, ano = year(dataInclusao), mes = month(dataInclusao)) %>%
  mutate(data = my(sprintf("%s/%s", mes, ano))) %>%
  summarise(.by = c(id, data), n = sum(n))

quantidades %>%
  ggplot(aes(x = data, y = n, fill = id)) +
  geom_col() +
  geom_text(aes(label = numero(n)), size = 6, position = position_stack(vjust = .5)) +
  labs(title = "Quantidade de itens no PNCP - por mês", x = "mês/ano", y = "Quantidade de itens no PNCP") +
  scale_x_date(date_labels = "%b/%Y") +
  scale_y_continuous(labels = numero, limits = c(0, 300000))

quantidades_ano <- count(quantidades, ano = year(data), wt = n, name = "qt_ano")

# Quantidade de itens - Total
nrow(itens)

# PREENCHIMENTO CATALOGO -------------------------------------------------------

#' Calcular a proporção de preenchimento de uma coluna por ano
#'
#' @param itens Dataframe contendo os itens a serem analisados
#' @param coluna String com o nome da coluna a ser verificada
#' @param quantidades_ano Dataframe com as quantidades totais por ano
#'
#' @return Dataframe com contagem e percentual de preenchimento da coluna por ano
conta_preenchimento <- function(itens, coluna, quantidades_ano) {
  itens %>%
    filter(!is.na(!!sym(coluna))) %>%
    count(ano = year(dataInclusao)) %>%
    left_join(quantidades_ano) %>%
    mutate(perc = perc(n / qt_ano, accuracy = .1)) %>%
    mutate(var = coluna)
}

# ---

# catalogo.dataInclusao
catalogo_dataInclusao <- conta_preenchimento(itens, "catalogo.dataInclusao", quantidades_ano)

itens %>% distinct(catalogo.dataInclusao)

itens %>%
  filter(!is.na(catalogo.dataInclusao)) %>%
  select(endpoint, catalogo.dataInclusao)

# ---


# catalogo.dataAtualizacao
catalogo_dataAtualizacao <- conta_preenchimento(itens, "catalogo.dataAtualizacao", quantidades_ano)

itens %>% distinct(catalogo.dataAtualizacao)

itens %>%
  filter(!is.na(catalogo.dataAtualizacao)) %>%
  select(endpoint, catalogo.dataAtualizacao)

# ---


# catalogo.descricao
catalogo_descricao <- conta_preenchimento(itens, "catalogo.descricao", quantidades_ano)

itens %>% distinct(catalogo.descricao)

itens %>%
  filter(!is.na(catalogo.descricao)) %>%
  select(endpoint, catalogo.descricao)

# ---


# catalogo.id
catalogo_id <- conta_preenchimento(itens, "catalogo.id", quantidades_ano)

itens %>% distinct(catalogo.id)

itens %>%
  filter(!is.na(catalogo.id)) %>%
  select(endpoint, catalogo.id)

# ---


# catalogo.nome
catalogo_nome <- conta_preenchimento(itens, "catalogo.nome", quantidades_ano)


itens %>% distinct(catalogo.nome)

itens %>%
  filter(!is.na(catalogo.nome)) %>%
  select(endpoint, catalogo.nome)

# ---

# catalogo.statusAtivo
catalogo_statusAtivo <- conta_preenchimento(itens, "catalogo.statusAtivo", quantidades_ano)

itens %>% distinct(catalogo.statusAtivo)

itens %>%
  filter(!is.na(catalogo.statusAtivo)) %>%
  select(endpoint, catalogo.statusAtivo)

# ---


# catalogo.url
catalogo_url <- conta_preenchimento(itens, "catalogo.url", quantidades_ano)

itens %>% distinct(catalogo.url)

itens %>%
  filter(!is.na(catalogo.url)) %>%
  select(endpoint, catalogo.url)

# ---


# catalogoCodigoItem
catalogoCodigoItem <- conta_preenchimento(itens, "catalogoCodigoItem", quantidades_ano)

itens %>%
  distinct(catalogoCodigoItem) %>%
  print(n = Inf)

itens %>%
  filter(!is.na(catalogoCodigoItem)) %>%
  select(endpoint, catalogoCodigoItem)

# ---


# categoriaItemCatalogo.dataAtualizacao
categoriaItemCatalogo_dataAtualizacao <- conta_preenchimento(itens, "categoriaItemCatalogo.dataAtualizacao", quantidades_ano)

itens %>% distinct(categoriaItemCatalogo.dataAtualizacao)

itens %>%
  filter(!is.na(categoriaItemCatalogo.dataAtualizacao)) %>%
  select(endpoint, categoriaItemCatalogo.dataAtualizacao)

# ---

# categoriaItemCatalogo.dataInclusao
categoriaItemCatalogo_dataInclusao <- conta_preenchimento(itens, "categoriaItemCatalogo.dataInclusao", quantidades_ano)

itens %>% distinct(categoriaItemCatalogo.dataInclusao)

itens %>%
  filter(!is.na(categoriaItemCatalogo.dataInclusao)) %>%
  select(endpoint, categoriaItemCatalogo.dataInclusao)

# ---


# categoriaItemCatalogo.id
categoriaItemCatalogo_id <- conta_preenchimento(itens, "categoriaItemCatalogo.id", quantidades_ano)

itens %>% distinct(categoriaItemCatalogo.id)

itens %>%
  filter(!is.na(categoriaItemCatalogo.id)) %>%
  select(endpoint, categoriaItemCatalogo.id)

# ---


# categoriaItemCatalogo.nome
categoriaItemCatalogo_nome <- conta_preenchimento(itens, "categoriaItemCatalogo.nome", quantidades_ano)

itens %>% distinct(categoriaItemCatalogo.nome)

itens %>%
  filter(!is.na(categoriaItemCatalogo.nome)) %>%
  select(endpoint, categoriaItemCatalogo.nome)

# ---


# categoriaItemCatalogo.statusAtivo
categoriaItemCatalogo_statusAtivo <- conta_preenchimento(itens, "categoriaItemCatalogo.statusAtivo", quantidades_ano)

itens %>% distinct(categoriaItemCatalogo.statusAtivo)

itens %>%
  filter(!is.na(categoriaItemCatalogo.statusAtivo)) %>%
  select(endpoint, categoriaItemCatalogo.statusAtivo)

# ---


# informacaoComplementar
informacaoComplementar <- conta_preenchimento(itens, "informacaoComplementar", quantidades_ano)

itens %>% distinct(informacaoComplementar)

itens %>%
  filter(!is.na(informacaoComplementar)) %>%
  select(endpoint, informacaoComplementar)

# ---


# ncmNbsCodigo
ncmNbsCodigo <- conta_preenchimento(itens, "ncmNbsCodigo", quantidades_ano)

itens %>% distinct(ncmNbsCodigo)

itens %>%
  filter(!is.na(ncmNbsCodigo)) %>%
  select(endpoint, ncmNbsCodigo) %>%
  print(n = Inf)

# ---


# ncmNbsDescricao
ncmNbsDescricao <- conta_preenchimento(itens, "ncmNbsDescricao", quantidades_ano)

itens %>% distinct(ncmNbsDescricao)

itens %>%
  filter(!is.na(ncmNbsDescricao)) %>%
  select(endpoint, ncmNbsDescricao) %>%
  print(n = Inf)

# ---

# os casos a seguir não retornaram resultados (100% NA's)

# categoriaItemCatalogo.descricao
categoriaItemCatalogo_descricao <- conta_preenchimento(itens, "categoriaItemCatalogo.descricao", quantidades_ano)

# categoriaItemCatalogo
categoriaItemCatalogo <- conta_preenchimento(itens, "categoriaItemCatalogo", quantidades_ano)

# catalogo
catalogo <- conta_preenchimento(itens, "catalogo", quantidades_ano)

# ---

# juntando todos resultados
resultados_preenchimento <- bind_rows(
  categoriaItemCatalogo_dataAtualizacao,
  categoriaItemCatalogo,
  catalogo,
  catalogoCodigoItem,
  catalogo_id,
  catalogo_nome,
  catalogo_descricao,
  catalogo_dataInclusao,
  catalogo_dataAtualizacao,
  catalogo_statusAtivo,
  catalogo_url,
  categoriaItemCatalogo_id,
  categoriaItemCatalogo_nome,
  categoriaItemCatalogo_descricao,
  categoriaItemCatalogo_dataInclusao,
  categoriaItemCatalogo_statusAtivo,
  informacaoComplementar,
  ncmNbsCodigo,
  ncmNbsDescricao
)

# Visualizar resultados
resultados_preenchimento

# Visualizar resultados
resultados_preenchimento %>%
  select(var, ano, n, perc) %>%
  complete(ano, var) %>%
  arrange(var) %>%
  gt::gt() %>%
  gt::fmt_missing()
