library(tidyverse)
library(here)

PATH_DATA_PACKAGES <- here("coleta/data-package/2025")

PATH_ITENS <- PATH_DATA_PACKAGES %>%
  list.files(recursive = TRUE, pattern = "itens-medicamentos.csv", full.names = TRUE)

PATH_ALL_ITENS <- PATH_DATA_PACKAGES %>%
  list.files(recursive = TRUE, pattern = "itens.csv", full.names = TRUE)

PATH_CONTRATACOES <- PATH_DATA_PACKAGES %>%
  list.files(recursive = TRUE, pattern = "contratacoes.csv", full.names = TRUE)

PATH_CARACTERISTICAS_OCDS <- "C:/Users/rdurl/OneDrive/Documentos/pncp-analises/tasks/pncp-data-quality-spin-offs/output/caracteristicas-ocds.rds"

PLAN_SIMILARIDADE <- "https://docs.google.com/spreadsheets/d/1lysUjnk5xn0j-zwG0Y1hdesEqNH9Lax9RzvDVKyH4is"

PATH_MEDICAMENTOS_BAIXA_SIMILARIDADE <- here("tasks/experimento-LLM/inputs/medicamentos-baixa-similaridade.csv")

# DATA -------------------------------------------------------------------------

all_itens <- map_df(
  PATH_ALL_ITENS,
  read_csv,
  col_types = cols(.default = col_character())
)

medicamentos <- map_df(
  PATH_ITENS,
  read_csv,
  col_types = cols(.default = col_character())
)

contratacoes <- map_df(
  PATH_CONTRATACOES,
  read_csv,
  col_types = cols(.default = col_character())
)

medicamentos_baixa_similaridade <- read_csv(
  PATH_MEDICAMENTOS_BAIXA_SIMILARIDADE,
  col_types = cols(.default = col_character())
)

med <- medicamentos %>%
  transmute(
    numeroItem,
    endpoint,
    descricao,
    quantidade,
    valorTotalEstimado = as.double(quantidade) * as.double(valorUnitarioEstimado),
    unidadeMedida,
    codigo_pdm,
    codigo_br,
    similaridade = as.double(similaridade),
    dataInclusao
  ) %>%
  distinct()

med_baixa_similaridade <- medicamentos_baixa_similaridade %>%
  transmute(
    numeroItem,
    endpoint,
    descricao,
    quantidade,
    valorTotalEstimado = as.double(quantidade) * as.double(valorUnitarioEstimado),
    unidadeMedida,
    codigo_pdm,
    codigo_br,
    similaridade = as.double(similaridade),
    dataInclusao
  ) %>%
  distinct()

cont <- contratacoes %>%
  transmute(
    orgao_cnpj = data.orgaoEntidade.cnpj,
    orgao_nome = case_when(
      data.orgaoEntidade.razaoSocial == "CONSORCIO REGIONAL DE RESIDUOS SOLIDOS DO AGRESTE ALAGOANO" ~ "CONSORCIO INTERMUNICIPAL DO AGRESTE ALAGOANO - CONAGRESTE",
      .default = data.orgaoEntidade.razaoSocial
    ),
    orgao_municipio = data.unidadeOrgao.municipioNome,
    orgao_uf = data.unidadeOrgao.ufSigla,
    orgao_esfera = data.orgaoEntidade.esferaId,
    ano_compra = data.anoCompra,
    sistema = case_when(
      data.usuarioNome == "North Tecnologia Sistemas e Informatica" ~ "NORTH TECNOLOGIA SISTEMAS E INFORMATICA LTDA",
      .default = data.usuarioNome
    ),
    sequencial_compra = data.sequencialCompra,
    endpoint = sprintf(
      "https://pncp.gov.br/api/pncp/v1/orgaos/%s/compras/%s/%s/itens",
      data.orgaoEntidade.cnpj, data.anoCompra, data.sequencialCompra
    )
  ) %>%
  filter(!str_detect(sistema, "^\\d+$")) %>%
  distinct()

itens <- left_join(med, cont)
itens_baixa_similaridade <- left_join(med_baixa_similaridade, cont)

# READ OCDS DATA ---------------------------------------------------------------

catmat_ocds <- readRDS(PATH_CARACTERISTICAS_OCDS)


# CONTAGEM CARACTERISTICAS - CATMAT --------------------------------------------

catmat_ocds <- catmat_ocds %>%
  # mutate(principio_ativo = if_else(principio_ativo == nome_pdm, "", principio_ativo)) %>%
  mutate(
    possui_principio_ativo = !is.na(principio_ativo),
    possui_dosagem = !is.na(dosagem),
    possui_forma_farmaceutica = !is.na(forma_farmaceutica),
    possui_uso = !is.na(uso),
    possui_forma_apresentacao = !is.na(forma_apresentacao)
  ) %>%
  mutate(
    total_caracteristicas = possui_principio_ativo +
      possui_forma_farmaceutica +
      possui_uso +
      possui_forma_apresentacao +
      possui_dosagem
  ) %>%
  group_nest(codigo_pdm, nome_pdm) %>%
  mutate(
    minimo_caracteristicas = map_int(data, ~ min(.x$total_caracteristicas)),
    maximo_caracteristicas = map_int(data, ~ max(.x$total_caracteristicas)),
    total_principio_ativo = map_int(data, ~ nrow(.x %>% filter(!is.na(principio_ativo)))),
    total_dosagem = map_int(data, ~ nrow(.x %>% filter(!is.na(dosagem)))),
    total_forma_farmaceutica = map_int(data, ~ nrow(.x %>% filter(!is.na(forma_farmaceutica)))),
    total_forma_apresentacao = map_int(data, ~ nrow(.x %>% filter(!is.na(forma_apresentacao)))),
    total_uso = map_int(data, ~ nrow(.x %>% filter(!is.na(uso)))),
    total_codigobr = map_int(data, nrow),
  ) %>%
  unnest(data)


catmat_ocds %>%
  googlesheets4::write_sheet(
    ss = PLAN_SIMILARIDADE,
    sheet = "catmat"
  )

catmat_odcs_range_caracteristicas <- catmat_ocds %>%
  distinct(codigo_pdm, minimo_caracteristicas, maximo_caracteristicas)


# PATH_ITENS <- here("tasks/experimento-LLM/inputs/demais-items.csv")

# anti_join(all_itens, itens[,2]) %>%
#   write_csv(PATH_ITENS)

# itens %>%
#   filter(similaridade <= .6) %>%
#   filter(sistema != "Compras.gov.br") %>%
#   googlesheets4::write_sheet(
#     ss = PLAN_SIMILARIDADE,
#     sheet = "itens_similaridade_abaixo_60"
#   )

# itens_baixa_similaridade %>%
#   filter(sistema != "Compras.gov.br") %>%
#   googlesheets4::write_sheet(
#     ss = PLAN_SIMILARIDADE,
#     sheet = "itens_similaridade_abaixo_50"
#   )


bind_rows(itens_baixa_similaridade, itens) %>%
  filter(sistema == "Compras.gov.br") %>%
  filter(ano_compra == 2025) %>%
  select(
    orgao_cnpj, sequencial_compra, ano_compra, numeroItem, endpoint,
    descricao, dataInclusao
  ) %>%
  mutate(dataInclusao = as_date(dataInclusao)) %>%
  filter(dataInclusao >= dmy("01-03-2025")) %>%
  glimpse()
# googlesheets4::write_sheet(
#   ss = "https://docs.google.com/spreadsheets/d/1RX7oHGxdJv2tWAtU93GsZQQpdO-p8gQ9VarEIqTyQJE",
#   sheet = "relação de endpoints"
# )

bind_rows(itens_baixa_similaridade, itens) %>%
  filter(sistema != "Compras.gov.br") %>%
  filter(similaridade >= .4) %>%
  mutate(valor_baixa_similaridade = if_else(similaridade <= .6, valorTotalEstimado, 0)) %>%
  summarise(
    .by = c(orgao_cnpj, orgao_nome, orgao_municipio, orgao_uf, orgao_esfera),
    qtde_itens = n(),
    # total_itens_distintos = n_distinct(descricao),
    valorTotalEstimado = sum(valorTotalEstimado, na.rm = TRUE),
    # media_similaridade = mean(similaridade, na.rm = TRUE),
    # total_similaridade_ate_50 = sum(similaridade <= 0.5),
    # total_similaridade_ate_60 = sum(similaridade <= 0.6),
    valor_baixa_similaridade = sum(valor_baixa_similaridade, na.rm = TRUE),
    # total_similaridade_acima_60 = sum(similaridade > 0.6)
  ) %>%
  mutate(perc_valor_baixa_similaridade = valor_baixa_similaridade / valorTotalEstimado) %>%
  filter(valorTotalEstimado >= 1000000) %>%
  filter(qtde_itens >= 50) %>%
  slice_max(perc_valor_baixa_similaridade, n = 50) %>%
  glimpse()
  # googlesheets4::write_sheet(
  #   ss = PLAN_SIMILARIDADE,
  #   sheet = "Top 50 orgaos com baixa similaridade - por valor"
  # )


  bind_rows(itens_baixa_similaridade, itens) %>%
    filter(sistema != "Compras.gov.br") %>%
    filter(similaridade >= .4) %>%
    summarise(
      .by = c(orgao_cnpj, orgao_nome, orgao_municipio, orgao_uf, orgao_esfera),
      qtde_itens = n(),
      # media_similaridade = mean(similaridade, na.rm = TRUE),
      # total_similaridade_ate_50 = sum(similaridade <= 0.5),
      qtde_similaridade_ate_60 = sum(similaridade <= 0.6),
      # valor_baixa_similaridade = sum(valor_baixa_similaridade, na.rm = TRUE),
      # total_similaridade_acima_60 = sum(similaridade > 0.6)
    ) %>%
    mutate(perc_qtde_baixa_similaridade = qtde_similaridade_ate_60 / qtde_itens) %>%
    filter(qtde_itens >= 50) %>%
    slice_max(perc_qtde_baixa_similaridade, n = 50) %>%
    glimpse()
  # googlesheets4::write_sheet(
  #   ss = PLAN_SIMILARIDADE,
  #   sheet = "Top 50 orgaos com baixa similaridade - por quantidade"
  # )

bind_rows(itens_baixa_similaridade, itens) %>%
  filter(sistema != "Compras.gov.br") %>%
  filter(similaridade >= .4) %>%
  mutate(valor_baixa_similaridade = if_else(similaridade <= .6, valorTotalEstimado, 0)) %>%
  summarise(
    .by = c(orgao_cnpj, orgao_nome, orgao_municipio, orgao_uf, orgao_esfera),
    qtde_itens = n(),
    qtde_similaridade_ate_60 = sum(similaridade <= 0.6),
    valorTotalEstimado = sum(valorTotalEstimado, na.rm = TRUE),
    valor_baixa_similaridade = sum(valor_baixa_similaridade, na.rm = TRUE),
  ) %>%
  mutate(
    perc_valor_baixa_similaridade = valor_baixa_similaridade / valorTotalEstimado,
    perc_qtde_baixa_similaridade = qtde_similaridade_ate_60 / qtde_itens
  ) %>%
  filter(valorTotalEstimado >= 1000000) %>%
  filter(qtde_itens >= 50) %>%
  arrange(desc(valorTotalEstimado), desc(qtde_itens)) %>%
  googlesheets4::write_sheet(
    ss = PLAN_SIMILARIDADE,
    sheet = "Órgaos com baixa similaridade"
  )


bind_rows(itens_baixa_similaridade, itens) %>%
  filter(sistema != "Compras.gov.br") %>%
  filter(similaridade >= .4) |>
  filter(similaridade <= .5) |>
  arrange(desc(similaridade)) |>
  View()

itens |>
  # filter(sistema == "ECustomize Consultoria em Software S.A") |>
  filter(sistema != "Compras.gov.br") |>
  distinct(descricao) |>
  mutate(descricao2 = limpa_texto(descricao)) |>
  filter(str_detect(descricao2, "aciclovir")) |>
  filter(str_detect(descricao2, "200mg")) |>
  googlesheets4::write_sheet(
    ss = PLAN_SIMILARIDADE,
    sheet = "Variantes de Aciclovir - ECustomize"
  )

limpa_texto <- function(texto) {
  # Carrega pacotes necessários
  texto |>
    tolower() |>
    stringr::str_replace_all("[[:punct:]]", " ") |>
    stringr::str_squish() |>
    stringi::stri_trans_general(id = "Latin-ASCII")
}

itens |>
  filter(sistema == "ECustomize Consultoria em Software S.A") |>
  distinct(descricao) |>
  arrange()


itens |>
  # filter(sistema == "ECustomize Consultoria em Software S.A") |>
  filter(sistema != "Compras.gov.br") |>
  filter(str_detect(tolower(descricao), "paracetamol")) |>
  distinct(descricao, unidadeMedida, quantidade) |>
  View()


itens |>
  filter(str_detect(tolower(descricao), "marca")) |>
  distinct(descricao, unidadeMedida, quantidade) |>
  print(n = Inf)


itens |>
  filter(descricao == "TRAMADOL 50 MG+ MELOXICAM 7,5 MG + PARACETAMOL 750 MG+ CICLOBENZAPRINA 5MG + FAMOTIDINA 20 MG+ PREDNISONA 5 MG, FRASCO CONTENDO 60 CAPSULAS.") |>
  glimpse()

itens_baixa_similaridade |>
  filter(sistema != "Compras.gov.br") |>
  filter(similaridade >= .45) |>
  distinct(descricao, unidadeMedida, quantidade) |>
  arrange(descricao) |>
  sample_n(150) |>
  print(n = Inf)

itens_baixa_similaridade |>
  filter(descricao == "02.02.01.018-0 DOSAGEM DE AMILASE\n02.02.01.055-4 DOSAGEM DE LIPASE\n02.02.07.025-5 DOSAGEM DE LITIO") |>
  select(endpoint, descricao)


options(width = 150)

itens |>
  filter(between(similaridade, 0.8, 0.81)) |>
  sample_n(1) |>
  glimpse()

"Acido Poliacrílico 2mg/g - Gel Oftalmico (7250)"
"Acetato de Medroxiprogesterona 150 mg/ml, suspensão injetável via intramuscular"
"Adenosina 3 mg/mL solução injetável, 2mL"