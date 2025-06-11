# :: LIBS ----------------------------------------------------------------------
library(tidyverse)
library(here)
library(jsonlite)
options(width = 150)
source(here("src/ETL/loaders/utils.R"))

# :: FILEPATTHS ----------------------------------------------------------------
CAMINHO_CATALOGO <- here("data/catmat/catmat.rds")


# :: CUT-OFF CARACTERISTICAS ---------------------------------------------------
MAX_CARACTERISTICAS <- 3 # Número máximo de características a manter por medicamento (por PDM)


# :: CATMAT --------------------------------------------------------------------
catalogo <- readRDS(CAMINHO_CATALOGO)


# :: OMEPRAZOL -----------------------------------------------------------------

# seleciona somente Omeprazol
catalogo_omeprazol <- catalogo %>%
  filter(nome_pdm == "Omeprazol")

# Desaninha a coluna "buscaItemCaracteristica"
catalogo_omeprazol <- catalogo_omeprazol %>% unnest(buscaItemCaracteristica)

# de-para para corrigir os códigos de características
dicionario_caracteristica <- catalogo_omeprazol %>%
  distinct(nomeCaracteristica, codigoCaracteristica)

# Corrige características manualmente
catalogo_omeprazol <- catalogo_omeprazol %>%
  mutate(
    nomeCaracteristica = case_when(
      nomeCaracteristica == "Característica Adicional" ~ "Composição",
      nomeCaracteristica == "Uso" ~ "Forma Farmacêutica",
      # nomeCaracteristica == "Apresentação" ~ "Forma Farmacêutica",
      # nomeCaracteristica == "Concentração" ~ "Dosagem",
      .default = nomeCaracteristica
    )
  ) %>%
  select(-codigoCaracteristica) %>%
  left_join(dicionario_caracteristica)

# precisa aglutinar características que estão saindo duplicadas
catalogo_omeprazol <- catalogo_omeprazol %>%
  group_nest(codigo_br) %>%
  mutate(
    data = map(data, ~ mutate(.x, nomeValorCaracteristica = paste0(nomeValorCaracteristica, collapse = ", "), .by = nomeCaracteristica)),
    data = map(data, distinct, nomeValorCaracteristica, .keep_all = TRUE)
  ) %>%
  unnest(data)

# Cria um  dataframe com as caracteristicas que serão mantidas para cada medicamento
caracteristicas_omeprazol <- catalogo_omeprazol %>%
  summarise(
    # Agrupa por PDM e nomeCaracteristica (corrigido manualmente)
    .by = c(codigo_pdm, codigoCaracteristica),
    n_valores_unicos = n_distinct(nomeValorCaracteristica),
  ) %>%
  group_by(codigo_pdm) %>%
  slice_max(n = MAX_CARACTERISTICAS, order_by = n_valores_unicos, with_ties = FALSE) %>%
  # filter(n_valores_unicos > 1) %>%
  mutate(manter = TRUE) %>%
  ungroup()

# Marca no catálogo as caracteristicas que serão utilizadas (manter == TRUE)
catalogo_omeprazol <- catalogo_omeprazol %>%
  left_join(caracteristicas_omeprazol, by = c("codigo_pdm", "codigoCaracteristica"))

# Reaninha as características dentro do catálogo
# Reaninha antes de excluir as características para não correr o risco de excluir
# medicamentos que possuam apenas uma característica com um único valor.
# Exemplo: Hidróxido De Alumínio, Indicação:300mg (codigo br: 267271)
catalogo_omeprazol <- catalogo_omeprazol %>%
  select(-n_valores_unicos) %>%
  group_by(codigo_br) %>%
  nest(
    buscaItemCaracteristica = c(
      codigoCaracteristica,
      codigoValorCaracteristica,
      nomeCaracteristica,
      caracteristicaObrigatoria,
      statusCaracteristica,
      numeroCaracteristica,
      nomeValorCaracteristica,
      siglaUnidadeMedida,
      statusValorCaracteristica,
      manter
    )
  ) %>%
  ungroup() %>%
  glimpse()

# Filtra as características dentro do dataframe aninhado
catalogo_omeprazol <- catalogo_omeprazol %>%
  mutate(buscaItemCaracteristica = map(buscaItemCaracteristica, ~ filter(.x, manter == TRUE)))


# TRANSFORMA A TABELA ----------------------------------------------------------

tb_catalogo <- catalogo_omeprazol %>%
  select(all_of(COLUNAS_CATALOGO)) %>%
  mutate( # Seleciona atributos de interesse
    características = map(buscaItemCaracteristica, ~ select(.x, nomeCaracteristica, nomeValorCaracteristica))
  ) %>%
  mutate( # transforma as características em um JSON
    características = map(características, ~ toJSON(.x, auto_unbox = TRUE)),
    unidade_fornecimento = map(unidadeFornecimento, ~ toJSON(.x, auto_unbox = TRUE))
  ) %>%
  mutate( # transforma o JSON em character (string)
    características = as.character(características),
    unidade_fornecimento = as.character(unidade_fornecimento)
  ) %>%
  select(-buscaItemCaracteristica, -unidadeFornecimento)


# INSERE OS DADOS --------------------------------------------------------------

# CONECTA-SE  COM O BD
con <- conecta_bd_medicamentos_transparentes()

# envia comando para SQL
insere_tabela(con, tabela = tb_catalogo, consulta = CONSULTA_UPDATE_CATALOGO)

# Fechar conexão
dbDisconnect(con)
