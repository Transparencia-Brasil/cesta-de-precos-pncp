
# :: SETUP ---------------------------------------------------------------------
# Executar apenas uma vez

# Abre o arquivo .Renviron e inclua token do github para acessar repo privado
#install.packages(c("remotes", "usethis"))
#usethis::edit_r_environ()


# INSTALAR PACOTE NA VERSÃO MAIS RECENTE ---------------------------------------
# Instalar o pacote privado (requer token github no .Renviron)

# Instale novamente sempre que houver atualizações no pacote
remotes::install_github(repo = "rdurl0/cnbsr", upgrade = "ask", force = TRUE)


# :: LIBS ----------------------------------------------------------------------
library(cnbsr)
library(tidyverse)
library(here)


# :: OUTPUTS -------------------------------------------------------------------

# esse arquivo entrará no repositório `medicine-extension `e será usado para criar o campo `caracteristicas_ocds` no banco de dados
PATH_OCDS <- here("tasks/atualiza-catmat/outputs/caracteristicas-catmat.csv")

# essa será a versão atualizada do catálogo de materiais que entrará no loader do banco de dados
PATH_CATALOGO_ATUALIZADO <- here("tasks/atualiza-catmat/outputs/catalogo-atualizado.rds")


# :: USANDO PACOTE -------------------------------------------------------------

# HIERARQUIA DE CÓDIGOS CATMAT
#
# GRUPO --> CLASSE --> PDM --> codigoBr
#
# │ GRUPO   │ 65 │ Equipamentos e Artigos Para Uso Médico, Dentário e Veterinário
# │ CLASSE  │6505│ Drogas e Medicamentos
# │ PDM     │ -- │ Padrão Descritivo de Materiais
# │ codigoBr│ -- │ Código do item (mais granular)
#


# :: PDM -----------------------------------------------------------------------

# obter PDM's da classe 6505
pdms <- cnbsr::get_codigo_pdm_classe(6505, busca_classe = TRUE)

pdms <- pdms |>
  select(
    # ---GRUPO
    # codigoGrupo,
    descricaoGrupo,
    #statusGrupo,
    # ---CLASSE
    # codigoClasse,
    descricaoClasse,
    #nomeClasse, # (é igual a descricaoClasse)
    #statusClasse,
    # ---PDM
    codigoPDM,
    descricaoPDM,
    statusPDM,
    #codigoPdm,  # (é igual a codigoPDM)
    #nomePdm, # (é igual a descricaoPDM)
  )

# detalhes de Classe, Grupo e Conjunto (seja lá o que for isso)
pdms <- pdms |>
  mutate(pdms = map(codigoPDM, cnbsr::get_dados_basicos_pdm_por_codigo))

pdms <- pdms |>
  unnest(pdms, keep_empty = TRUE) |>
  select(
    # ---Conjunto
    codigoConjunto, #?
    nomeAcentuadoConjunto,
    # ---GRUPO
    codigoGrupo,
    descricaoGrupo,
    #nomeGrupo
    # ---CLASSE
    codigoClasse,
    descricaoClasse,
    #nomeClasse
    # ---PDM
    codigoPDM,
    descricaoPDM,
    statusPDM,
    # ---Pdm
    #codigoPdm,
    #nomePdm,
    #statusPdm
  )


# :: CODIGO BR -----------------------------------------------------------------

# Dados de classe e grupo
codbr_raw <- pdms |>
  select(codigoPDM, descricaoPDM) |>
  mutate(codbr = map(codigoPDM, cnbsr::get_material_caracteristica_valor_pdm_sem_filtro))

# CodigoBr e características
codbr <- codbr_raw |>
  unnest(codbr, keep_empty = TRUE) |>
  select(
    codigoPDM,
    descricaoPDM,
    codigoItem,
    # nomePdm,
    statusItem,
    itemSuspenso,
    itemSustentavel,
    # itemExclusivoUasgCentral,
    # codigoClasse,
    codigoNcm,
    nomeNcm,
    # aplicaMargemPreferencia,
    buscaItemCaracteristica,
    # - codigoCaracteristica,
    # - codigoValorCaracteristica,
    # - nomeCaracteristica,
    # - caracteristicaObrigatoria,
    # - statusCaracteristica,
    # - numeroCaracteristica,
    # - nomeValorCaracteristica,
    # - siglaUnidadeMedida,
    # - statusValorCaracteristica,
    # - tuplaCaracteristica
  )

# descricaoItem completa
codbr <- codbr |>
  mutate(codbr = coalesce(codigoItem, codigoPDM) |>
    map(cnbsr::get_dados_item_material_por_codigo)
  ) |>
  unnest(codbr, keep_empty = TRUE)

# Unidade de fornecimento (ex: "UN", "CX", "FR", etc)
codbr <- codbr |>
  filter(!is.na(codigoItem)) |>
  mutate(unidadeFornecimento = map(
    coalesce(codigoItem, codigoPDM),
    cnbsr::get_unidade_fornecimento_por_codigo_item_material
  ))


# :: EXPORTAR PARA OCDS --------------------------------------------------------

# esse arquivo entrará no repositório `medicine-extension `e será usado para criar o campo `caracteristicas_ocds` no banco de dados

# aqui nós exportaremos o dado criação do campo `caracteristicas_ocds`
# no repositório
codbr |>
  filter(statusItem) |>
  select(
    codigo_br = codigoItem,
    desc_item = descricaoItem,
    codigo_pdm = codigoPDM,
    desc_pdm = descricaoPDM,
    buscaItemCaracteristica
  ) |>
  unnest(buscaItemCaracteristica, keep_empty = TRUE) |>
  select(
    codigo_br,
    desc_item,
    codigo_pdm,
    desc_pdm,
    numeroCaracteristica,
    nomeCaracteristica,
    nomeValorCaracteristica,
    siglaUnidadeMedida
  ) |>
  write_csv(PATH_OCDS)


# :: CATALOGO ------------------------------------------------------------------

# essa é a tabela de catálogo que entra no loader, com as colunas que interessam para o banco de dados
codbr_catalogo <- codbr |>
  left_join(pdms) |>
  transmute(
    codigo_grupo = codigoGrupo,
    nome_grupo = descricaoGrupo,
    codigo_classe = codigoClasse,
    nome_classe = descricaoClasse,
    codigo_pdm = codigoPDM,
    nome_pdm = descricaoPDM,
    codigo_br = codigoItem,
    nome_item = descricaoItem,
    item_suspenso = itemSuspenso,
    item_ativo = statusItem,
    # desc_item_ativo = ...,
    item_sustentavel = itemSustentavel,
    # desc_item_sustentavel = ...,
    buscaItemCaracteristica = map(buscaItemCaracteristica, select, -tuplaCaracteristica),
    # classificacaoContabil = ...,
    unidadeFornecimento
  )

# somente itens ativos entram no catálogo
codbr_catalogo <- codbr_catalogo |>
  filter(item_ativo)


saveRDS(codbr_catalogo, PATH_CATALOGO_ATUALIZADO)

# Documentação
?cnbsr::get_codigo_pdm_classe
?cnbsr::get_material_caracteristica_valor_pdm_sem_filtro
?cnbsr::get_dados_item_material_por_codigo
?cnbsr::get_unidade_fornecimento_por_codigo_item_material
