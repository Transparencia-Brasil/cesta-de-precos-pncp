-- Popula os campos de margem de preferencia a partir do CSV enriquecido.
-- Execute depois de alter-item-homologado-descontos.sql.
-- Uso (psql):
-- psql -d medicamentos-transparentes \
--   -v dataset_csv='tasks/verifica-descontos/outputs/itens_homologados_atualizados_com_legado.csv' \
--   -f tasks/alteracoes-no-banco-de-dados/descontos/src/sql/update-item-homologado-descontos.sql

\set ON_ERROR_STOP on

BEGIN;

CREATE TEMP TABLE tmp_item_homologado_margens_csv (
  numero_controle_pncp TEXT,
  numero_item TEXT,
  "tipoBeneficioNome" TEXT,
  "aplicabilidadeMargemPreferenciaNormal" TEXT,
  "percentualMargemPreferenciaNormal" TEXT,
  "aplicabilidadeMargemPreferenciaAdicional" TEXT,
  "percentualMargemPreferenciaAdicional" TEXT,
  "tipoMargemPreferencia.codigo" TEXT,
  "criterioJulgamentoNome" TEXT,
  "tipoMargemPreferencia.nome" TEXT,
  "tipoMargemPreferencia" TEXT,
  "exigenciaConteudoNacional" TEXT
) ON COMMIT DROP;

\copy tmp_item_homologado_margens_csv FROM :'dataset_csv' WITH (FORMAT csv, HEADER true, NULL '')

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM tmp_item_homologado_margens_csv
    WHERE numero_controle_pncp IS NULL
       OR btrim(numero_controle_pncp) = ''
       OR numero_item IS NULL
       OR btrim(numero_item) !~ '^[0-9]+$'
  ) THEN
    RAISE EXCEPTION 'O CSV contem chave de item nula ou invalida.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM tmp_item_homologado_margens_csv
    GROUP BY numero_controle_pncp, numero_item
    HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION 'O CSV contem chaves (numero_controle_pncp, numero_item) duplicadas.';
  END IF;
END;
$$;

SELECT
  COUNT(*) AS total_dataset,
  COUNT(i.numero_controle_pncp) AS itens_encontrados,
  COUNT(*) - COUNT(i.numero_controle_pncp) AS itens_nao_encontrados
FROM tmp_item_homologado_margens_csv AS t
LEFT JOIN item_homologado AS i
  ON i.numero_controle_pncp = t.numero_controle_pncp
 AND i.numero_item = t.numero_item::integer;

UPDATE item_homologado AS i
SET
  aplicabilidade_margem_preferencia_normal = t."aplicabilidadeMargemPreferenciaNormal",
  percentual_margem_preferencia_normal = t."percentualMargemPreferenciaNormal",
  aplicabilidade_margem_preferencia_adicional = t."aplicabilidadeMargemPreferenciaAdicional",
  percentual_margem_preferencia_adicional = t."percentualMargemPreferenciaAdicional",
  tipo_margem_preferencia_codigo = t."tipoMargemPreferencia.codigo",
  tipo_margem_preferencia_nome = t."tipoMargemPreferencia.nome",
  tipo_margem_preferencia = t."tipoMargemPreferencia",
  exigencia_conteudo_nacional = t."exigenciaConteudoNacional"
FROM tmp_item_homologado_margens_csv AS t
WHERE i.numero_controle_pncp = t.numero_controle_pncp
  AND i.numero_item = t.numero_item::integer;

COMMIT;

SELECT
  COUNT(*) AS total_itens,
  COUNT(*) FILTER (WHERE aplicabilidade_margem_preferencia_normal IS NOT NULL) AS com_aplicabilidade_normal,
  COUNT(*) FILTER (WHERE percentual_margem_preferencia_normal IS NOT NULL) AS com_percentual_normal,
  COUNT(*) FILTER (WHERE tipo_margem_preferencia_codigo IS NOT NULL) AS com_tipo_margem,
  COUNT(*) FILTER (WHERE exigencia_conteudo_nacional IS NOT NULL) AS com_exigencia_conteudo_nacional
FROM item_homologado;
