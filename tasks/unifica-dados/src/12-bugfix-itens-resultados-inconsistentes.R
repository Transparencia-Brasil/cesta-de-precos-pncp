# ITENS RESULTADOS INCONSISTENTES

library(tidyverse)
library(here)


# :: FILEPATHS -----------------------------------------------------------------

# RDS's dos arquivos brutos de coleta extraídos do Google Drive no script 00-download-de-dados.R
ITENS_RESULTADOS2_PATH <- "tasks/unifica-dados/input/itens2-resultados.rds"
ITENS_RESULTADOS3_PATH <- "tasks/unifica-dados/input/itens3-resultados.rds"

# itens-resultados remanescentes coletados nesta task com o script 09-run-coleta-resultados.sh
PATH_RESULTADOS_NOVOS <- here("coleta/resultados/dados.csv")

# CSV com as coletas unificadas
OUTPUT_DIR <- "tasks/unifica-dados/output"
PATH_RESULTADOS_UNIFICADOS <- here(OUTPUT_DIR, "itens-resultados.csv")

# Onde guardarei os arquivos inconsistentes
# Esse arquivo será enviado para para recoleta em uma VM
PATH_TEMP <- tempfile(pattern = "_inconsistentes", fileext = ".csv")

# Arquivos recuperados - recoletados na VM e transferido para local
PATH_RECOLETA <- here("coleta/_recoletas/coleta-resultados/resultados/dados.csv")

# :: CARREGA DADOS -------------------------------------------------------------

# carrega arquivos brutos de coleta
resultados <- map(c(ITENS_RESULTADOS2_PATH, ITENS_RESULTADOS3_PATH), readRDS) %>%
  set_names(c("itens2", "itens3"))

# carrega arquivos unificados
resultados$itens_resultados <- read_csv(PATH_RESULTADOS_UNIFICADOS)

# carrega itens-resultados coletados nesta task
resultados$itensNovos <- read_csv(PATH_RESULTADOS_NOVOS)

# dados recoletados
resultados$recoleta <- read_csv(PATH_RECOLETA)
resultados$recoleta <- distinct(resultados$recoleta)

# :: INCONSISTENCIAS -----------------------------------------------------------

# separa os itens que estão inconsistentes no arquivo de itens-resultados.csv inconsistentes

# separa as coletas que estão ruins
inconsistentes <- anti_join(resultados$itens_resultados, coleta1)

# salva os itens inconsistentes em um arquivo temporário
write_csv(inconsistentes, PATH_TMP)

# depois de salvar envia para vm usando scp no bash

# :: RESULTADOS CONSISTENTES ---------------------------------------------------

# separa as coletas que estão boas
coleta1_tratados <- semi_join(resultados$itens_resultados, coleta1)

# recolete os inconsistentes na VM
# faça o download do resultado da recoleta e salve na pasta OUTPUT_DIR
# comando em bash
"scp -r ubuntu@150.165.85.46:/home/ubuntu/tb-pncp/coleta-jan2025/coleta-resultados /mnt/c/Users/rdurl/OneDrive/Documentos/cesta-de-precos-pncp/coleta/_recoletas"

# guardar um backup do arquivo de resultados que será substituído
write_csv(resultados$itens_resultados, paste0(PATH_RESULTADOS_UNIFICADOS, ".old"))

# forçar que os tipos de dados sejam os mesmos, no caso strings
coleta1_tratados <- coleta1_tratados %>%
  mutate(across(everything(), \(x) as.character(x)))

resultados$recoleta <- resultados$recoleta %>%
  mutate(across(everything(), \(x) as.character(x)))

# juntar os resultados consistentes
itens_resultados_consistentes <- bind_rows(coleta1_tratados, resultados$recoleta)

# :: SALVA RESULTADOS INCONSISTENTES -------------------------------------------

write_csv(itens_resultados_consistentes, PATH_RESULTADOS_UNIFICADOS)

medicamentos <- read_csv(here("tasks/unifica-dados/output/medicamentos.csv")) %>%
  transmute(endpoint = str_glue("{endpoint}/{numeroItem}/resultados"))

medicamentos_resultados <- semi_join(itens_resultados_consistentes, medicamentos)

write_csv(medicamentos_resultados, here(OUTPUT_DIR, "resultados-medicamentos.csv"))
