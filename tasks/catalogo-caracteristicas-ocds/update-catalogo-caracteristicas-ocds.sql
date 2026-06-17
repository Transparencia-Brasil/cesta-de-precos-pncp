-- Popula catalogo.caracteristicas_ocds a partir do CSV gerado pelo notebook
-- src/ETL/loaders/docs/tabela-caracteristicas-ocds.ipynb.
--
-- Pre-requisito:
-- executar antes alter-catalogo-caracteristicas-ocds.sql.
--
-- Uso esperado:
-- psql -d medicamentos-transparentes \
--   -v dataset_csv='tasks/catalogo-caracteristicas-ocds/input/tabela-mapeamento-ocds.csv' \
--   -f tasks/catalogo-caracteristicas-ocds/update-catalogo-caracteristicas-ocds.sql
--
-- O CSV deve seguir o formato gerado em:
-- tasks/catalogo-caracteristicas-ocds/input/tabela-mapeamento-ocds.csv

\set ON_ERROR_STOP on

BEGIN;

CREATE TEMP TABLE tmp_catalogo_caracteristicas_ocds (
  codigo_classe TEXT,
  nome_classe TEXT,
  codigo_pdm TEXT,
  codigo_item INTEGER PRIMARY KEY,
  nome_item TEXT,
  item_suspenso TEXT,
  item_ativo TEXT,
  item_sustentavel TEXT,
  características TEXT,
  unidades_fornecimento TEXT,
  data_insercao TEXT,
  caracteristicas_ocds TEXT
) ON COMMIT DROP;

\copy tmp_catalogo_caracteristicas_ocds FROM :'dataset_csv' WITH (FORMAT csv, HEADER true)

UPDATE catalogo AS c
SET caracteristicas_ocds = NULLIF(btrim(t.caracteristicas_ocds), '')::jsonb
FROM tmp_catalogo_caracteristicas_ocds AS t
WHERE c.codigo_item = t.codigo_item
  AND NULLIF(btrim(t.caracteristicas_ocds), '') IS NOT NULL;

COMMIT;

SELECT
  COUNT(*) AS total_catalogo,
  COUNT(*) FILTER (WHERE caracteristicas_ocds IS NULL) AS sem_caracteristicas_ocds,
  COUNT(*) FILTER (WHERE caracteristicas_ocds IS NOT NULL) AS com_caracteristicas_ocds
FROM catalogo;

SELECT
  jsonb_typeof(caracteristicas_ocds) AS tipo_jsonb,
  COUNT(*) AS total
FROM catalogo
WHERE caracteristicas_ocds IS NOT NULL
GROUP BY jsonb_typeof(caracteristicas_ocds)
ORDER BY total DESC;
