-- Popula contratacao.compra_judicial a partir do CSV gerado pelo notebook
-- tasks/verifica-compras-judiciais/docs/contagem-compras-judiciais.ipynb.
--
-- Pre-requisito:
-- executar antes:
-- tasks/verifica-compras-judiciais/src/sql/alter-contratacao-compra-judicial.sql.
--
-- Uso esperado:
-- psql -d medicamentos_transparentes \
--   -v dataset_csv='tasks/verifica-compras-judiciais/outputs/compras-judiciais-completo.csv' \
--   -f tasks/verifica-compras-judiciais/src/sql/update-contratacao-compra-judicial.sql

\set ON_ERROR_STOP on

BEGIN;

CREATE TEMP TABLE tmp_contratacao_compra_judicial (
  numero_controle_pncp VARCHAR(30) PRIMARY KEY,
  srp TEXT,
  objeto_compra TEXT,
  codigo_modalidade TEXT,
  nome_modalidade TEXT,
  compra_judicial TEXT
) ON COMMIT DROP;

\copy tmp_contratacao_compra_judicial FROM :'dataset_csv' WITH (FORMAT csv, HEADER true)

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM tmp_contratacao_compra_judicial
    WHERE lower(btrim(compra_judicial)) NOT IN ('true', 'false')
       OR compra_judicial IS NULL
  ) THEN
    RAISE EXCEPTION
      'O dataset contém valores inválidos na coluna compra_judicial; use somente True ou False.';
  END IF;
END;
$$;

SELECT
  COUNT(*) AS total_dataset,
  COUNT(c.numero_controle_pncp) AS contratacoes_encontradas,
  COUNT(*) - COUNT(c.numero_controle_pncp) AS contratacoes_nao_encontradas
FROM tmp_contratacao_compra_judicial AS t
LEFT JOIN contratacao AS c
  ON c.numero_controle_pncp = t.numero_controle_pncp;

UPDATE contratacao AS c
SET compra_judicial = lower(btrim(t.compra_judicial))::boolean
FROM tmp_contratacao_compra_judicial AS t
WHERE c.numero_controle_pncp = t.numero_controle_pncp;

COMMIT;

SELECT
  COUNT(*) AS total_contratacoes,
  COUNT(*) FILTER (WHERE compra_judicial IS NULL) AS sem_classificacao,
  COUNT(*) FILTER (WHERE compra_judicial IS TRUE) AS compras_judiciais,
  COUNT(*) FILTER (WHERE compra_judicial IS FALSE) AS compras_nao_judiciais
FROM contratacao;
