-- Popula os campos de descontos em item_homologado a partir de descontos.csv.
-- Execute depois de alter-item-homologado-descontos.sql.
--
-- Uso esperado (psql):
-- psql -v dataset_csv='/caminho/absoluto/descontos.csv' \
--   -f tasks/alteracoes-no-banco-de-dados/descontos/src/sql/update-item-homologado-descontos.sql

\set ON_ERROR_STOP on

BEGIN;

CREATE TEMP TABLE tmp_item_homologado_descontos_csv (
  numero_controle_pncp TEXT,
  numero_item TEXT,
  aplicacao_beneficio_me_epp TEXT,
  incentivo_produtivo_basico TEXT,
  exigencia_conteudo_nacional TEXT,
  aplicabilidade_margem_preferencia_normal TEXT,
  aplicabilidade_margem_preferencia_adicional TEXT,
  tipo_margem_preferencia_codigo TEXT,
  tipo_margem_preferencia_nome TEXT,
  percentual_margem_preferencia_normal TEXT,
  percentual_margem_preferencia_adicional TEXT,
  aplicacao_margem_preferencia TEXT,
  amparo_legal_margem_preferencia_id TEXT,
  amparo_legal_margem_preferencia_nome TEXT,
  amparo_legal_margem_preferencia_descricao TEXT,
  aplicacao_criterio_desempate TEXT,
  amparo_legal_criterio_desempate_id TEXT,
  amparo_legal_criterio_desempate_nome TEXT,
  amparo_legal_criterio_desempate_descricao TEXT,
  percentual_desconto TEXT
) ON COMMIT DROP;

\copy tmp_item_homologado_descontos_csv FROM :'dataset_csv' WITH (FORMAT csv, HEADER true, NULL '')

CREATE OR REPLACE FUNCTION pg_temp.normaliza_nulo(valor TEXT)
RETURNS TEXT
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT CASE
    WHEN valor IS NULL OR btrim(valor) IN ('', 'NA', 'N/A', 'NULL', 'null') THEN NULL
    ELSE btrim(valor)
  END
$$;

CREATE OR REPLACE FUNCTION pg_temp.parse_booleano(valor TEXT, coluna TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  valor_normalizado TEXT := lower(pg_temp.normaliza_nulo(valor));
BEGIN
  IF valor_normalizado IS NULL THEN
    RETURN NULL;
  ELSIF valor_normalizado IN ('true', 't', '1', 'sim', 's', 'yes', 'y', 'verdadeiro', 'v') THEN
    RETURN TRUE;
  ELSIF valor_normalizado IN ('false', 'f', '0', 'nao', 'não', 'n', 'no', 'falso') THEN
    RETURN FALSE;
  END IF;

  RAISE EXCEPTION 'Valor booleano invalido na coluna %: %.', coluna, valor;
END;
$$;

DO $$
DECLARE
  duplicatas BIGINT;
BEGIN
  IF EXISTS (
    SELECT 1
    FROM tmp_item_homologado_descontos_csv
    WHERE pg_temp.normaliza_nulo(numero_controle_pncp) IS NULL
       OR length(pg_temp.normaliza_nulo(numero_controle_pncp)) > 30
       OR pg_temp.normaliza_nulo(numero_item) IS NULL
       OR pg_temp.normaliza_nulo(numero_item) !~ '^[0-9]+$'
  ) THEN
    RAISE EXCEPTION
      'O CSV contem numero_controle_pncp ou numero_item nulo, invalido ou maior que o limite do schema.';
  END IF;

  SELECT COUNT(*)
  INTO duplicatas
  FROM (
    SELECT
      pg_temp.normaliza_nulo(numero_controle_pncp),
      pg_temp.normaliza_nulo(numero_item)
    FROM tmp_item_homologado_descontos_csv
    GROUP BY 1, 2
    HAVING COUNT(*) > 1
  ) AS chaves_duplicadas;

  IF duplicatas > 0 THEN
    RAISE EXCEPTION
      'O CSV contem % chave(s) (numero_controle_pncp, numero_item) duplicada(s).', duplicatas;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM tmp_item_homologado_descontos_csv AS t
    CROSS JOIN LATERAL (
      VALUES
        ('tipo_margem_preferencia_codigo', pg_temp.normaliza_nulo(t.tipo_margem_preferencia_codigo)),
        ('amparo_legal_margem_preferencia_id', pg_temp.normaliza_nulo(t.amparo_legal_margem_preferencia_id)),
        ('amparo_legal_criterio_desempate_id', pg_temp.normaliza_nulo(t.amparo_legal_criterio_desempate_id))
    ) AS valor(coluna, conteudo)
    WHERE valor.conteudo IS NOT NULL
      AND valor.conteudo !~ '^[+-]?[0-9]+$'
  ) THEN
    RAISE EXCEPTION 'O CSV contem valor invalido em uma coluna INTEGER.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM tmp_item_homologado_descontos_csv AS t
    CROSS JOIN LATERAL (
      VALUES
        ('percentual_margem_preferencia_normal', pg_temp.normaliza_nulo(t.percentual_margem_preferencia_normal)),
        ('percentual_margem_preferencia_adicional', pg_temp.normaliza_nulo(t.percentual_margem_preferencia_adicional)),
        ('percentual_desconto', pg_temp.normaliza_nulo(t.percentual_desconto))
    ) AS valor(coluna, conteudo)
    WHERE valor.conteudo IS NOT NULL
      AND valor.conteudo !~ '^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$'
  ) THEN
    RAISE EXCEPTION 'O CSV contem valor invalido em uma coluna NUMERIC.';
  END IF;
END;
$$;

CREATE TEMP TABLE tmp_item_homologado_descontos (
  numero_controle_pncp TEXT NOT NULL,
  numero_item INTEGER NOT NULL,
  aplicacao_beneficio_me_epp BOOLEAN,
  incentivo_produtivo_basico BOOLEAN,
  exigencia_conteudo_nacional BOOLEAN,
  aplicabilidade_margem_preferencia_normal BOOLEAN,
  aplicabilidade_margem_preferencia_adicional BOOLEAN,
  tipo_margem_preferencia_codigo INTEGER,
  tipo_margem_preferencia_nome TEXT,
  percentual_margem_preferencia_normal NUMERIC,
  percentual_margem_preferencia_adicional NUMERIC,
  aplicacao_margem_preferencia BOOLEAN,
  amparo_legal_margem_preferencia_id INTEGER,
  amparo_legal_margem_preferencia_nome TEXT,
  amparo_legal_margem_preferencia_descricao TEXT,
  aplicacao_criterio_desempate BOOLEAN,
  amparo_legal_criterio_desempate_id INTEGER,
  amparo_legal_criterio_desempate_nome TEXT,
  amparo_legal_criterio_desempate_descricao TEXT,
  percentual_desconto NUMERIC,
  PRIMARY KEY (numero_controle_pncp, numero_item)
) ON COMMIT DROP;

INSERT INTO tmp_item_homologado_descontos (
  numero_controle_pncp,
  numero_item,
  aplicacao_beneficio_me_epp,
  incentivo_produtivo_basico,
  exigencia_conteudo_nacional,
  aplicabilidade_margem_preferencia_normal,
  aplicabilidade_margem_preferencia_adicional,
  tipo_margem_preferencia_codigo,
  tipo_margem_preferencia_nome,
  percentual_margem_preferencia_normal,
  percentual_margem_preferencia_adicional,
  aplicacao_margem_preferencia,
  amparo_legal_margem_preferencia_id,
  amparo_legal_margem_preferencia_nome,
  amparo_legal_margem_preferencia_descricao,
  aplicacao_criterio_desempate,
  amparo_legal_criterio_desempate_id,
  amparo_legal_criterio_desempate_nome,
  amparo_legal_criterio_desempate_descricao,
  percentual_desconto
)
SELECT
  pg_temp.normaliza_nulo(numero_controle_pncp),
  pg_temp.normaliza_nulo(numero_item)::INTEGER,
  pg_temp.parse_booleano(aplicacao_beneficio_me_epp, 'aplicacao_beneficio_me_epp'),
  pg_temp.parse_booleano(incentivo_produtivo_basico, 'incentivo_produtivo_basico'),
  pg_temp.parse_booleano(exigencia_conteudo_nacional, 'exigencia_conteudo_nacional'),
  pg_temp.parse_booleano(aplicabilidade_margem_preferencia_normal, 'aplicabilidade_margem_preferencia_normal'),
  pg_temp.parse_booleano(aplicabilidade_margem_preferencia_adicional, 'aplicabilidade_margem_preferencia_adicional'),
  pg_temp.normaliza_nulo(tipo_margem_preferencia_codigo)::INTEGER,
  pg_temp.normaliza_nulo(tipo_margem_preferencia_nome),
  pg_temp.normaliza_nulo(percentual_margem_preferencia_normal)::NUMERIC,
  pg_temp.normaliza_nulo(percentual_margem_preferencia_adicional)::NUMERIC,
  pg_temp.parse_booleano(aplicacao_margem_preferencia, 'aplicacao_margem_preferencia'),
  pg_temp.normaliza_nulo(amparo_legal_margem_preferencia_id)::INTEGER,
  pg_temp.normaliza_nulo(amparo_legal_margem_preferencia_nome),
  pg_temp.normaliza_nulo(amparo_legal_margem_preferencia_descricao),
  pg_temp.parse_booleano(aplicacao_criterio_desempate, 'aplicacao_criterio_desempate'),
  pg_temp.normaliza_nulo(amparo_legal_criterio_desempate_id)::INTEGER,
  pg_temp.normaliza_nulo(amparo_legal_criterio_desempate_nome),
  pg_temp.normaliza_nulo(amparo_legal_criterio_desempate_descricao),
  pg_temp.normaliza_nulo(percentual_desconto)::NUMERIC
FROM tmp_item_homologado_descontos_csv;

SELECT
  COUNT(*) AS total_dataset,
  COUNT(i.numero_controle_pncp) AS itens_encontrados,
  COUNT(*) - COUNT(i.numero_controle_pncp) AS itens_nao_encontrados
FROM tmp_item_homologado_descontos AS t
LEFT JOIN item_homologado AS i
  ON i.numero_controle_pncp = t.numero_controle_pncp
 AND i.numero_item = t.numero_item;

CREATE TEMP TABLE tmp_item_homologado_descontos_resumo
ON COMMIT DROP
AS
WITH atualizados AS (
  UPDATE item_homologado AS i
  SET
    aplicacao_beneficio_me_epp = t.aplicacao_beneficio_me_epp,
    incentivo_produtivo_basico = t.incentivo_produtivo_basico,
    exigencia_conteudo_nacional = t.exigencia_conteudo_nacional,
    aplicabilidade_margem_preferencia_normal = t.aplicabilidade_margem_preferencia_normal,
    aplicabilidade_margem_preferencia_adicional = t.aplicabilidade_margem_preferencia_adicional,
    tipo_margem_preferencia_codigo = t.tipo_margem_preferencia_codigo,
    tipo_margem_preferencia_nome = t.tipo_margem_preferencia_nome,
    percentual_margem_preferencia_normal = t.percentual_margem_preferencia_normal,
    percentual_margem_preferencia_adicional = t.percentual_margem_preferencia_adicional,
    aplicacao_margem_preferencia = t.aplicacao_margem_preferencia,
    amparo_legal_margem_preferencia_id = t.amparo_legal_margem_preferencia_id,
    amparo_legal_margem_preferencia_nome = t.amparo_legal_margem_preferencia_nome,
    amparo_legal_margem_preferencia_descricao = t.amparo_legal_margem_preferencia_descricao,
    aplicacao_criterio_desempate = t.aplicacao_criterio_desempate,
    amparo_legal_criterio_desempate_id = t.amparo_legal_criterio_desempate_id,
    amparo_legal_criterio_desempate_nome = t.amparo_legal_criterio_desempate_nome,
    amparo_legal_criterio_desempate_descricao = t.amparo_legal_criterio_desempate_descricao,
    percentual_desconto = t.percentual_desconto
  FROM tmp_item_homologado_descontos AS t
  WHERE i.numero_controle_pncp = t.numero_controle_pncp
    AND i.numero_item = t.numero_item
  RETURNING 1
)
SELECT COUNT(*)::BIGINT AS linhas_atualizadas
FROM atualizados;

SELECT linhas_atualizadas
FROM tmp_item_homologado_descontos_resumo;

SELECT
  valor.coluna,
  COUNT(*) FILTER (WHERE valor.nulo) AS valores_nulos,
  COUNT(*) FILTER (WHERE NOT valor.nulo) AS valores_preenchidos
FROM item_homologado AS i
INNER JOIN tmp_item_homologado_descontos AS t
  ON i.numero_controle_pncp = t.numero_controle_pncp
 AND i.numero_item = t.numero_item
CROSS JOIN LATERAL (
  VALUES
    ('aplicacao_beneficio_me_epp', i.aplicacao_beneficio_me_epp IS NULL),
    ('incentivo_produtivo_basico', i.incentivo_produtivo_basico IS NULL),
    ('exigencia_conteudo_nacional', i.exigencia_conteudo_nacional IS NULL),
    ('aplicabilidade_margem_preferencia_normal', i.aplicabilidade_margem_preferencia_normal IS NULL),
    ('aplicabilidade_margem_preferencia_adicional', i.aplicabilidade_margem_preferencia_adicional IS NULL),
    ('tipo_margem_preferencia_codigo', i.tipo_margem_preferencia_codigo IS NULL),
    ('tipo_margem_preferencia_nome', i.tipo_margem_preferencia_nome IS NULL),
    ('percentual_margem_preferencia_normal', i.percentual_margem_preferencia_normal IS NULL),
    ('percentual_margem_preferencia_adicional', i.percentual_margem_preferencia_adicional IS NULL),
    ('aplicacao_margem_preferencia', i.aplicacao_margem_preferencia IS NULL),
    ('amparo_legal_margem_preferencia_id', i.amparo_legal_margem_preferencia_id IS NULL),
    ('amparo_legal_margem_preferencia_nome', i.amparo_legal_margem_preferencia_nome IS NULL),
    ('amparo_legal_margem_preferencia_descricao', i.amparo_legal_margem_preferencia_descricao IS NULL),
    ('aplicacao_criterio_desempate', i.aplicacao_criterio_desempate IS NULL),
    ('amparo_legal_criterio_desempate_id', i.amparo_legal_criterio_desempate_id IS NULL),
    ('amparo_legal_criterio_desempate_nome', i.amparo_legal_criterio_desempate_nome IS NULL),
    ('amparo_legal_criterio_desempate_descricao', i.amparo_legal_criterio_desempate_descricao IS NULL),
    ('percentual_desconto', i.percentual_desconto IS NULL)
) AS valor(coluna, nulo)
GROUP BY valor.coluna
ORDER BY valor.coluna;

COMMIT;
