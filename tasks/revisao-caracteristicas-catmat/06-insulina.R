# :: LIBS ----------------------------------------------------------------------
library(tidyverse)
library(here)
library(jsonlite)
options(width = 150)

source(here("src/ETL/loaders/utils.R"))
source(here("tasks/revisao-caracteristicas-catmat/utils.R"))

# :: FILEPATTHS ----------------------------------------------------------------
CAMINHO_CATALOGO <- here("data/catmat/catmat.rds")


# :: CUT-OFF CARACTERISTICAS ---------------------------------------------------
MAX_CARACTERISTICAS <- 3 # Número máximo de características a manter por medicamento (por PDM)


# :: CATMAT --------------------------------------------------------------------
catalogo <- readRDS(CAMINHO_CATALOGO)


# :: DATA-WRANGLING ------------------------------------------------------------

med <- consulta_catalogo(catalogo = catalogo, "Insulina")

med$catalogo <- med$catalogo %>%
  mutate(
    nomeCaracteristica = case_when(
      nomeCaracteristica == "Adicionais" ~ "Forma Farmacêutica",
      nomeCaracteristica == "Aplicação" ~ "Forma Farmacêutica",
      nomeCaracteristica == "Dosagem" ~ "Concentração",
      nomeCaracteristica == "Origem" ~ "Tipo",
      nomeCaracteristica == "Caracteristica Adicional" ~ "Tipo",
      nomeCaracteristica == "Característica Adicional" ~ "Tipo",
      nomeCaracteristica == "Composição" ~ "Tipo",
      .default = nomeCaracteristica
    )
  ) %>%
  select(-codigoCaracteristica) %>%
  left_join(med$dicionario_caracteristica)

med$catalogo <- concatena_caracteristicas_multiplas(med$catalogo)

med$caracteristicas <- agrupa_caracteristicas(med$catalogo)

# Marca no catálogo as caracteristicas que serão utilizadas (manter == TRUE)
med$catalogo <- med$catalogo %>%
  left_join(med$caracteristicas, by = c("codigo_pdm", "codigoCaracteristica"))

med$catalogo <- reaninha_caracteristicas(med$catalogo)

tb_catalogo <- transform_catalogo_to_db(med$catalogo)

# INSERE OS DADOS --------------------------------------------------------------

# CONECTA-SE  COM O BD
con <- conecta_bd_medicamentos_transparentes()

# envia comando para SQL
insere_tabela(con, tabela = tb_catalogo, consulta = CONSULTA_UPDATE_CATALOGO)

# Fechar conexão
dbDisconnect(con)
