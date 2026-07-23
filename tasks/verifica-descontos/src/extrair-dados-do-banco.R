library(here)
library(tidyverse)

source(here("src/ETL/loaders/utils.R"))
source(here("src/ETL/loaders/utils-historico.R"))

INPUT_DIR <- here("tasks/verifica-descontos/inputs")

con <- conecta_bd_medicamentos_transparentes()


# Listar todas as tabelas do banco
get_query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';")

contratacao <- get_query("select * from contratacao;")
item_homologado <- get_query("select * from item_homologado;")

write_csv(contratacao, file.path(INPUT_DIR, "contratacao.csv"))
write_csv(item_homologado, file.path(INPUT_DIR, "item_homologado.csv"))
