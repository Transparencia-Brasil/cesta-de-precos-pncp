library(tidyverse)
library(here)

source(here("setup/rsetup.R"))


# FILEPATHS --------------------------------------------------------------------

PATH_MEDICAMENTOS_2024 <- here("tasks/unifica-dados/output/medicamentos.csv")

PATH_MEDICAMENTOS_2025 <- list.files(
  path = here("coleta/itens"),
  pattern = "medicamentos.csv",
  recursive = TRUE,
  full.names = TRUE
)[-6]

PATH_RESULTADOS_2025 <- list.files(
  path = here("coleta/resultados"),
  pattern = "dados.csv",
  recursive = TRUE,
  full.names = TRUE
)[-6]

# READ DATA --------------------------------------------------------------------

medicamentos_2024 <- read_csv(PATH_MEDICAMENTOS_2024, col_types = list(.default = col_character())) %>%
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

medicamentos_2025 <- map_df(PATH_MEDICAMENTOS_2025, read_csv, col_types = list(.default = col_character())) %>%
  select(
    endpoint, numeroItem, dataInclusao, dataAtualizacao,
    descricao, unidadeMedida, valorTotal, quantidade,
    unidadeMedida,
    contains("atalogo"),
    informacaoComplementar,
    starts_with("ncm"),
  )

medicamentos_2024 <- medicamentos_2024 %>%
  mutate(
    endpoint = sprintf("%s/%s", endpoint, numeroItem),
    id = "medicamentos_2024"
  )

medicamentos_2025 <- medicamentos_2025 %>%
  mutate(
    endpoint = sprintf("%s/%s", endpoint, numeroItem),
    id = "medicamentos_2025"
  )

glimpse(medicamentos_2024)
glimpse(medicamentos_2025)


# COUNT ALL --------------------------------------------------------------------

medicamentos <- bind_rows(medicamentos_2024, medicamentos_2025)

quantidades <- medicamentos %>%
  count(id, ano = year(dataInclusao), mes = month(dataInclusao)) %>%
  mutate(data = my(sprintf("%s/%s", mes, ano))) %>%
  summarise(.by = c(id, data), n = sum(n))

quantidades %>%
  mutate(id = fct_reorder(id, -as.numeric(str_remove(id, "medicamentos_")))) %>%
  ggplot(aes(x = data, y = n, fill = id)) +
  geom_col() +
  labs(
    title = "Quantidade de *medicamentos* coletados do PNCP - por mês",
    subtitle = "Ex: https:\\/\\/pncp.gov.br\\/api\\/pncp\\/v1\\/orgaos\\/**{cnpj}**\\/compras\\/**{ano}**\\/**{sequencial}**\\/itens/**{numeroItem}**",
    x = NULL,
    y = "<br>Quantidade de *medicamentos* coletados", fill = "Coleta"
  ) +
  scale_x_date(date_labels = "%b-%y", date_breaks = "1 months", expand = c(0, 0)) +
  scale_y_continuous(labels = numero, breaks = seq(0, 3e4, length.out = 6), limits = c(0, 4e4), expand = c(0, 0), position = "right") +
  theme(
    axis.text.x = ggtext::element_markdown(angle = 45, hjust = 1),
    legend.position = c(.15, .9),
    legend.direction = "horizontal",
    legend.title.position = "top"
  )


# FILTER -----------------------------------------------------------------------

rm(medicamentos)
rm(quantidades)

medicamentos_2024_filtrado <- medicamentos_2024 %>%
  filter(year(dataInclusao) == 2024) %>%
  filter(month(dataInclusao) >= 10)

medicamentos_2025_filtrado <- medicamentos_2025 %>%
  filter(
    (year(dataInclusao) >= 2024 &
      month(dataInclusao) %in% c(10, 11, 12)) |
      (year(dataInclusao) >= 2025)
  ) %>%
  mutate(id = "medicamentos_2025")

medicamentos <- bind_rows(medicamentos_2024_filtrado, medicamentos_2025_filtrado)


# COUNT FILTRADO ---------------------------------------------------------------

quantidades <- medicamentos %>%
  count(id, ano = year(dataInclusao), mes = month(dataInclusao)) %>%
  mutate(data = my(sprintf("%s/%s", mes, ano))) %>%
  summarise(.by = c(id, data), n = sum(n))

quantidades %>%
  ggplot(aes(x = data, y = n, fill = id)) +
  geom_col() +
  geom_text(aes(label = numero(n)), size = 6, position = position_stack(vjust = .5)) +
  labs(
    title = "Quantidade de *medicamentos* coletados do PNCP - por mês",
    subtitle = "Ex: https:\\/\\/pncp.gov.br\\/api\\/pncp\\/v1\\/orgaos\\/**{cnpj}**\\/compras\\/**{ano}**\\/**{sequencial}**\\/itens/**{numeroItem}**",
    x = NULL,
    y = "<br>Quantidade de *medicamentos* coletados", fill = "Coleta"
  ) +
  scale_x_date(date_labels = "%b/%Y") +
  scale_y_continuous(labels = numero, breaks = seq(0, 1.5e4, length.out = 6), limits = c(0, 2e4), expand = c(0, 0), position = "right") +
  theme(
    legend.position = c(.2, .9),
    legend.direction = "horizontal",
    legend.title.position = "top"
  )

quantidades_ano <- count(quantidades, ano = year(data), wt = n, name = "qt_ano")

# Quantidade de itens - Total
nrow(medicamentos)


# PREENCHIMENTO CATALOGO -------------------------------------------------------

#' Calcular a proporção de preenchimento de uma coluna por ano
#'
#' @param medicamentos Dataframe contendo os medicamentos a serem analisados
#' @param coluna String com o nome da coluna a ser verificada
#' @param quantidades_ano Dataframe com as quantidades totais por ano
#'
#' @return Dataframe com contagem e percentual de preenchimento da coluna por ano
conta_preenchimento <- function(medicamentos, coluna, quantidades_ano) {
  medicamentos %>%
    filter(!is.na(!!sym(coluna))) %>%
    count(ano = year(dataInclusao)) %>%
    left_join(quantidades_ano) %>%
    mutate(perc = perc(n / qt_ano, accuracy = .1)) %>%
    mutate(var = coluna)
}

# ---

# catalogo.dataInclusao
catalogo_dataInclusao <- conta_preenchimento(medicamentos, "catalogo.dataInclusao", quantidades_ano)

medicamentos %>% distinct(catalogo.dataInclusao)

medicamentos %>%
  filter(!is.na(catalogo.dataInclusao)) %>%
  select(endpoint, catalogo.dataInclusao)

# ---


# catalogo.dataAtualizacao
catalogo_dataAtualizacao <- conta_preenchimento(medicamentos, "catalogo.dataAtualizacao", quantidades_ano)

medicamentos %>% distinct(catalogo.dataAtualizacao)

medicamentos %>%
  filter(!is.na(catalogo.dataAtualizacao)) %>%
  select(endpoint, catalogo.dataAtualizacao)

# ---


# catalogo.descricao
catalogo_descricao <- conta_preenchimento(medicamentos, "catalogo.descricao", quantidades_ano)

medicamentos %>% distinct(catalogo.descricao)

medicamentos %>%
  filter(!is.na(catalogo.descricao)) %>%
  select(endpoint, catalogo.descricao)

# ---


# catalogo.id
catalogo_id <- conta_preenchimento(medicamentos, "catalogo.id", quantidades_ano)

medicamentos %>% distinct(catalogo.id)

medicamentos %>%
  filter(!is.na(catalogo.id)) %>%
  select(endpoint, catalogo.id)

# ---


# catalogo.nome
catalogo_nome <- conta_preenchimento(medicamentos, "catalogo.nome", quantidades_ano)


medicamentos %>% distinct(catalogo.nome)

medicamentos %>%
  filter(!is.na(catalogo.nome)) %>%
  select(endpoint, catalogo.nome)

# ---

# catalogo.statusAtivo
catalogo_statusAtivo <- conta_preenchimento(medicamentos, "catalogo.statusAtivo", quantidades_ano)

medicamentos %>% distinct(catalogo.statusAtivo)

medicamentos %>%
  filter(!is.na(catalogo.statusAtivo)) %>%
  select(endpoint, catalogo.statusAtivo)

# ---


# catalogo.url
catalogo_url <- conta_preenchimento(medicamentos, "catalogo.url", quantidades_ano)

medicamentos %>% distinct(catalogo.url)

medicamentos %>%
  filter(!is.na(catalogo.url)) %>%
  select(endpoint, catalogo.url)

# ---


# catalogoCodigoItem
catalogoCodigoItem <- conta_preenchimento(medicamentos, "catalogoCodigoItem", quantidades_ano)

medicamentos %>%
  distinct(catalogoCodigoItem) %>%
  print(n = Inf)

medicamentos %>%
  filter(!is.na(catalogoCodigoItem)) %>%
  View()
select(endpoint, catalogoCodigoItem)

# ---


# categoriaItemCatalogo.dataAtualizacao
categoriaItemCatalogo_dataAtualizacao <- conta_preenchimento(medicamentos, "categoriaItemCatalogo.dataAtualizacao", quantidades_ano)

medicamentos %>% distinct(categoriaItemCatalogo.dataAtualizacao)

medicamentos %>%
  filter(!is.na(categoriaItemCatalogo.dataAtualizacao)) %>%
  select(endpoint, categoriaItemCatalogo.dataAtualizacao)

# ---

# categoriaItemCatalogo.dataInclusao
categoriaItemCatalogo_dataInclusao <- conta_preenchimento(medicamentos, "categoriaItemCatalogo.dataInclusao", quantidades_ano)

medicamentos %>% distinct(categoriaItemCatalogo.dataInclusao)

medicamentos %>%
  filter(!is.na(categoriaItemCatalogo.dataInclusao)) %>%
  select(endpoint, categoriaItemCatalogo.dataInclusao)

# ---


# categoriaItemCatalogo.id
categoriaItemCatalogo_id <- conta_preenchimento(medicamentos, "categoriaItemCatalogo.id", quantidades_ano)

medicamentos %>% distinct(categoriaItemCatalogo.id)

medicamentos %>%
  filter(!is.na(categoriaItemCatalogo.id)) %>%
  select(endpoint, categoriaItemCatalogo.id)

# ---


# categoriaItemCatalogo.nome
categoriaItemCatalogo_nome <- conta_preenchimento(medicamentos, "categoriaItemCatalogo.nome", quantidades_ano)

medicamentos %>% distinct(categoriaItemCatalogo.nome)

medicamentos %>%
  filter(!is.na(categoriaItemCatalogo.nome)) %>%
  select(endpoint, categoriaItemCatalogo.nome)

# ---


# categoriaItemCatalogo.statusAtivo
categoriaItemCatalogo_statusAtivo <- conta_preenchimento(medicamentos, "categoriaItemCatalogo.statusAtivo", quantidades_ano)

medicamentos %>% distinct(categoriaItemCatalogo.statusAtivo)

medicamentos %>%
  filter(!is.na(categoriaItemCatalogo.statusAtivo)) %>%
  select(endpoint, categoriaItemCatalogo.statusAtivo)

# ---


# informacaoComplementar
informacaoComplementar <- conta_preenchimento(medicamentos, "informacaoComplementar", quantidades_ano)

medicamentos %>% distinct(informacaoComplementar)

medicamentos %>%
  filter(!is.na(informacaoComplementar)) %>%
  select(endpoint, informacaoComplementar) %>%
  View()

# ---


# ncmNbsCodigo
ncmNbsCodigo <- conta_preenchimento(medicamentos, "ncmNbsCodigo", quantidades_ano)

medicamentos %>% distinct(ncmNbsCodigo)

medicamentos %>%
  filter(!is.na(ncmNbsCodigo)) %>%
  select(endpoint, ncmNbsCodigo) %>%
  print(n = Inf)

# ---


# ncmNbsDescricao
ncmNbsDescricao <- conta_preenchimento(medicamentos, "ncmNbsDescricao", quantidades_ano)

medicamentos %>% distinct(ncmNbsDescricao)

medicamentos %>%
  filter(!is.na(ncmNbsDescricao)) %>%
  select(endpoint, ncmNbsDescricao) %>%
  print(n = Inf)

# ---

# os casos a seguir não retornaram resultados (100% NA's)

# categoriaItemCatalogo.descricao
categoriaItemCatalogo_descricao <- conta_preenchimento(medicamentos, "categoriaItemCatalogo.descricao", quantidades_ano)

# categoriaItemCatalogo
categoriaItemCatalogo <- conta_preenchimento(medicamentos, "categoriaItemCatalogo", quantidades_ano)

# catalogo
catalogo <- conta_preenchimento(medicamentos, "catalogo", quantidades_ano)

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

medicamentos_2025 <- map_df(PATH_MEDICAMENTOS_2025, read_csv, col_types = list(.default = col_character())) %>%
  select(
    endpoint, numeroItem,
    descricao, unidadeMedida, valorTotal, quantidade,
    codigo_pdm, codigo_br
    # contains("atalogo"),
    # informacaoComplementar,
    # starts_with("ncm"),
  )

medicamentos_2025 <- medicamentos_2025 %>%
  mutate(endpoint = sprintf("%s/%s/resultados", endpoint, numeroItem))

resultados_2025 <- map_df(PATH_RESULTADOS_2025, read_csv, col_types = list(.default = col_character())) %>%
  select(
    endpoint, numeroItem, sequencialResultado, quantidadeHomologada,
    valorUnitarioHomologado, valorTotalHomologado
  )


medicamentos_2025 %>% glimpse()
resultados_2025 %>% glimpse()

left_join(distinct(medicamentos_2025), resultados_2025) %>%
  filter(!is.na(sequencialResultado)) %>%
  rename(endpointResultado = endpoint) %>%
  mutate(endpointItem = str_remove(endpointResultado, "/resultados")) %>%
  relocate(contains("endpoint"), .after = everything()) %>%
  googlesheets4::write_sheet(
    "https://docs.google.com/spreadsheets/d/1flrHYL0np5liCciJRXROARa9AlhQDSvwmhmmWvqdu7g"
  )


resultados_2025 %>%
  slice(1385) %>%
  pull(endpoint)

medicamentos_2025 %>%
  filter(endpoint == "https://pncp.gov.br/api/pncp/v1/orgaos/46374500000194/compras/2024/11085/itens/3/resultados")

resultados_2025$endpoint[1]
medicamentos_2025$endpoint[1]
