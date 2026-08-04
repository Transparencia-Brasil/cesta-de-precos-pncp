-- Popula catalogo.caracteristicas_ocds a partir do CSV versionado.
--
-- Pre-requisito:
-- executar antes:
-- tasks/alteracoes-no-banco-de-dados/catalogo-caracteristicas-ocds/src/sql/alter-catalogo-caracteristicas-ocds.sql.
--
-- Uso esperado: execute pelo wrapper Bash/WSL documentado no README da task,
-- que substitui :'dataset_csv' pelo caminho absoluto antes de chamar psql.
--
-- O CSV deve conter apenas codigo_item e caracteristicas_ocds.

\set ON_ERROR_STOP on

BEGIN;

CREATE TEMP TABLE tmp_catalogo_caracteristicas_ocds (
  codigo_item INTEGER PRIMARY KEY,
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
