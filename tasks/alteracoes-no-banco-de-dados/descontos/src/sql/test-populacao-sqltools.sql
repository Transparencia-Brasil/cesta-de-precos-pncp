-- Teste autocontido da migracao de descontos para PostgreSQL/SQLTools.
-- Nao usa \copy, nao altera tabelas permanentes e termina com ROLLBACK.

BEGIN;

CREATE TEMP TABLE item_homologado (
  numero_controle_pncp VARCHAR(30),
  numero_item INTEGER NOT NULL,
  descricao TEXT,
  valor_unitario_homologado NUMERIC,
  quantidade_homologada INTEGER,
  PRIMARY KEY (numero_controle_pncp, numero_item)
) ON COMMIT DROP;

INSERT INTO item_homologado (
  numero_controle_pncp,
  numero_item,
  descricao,
  valor_unitario_homologado,
  quantidade_homologada
)
VALUES
  ('01601856000185-1-000321/2025', 5, 'Item completo', 10.00, 100),
  ('33781055000135-1-000933/2025', 1, 'Item parcial', 2.59, 400),
  ('45358249000101-1-001296/2024', 3, 'Item sem atributos', 1.00, 1);

ALTER TABLE item_homologado
  ADD COLUMN aplicacao_beneficio_me_epp BOOLEAN,
  ADD COLUMN incentivo_produtivo_basico BOOLEAN,
  ADD COLUMN exigencia_conteudo_nacional BOOLEAN,
  ADD COLUMN aplicabilidade_margem_preferencia_normal BOOLEAN,
  ADD COLUMN aplicabilidade_margem_preferencia_adicional BOOLEAN,
  ADD COLUMN tipo_margem_preferencia_codigo INTEGER,
  ADD COLUMN tipo_margem_preferencia_nome TEXT,
  ADD COLUMN percentual_margem_preferencia_normal NUMERIC,
  ADD COLUMN percentual_margem_preferencia_adicional NUMERIC,
  ADD COLUMN aplicacao_margem_preferencia BOOLEAN,
  ADD COLUMN amparo_legal_margem_preferencia_id INTEGER,
  ADD COLUMN amparo_legal_margem_preferencia_nome TEXT,
  ADD COLUMN amparo_legal_margem_preferencia_descricao TEXT,
  ADD COLUMN aplicacao_criterio_desempate BOOLEAN,
  ADD COLUMN amparo_legal_criterio_desempate_id INTEGER,
  ADD COLUMN amparo_legal_criterio_desempate_nome TEXT,
  ADD COLUMN amparo_legal_criterio_desempate_descricao TEXT,
  ADD COLUMN percentual_desconto NUMERIC;

-- Simula valores anteriores para comprovar que o CSV autoritativo pode
-- substitui-los por NULL.
UPDATE item_homologado
SET
  aplicacao_beneficio_me_epp = TRUE,
  incentivo_produtivo_basico = TRUE,
  exigencia_conteudo_nacional = TRUE,
  aplicabilidade_margem_preferencia_normal = TRUE,
  aplicabilidade_margem_preferencia_adicional = TRUE,
  tipo_margem_preferencia_codigo = 1,
  tipo_margem_preferencia_nome = 'valor anterior',
  percentual_margem_preferencia_normal = 1,
  percentual_margem_preferencia_adicional = 1,
  aplicacao_margem_preferencia = TRUE,
  amparo_legal_margem_preferencia_id = 1,
  amparo_legal_margem_preferencia_nome = 'valor anterior',
  amparo_legal_margem_preferencia_descricao = 'valor anterior',
  aplicacao_criterio_desempate = TRUE,
  amparo_legal_criterio_desempate_id = 1,
  amparo_legal_criterio_desempate_nome = 'valor anterior',
  amparo_legal_criterio_desempate_descricao = 'valor anterior',
  percentual_desconto = 1
WHERE numero_controle_pncp = '45358249000101-1-001296/2024'
  AND numero_item = 3;

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

INSERT INTO tmp_item_homologado_descontos_csv
VALUES
  (
    '01601856000185-1-000321/2025', '5',
    'TRUE', 'FALSE', 'FALSE', 'TRUE', 'FALSE',
    '2', 'Resolução CICS', '5.0', '10.0',
    'TRUE', '143', 'Lei de margem', 'Descrição da margem',
    'FALSE', '145', 'Preferência nacional', 'Descrição do desempate',
    '559.32'
  ),
  (
    '33781055000135-1-000933/2025', '1',
    'sim', 'não', 'NA', 't', 'f',
    '1', 'Normal', '.5', '1e1',
    'yes', '144', 'N/A', 'Descrição parcial',
    '0', '163', 'NULL', 'Descrição parcial do desempate',
    '0'
  ),
  (
    '45358249000101-1-001296/2024', '3',
    NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL,
    NULL
  ),
  (
    '99999999999999-1-999999/2025', '99',
    NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL,
    NULL
  );

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

INSERT INTO tmp_item_homologado_descontos
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

CREATE TEMP TABLE tmp_resultado_update
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

SELECT
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
FROM item_homologado
ORDER BY numero_controle_pncp, numero_item;

DO $$
DECLARE
  tipos_incorretos INTEGER;
BEGIN
  SELECT COUNT(*)
  INTO tipos_incorretos
  FROM (
    VALUES
      ('aplicacao_beneficio_me_epp', 'boolean'),
      ('incentivo_produtivo_basico', 'boolean'),
      ('exigencia_conteudo_nacional', 'boolean'),
      ('aplicabilidade_margem_preferencia_normal', 'boolean'),
      ('aplicabilidade_margem_preferencia_adicional', 'boolean'),
      ('tipo_margem_preferencia_codigo', 'integer'),
      ('tipo_margem_preferencia_nome', 'text'),
      ('percentual_margem_preferencia_normal', 'numeric'),
      ('percentual_margem_preferencia_adicional', 'numeric'),
      ('aplicacao_margem_preferencia', 'boolean'),
      ('amparo_legal_margem_preferencia_id', 'integer'),
      ('amparo_legal_margem_preferencia_nome', 'text'),
      ('amparo_legal_margem_preferencia_descricao', 'text'),
      ('aplicacao_criterio_desempate', 'boolean'),
      ('amparo_legal_criterio_desempate_id', 'integer'),
      ('amparo_legal_criterio_desempate_nome', 'text'),
      ('amparo_legal_criterio_desempate_descricao', 'text'),
      ('percentual_desconto', 'numeric')
  ) AS esperado(nome, tipo)
  LEFT JOIN pg_attribute AS a
    ON a.attrelid = 'item_homologado'::regclass
   AND a.attname = esperado.nome
   AND a.attnum > 0
   AND NOT a.attisdropped
  WHERE a.attname IS NULL
     OR format_type(a.atttypid, a.atttypmod) <> esperado.tipo;

  IF tipos_incorretos <> 0 THEN
    RAISE EXCEPTION 'O teste encontrou % coluna(s) ausente(s) ou com tipo incorreto.', tipos_incorretos;
  END IF;

  IF (SELECT COUNT(*) FROM item_homologado) <> 3 THEN
    RAISE EXCEPTION 'O UPDATE alterou a cardinalidade de item_homologado.';
  END IF;

  IF (SELECT linhas_atualizadas FROM tmp_resultado_update) <> 3 THEN
    RAISE EXCEPTION 'O UPDATE deveria atualizar exatamente tres itens existentes.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM item_homologado
    WHERE numero_controle_pncp = '99999999999999-1-999999/2025'
  ) THEN
    RAISE EXCEPTION 'A chave inexistente do dataset foi inserida indevidamente.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM item_homologado
    WHERE numero_controle_pncp = '01601856000185-1-000321/2025'
      AND numero_item = 5
      AND aplicacao_beneficio_me_epp IS TRUE
      AND incentivo_produtivo_basico IS FALSE
      AND exigencia_conteudo_nacional IS FALSE
      AND aplicabilidade_margem_preferencia_normal IS TRUE
      AND aplicabilidade_margem_preferencia_adicional IS FALSE
      AND tipo_margem_preferencia_codigo = 2
      AND tipo_margem_preferencia_nome = 'Resolução CICS'
      AND percentual_margem_preferencia_normal = 5.0
      AND percentual_margem_preferencia_adicional = 10.0
      AND aplicacao_margem_preferencia IS TRUE
      AND amparo_legal_margem_preferencia_id = 143
      AND amparo_legal_margem_preferencia_nome = 'Lei de margem'
      AND amparo_legal_margem_preferencia_descricao = 'Descrição da margem'
      AND aplicacao_criterio_desempate IS FALSE
      AND amparo_legal_criterio_desempate_id = 145
      AND amparo_legal_criterio_desempate_nome = 'Preferência nacional'
      AND amparo_legal_criterio_desempate_descricao = 'Descrição do desempate'
      AND percentual_desconto = 559.32
  ) THEN
    RAISE EXCEPTION 'O item completo nao foi populado corretamente.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM item_homologado
    WHERE numero_controle_pncp = '33781055000135-1-000933/2025'
      AND numero_item = 1
      AND aplicacao_beneficio_me_epp IS TRUE
      AND incentivo_produtivo_basico IS FALSE
      AND exigencia_conteudo_nacional IS NULL
      AND aplicabilidade_margem_preferencia_normal IS TRUE
      AND aplicabilidade_margem_preferencia_adicional IS FALSE
      AND percentual_margem_preferencia_normal = 0.5
      AND percentual_margem_preferencia_adicional = 10
      AND amparo_legal_margem_preferencia_nome IS NULL
      AND amparo_legal_criterio_desempate_nome IS NULL
  ) THEN
    RAISE EXCEPTION 'A normalizacao do item parcial falhou.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM item_homologado
    WHERE numero_controle_pncp = '45358249000101-1-001296/2024'
      AND numero_item = 3
      AND num_nonnulls(
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
      ) = 0
  ) THEN
    RAISE EXCEPTION 'Os nulos autoritativos nao substituíram os valores anteriores.';
  END IF;
END;
$$;

ROLLBACK;
