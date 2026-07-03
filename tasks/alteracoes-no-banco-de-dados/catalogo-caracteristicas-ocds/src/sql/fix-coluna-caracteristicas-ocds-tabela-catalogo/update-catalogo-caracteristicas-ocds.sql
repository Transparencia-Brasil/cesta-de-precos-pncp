-- Atualiza catalogo.caracteristicas_ocds a partir do CSV corrigido.
--
-- Este script nao executa ALTER TABLE. Ele assume que a coluna
-- catalogo.caracteristicas_ocds ja existe.
--
-- Uso esperado:
-- psql -d medicamentos-transparentes \
--   -v dataset_csv='tasks/alteracoes-no-banco-de-dados/catalogo-caracteristicas-ocds/outputs/tabela-mapeamento-ocds.csv' \
--   -f tasks/alteracoes-no-banco-de-dados/catalogo-caracteristicas-ocds/src/sql/fix-coluna-caracteristicas-ocds-tabela-catalogo/update-catalogo-caracteristicas-ocds.sql
--
-- O CSV esperado deve conter as colunas:
-- codigo_item,caracteristicas_ocds

\set ON_ERROR_STOP on

BEGIN;

CREATE TEMP TABLE tmp_catalogo_caracteristicas_ocds_corrigidas (
  codigo_item INTEGER PRIMARY KEY,
  caracteristicas_ocds TEXT
) ON COMMIT DROP;

\copy tmp_catalogo_caracteristicas_ocds_corrigidas FROM :'dataset_csv' WITH (FORMAT csv, HEADER true)

WITH mapeamento AS (
  SELECT
    codigo_item,
    NULLIF(btrim(caracteristicas_ocds), '')::jsonb AS caracteristicas_ocds
  FROM tmp_catalogo_caracteristicas_ocds_corrigidas
  WHERE NULLIF(btrim(caracteristicas_ocds), '') IS NOT NULL
),
atualizados AS (
  UPDATE catalogo AS c
  SET caracteristicas_ocds = m.caracteristicas_ocds
  FROM mapeamento AS m
  WHERE c.codigo_item = m.codigo_item
  RETURNING c.codigo_item
)
SELECT
  COUNT(*) AS total_linhas_atualizadas
FROM atualizados;

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
