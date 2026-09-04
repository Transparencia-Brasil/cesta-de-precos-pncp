library(tidyverse)
library(here)

source(here("tasks/contagem-medicamentos-em-producao/src/R/utils.R"))

CATMAT_DIR <- here("data/catmat")
OUTPUT <- here(
  "tasks/contagem-medicamentos-em-producao/outputs",
  "contagem-medicamentos-em-producao.csv"
)

arquivos_catalogo <- list.files(
  CATMAT_DIR,
  pattern = "^catmat-[0-9]+\\.csv$",
  recursive = TRUE,
  full.names = TRUE
)

versoes_catalogo <- arquivos_catalogo |>
  map_dfr(function(arquivo) {
    versao <- basename(arquivo) |>
      str_extract("[0-9]+") |>
      as.integer()

    read_csv(
      arquivo,
      col_types = cols(codigo_br = col_integer()),
      show_col_types = FALSE,
      progress = FALSE
    ) |>
      select(codigo_br) |>
      mutate(versao_catalogo = versao)
  }) |>
  summarise(
    versao_catalogo = min(versao_catalogo),
    .by = codigo_br
  )

qry <- "
  WITH deteccoes AS (
    SELECT codigo_item_catalogo, COUNT(*) AS quantidade
    FROM item_licitado
    GROUP BY codigo_item_catalogo

    UNION ALL

    SELECT codigo_item_catalogo, COUNT(*) AS quantidade
    FROM item_homologado
    GROUP BY codigo_item_catalogo
  ),
  contagens AS (
    SELECT codigo_item_catalogo, SUM(quantidade) AS contagem_deteccoes
    FROM deteccoes
    GROUP BY codigo_item_catalogo
  ),
  homologacoes AS (
    SELECT
      codigo_item_catalogo,
      SUM(valor_total_homologado) AS valor_total_homologado,
      MAX(data_insercao) AS data_ultima_insercao
    FROM item_homologado
    GROUP BY codigo_item_catalogo
  )
  SELECT
    catalogo.codigo_item AS codigo_br,
    catalogo.nome_item AS descricao_item,
    catalogo.nome_pdm AS nome_pdm,
    COALESCE(contagens.contagem_deteccoes, 0) AS contagem_deteccoes,
    COALESCE(homologacoes.valor_total_homologado, 0) AS valor_total_homologado,
    homologacoes.data_ultima_insercao
  FROM catalogo
  LEFT JOIN contagens
    ON catalogo.codigo_item = contagens.codigo_item_catalogo
  LEFT JOIN homologacoes
    ON catalogo.codigo_item = homologacoes.codigo_item_catalogo
"

con <- conecta_bd_medicamentos_transparentes()
medicamentos_producao <- get_query(qry, quiet = TRUE)
DBI::dbDisconnect(con)

output <- medicamentos_producao |>
  left_join(versoes_catalogo, by = "codigo_br") |>
  transmute(
    codigoBR = as.integer(codigo_br),
    descricaoItem = descricao_item,
    nomePDM = nome_pdm,
    versaoCatalogo = versao_catalogo,
    contagemDeteccoes = as.numeric(contagem_deteccoes),
    valorTotalHomologado = as.numeric(valor_total_homologado),
    dataUltimaInsercao = format(
      data_ultima_insercao,
      format = "%Y-%m-%d %H:%M:%S"
    )
  ) |>
  arrange(versaoCatalogo, nomePDM, codigoBR)

dir.create(dirname(OUTPUT), recursive = TRUE, showWarnings = FALSE)
write_csv(output, OUTPUT, na = "")

message("Arquivo salvo em: ", OUTPUT)


# Exportar

read_csv(OUTPUT) |>
  googlesheets4::write_sheet(
    ss = "https://docs.google.com/spreadsheets/d/1CnYlX9gvzYSQXb07anGPMFSZB9CdKbHGt9ip_vNjmNY",
    sheet = str_glue("EXPORTACAO - {format(today(), '%d-%b-%y')}")
  )
