library(tidyverse)
library(here)
library(DBI)


source(here("src/ETL/loaders/utils.R"))

PATH_CONTRATACOES <- here("tasks/alteracoes-no-banco-de-dados/sistemas-de-contratacao/inputs/contratacoes-db.rds")

dir.create(dirname(PATH_CONTRATACOES), recursive = TRUE, showWarnings = FALSE)

# CONECTA-SE  COM O BD ----------------------------------------------------

con <- conecta_bd_medicamentos_transparentes()

get_query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")

contratacoes <- get_query("select distinct numero_controle_pncp from contratacao")
saveRDS(contratacoes, PATH_CONTRATACOES)
