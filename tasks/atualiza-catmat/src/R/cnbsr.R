
# SETUP ------------------------------------------------------------------------
# Executar apenas uma vez

# Abre o arquivo .Renviron e inclua token do github para acessar repo privado
#install.packages(c("remotes", "usethis"))
#usethis::edit_r_environ()


# INSTALAR PACOTE NA VERSÃO MAIS RECENTE ---------------------------------------
# Instalar o pacote privado (requer token github no .Renviron)

# Instale novamente sempre que houver atualizações no pacote
remotes::install_github(repo = "rdurl0/cnbsr", upgrade = "ask", force = TRUE)


# LIBS -------------------------------------------------------------------------
library(cnbsr)
library(tidyverse)
library(here)


# BANCO DE DADOS ---------------------------------------------------------------
source(here("src/ETL/loaders/utils.R"))
con <- conecta_bd_medicamentos_transparentes()

catalogo_bd <- get_query("select * from catalogo;")

# USANDO PACOTE ----------------------------------------------------------------

# HIERARQUIA DE CÓDIGOS CATMAT
#
# GRUPO --> CLASSE --> PDM --> codigoBr
#
# │ GRUPO   │ 65 │ Equipamentos e Artigos Para Uso Médico, Dentário e Veterinário
# │ CLASSE  │6505│ Drogas e Medicamentos
# │ PDM     │ -- │ Padrão Descritivo de Materiais
# │ codigoBr│ -- │ Código do item (mais granular)
#

# obter PDM's da classe 6505
pdms <- cnbsr::get_codigo_pdm_classe(6505, busca_classe = TRUE)

pdms <- pdms |>
  select(
    # --GRUPO
    codigoGrupo,
    descricaoGrupo,
    #statusGrupo,
    # --CLASSE
    codigoClasse,
    descricaoClasse,
    #nomeClasse, # (é igual a descricaoClasse)
    #statusClasse,
    # --PDM
    codigoPDM,
    descricaoPDM,
    #codigoPdm,  # (é igual a codigoPDM)
    #nomePdm, # (é igual a descricaoPDM)
    #statusPDM
  )

# Dados de classe e grupo
codbr_raw <- pdms |>
  select(codigoPDM, descricaoPDM) |>
  mutate(codbr = map(codigoPDM, cnbsr::get_material_caracteristica_valor_pdm_sem_filtro))


# CodigoBr
codbr <- codbr_raw |>
  unnest(codbr, keep_empty = TRUE) |>
  select(
    codigoPDM,
    descricaoPDM,
    codigoItem,
    # nomePdm,
    statusItem,
    # itemSuspenso,
    # itemSustentavel,
    # itemExclusivoUasgCentral,
    # codigoClasse,
    codigoNcm,
    nomeNcm,
    # aplicaMargemPreferencia,
    # codigoCaracteristica,
    # codigoValorCaracteristica,
    # nomeCaracteristica,
    # caracteristicaObrigatoria,
    # statusCaracteristica,
    # numeroCaracteristica,
    # nomeValorCaracteristica,
    # siglaUnidadeMedida,
    # statusValorCaracteristica,
    # tuplaCaracteristica
  )

# descricaoItem
codbr <- codbr |>
  mutate(
    codbr = coalesce(codigoItem, codigoPDM) |>
      map(cnbsr::get_dados_item_material_por_codigo)
  )


 codbr_raw |>
   unnest(codbr, keep_empty = TRUE) |>
   filter(codigoItem == 267203) |>
   unnest(buscaItemCaracteristica, keep_empty = TRUE, names_sep = "_") |>
   select(-buscaItemCaracteristica_tuplaCaracteristica) |>
   glimpse()

catalogo_bd |>
  filter(codigo_pdm == 17708) |>
  filter(codigo_item == 267203) |>
  glimpse()

codbr |>
  filter(descricaoPDM == "Dipirona Sódica") |>
  unnest(codbr, keep_empty = TRUE) |>
  count(statusItem) |>
  print(n = Inf)

# Documentação
?cnbsr::get_codigo_pdm_classe
?cnbsr::get_material_caracteristica_valor_pdm_sem_filtro
?cnbsr::get_dados_item_material_por_codigo
