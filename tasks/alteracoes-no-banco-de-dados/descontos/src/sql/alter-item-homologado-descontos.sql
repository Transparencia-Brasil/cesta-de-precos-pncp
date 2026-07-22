-- Adiciona a item_homologado os campos de beneficios, margens de preferencia,
-- criterios de desempate e desconto presentes no dataset descontos.csv.
--
-- O script pode ser reexecutado quando as colunas existentes possuem exatamente
-- os tipos esperados. Tipos divergentes interrompem a transacao antes de
-- qualquer alteracao.

\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
  colunas_incompativeis TEXT;
BEGIN
  SELECT string_agg(
    format('%I (%s; esperado %s)', esperado.nome, format_type(a.atttypid, a.atttypmod), esperado.tipo),
    ', ' ORDER BY esperado.nome
  )
  INTO colunas_incompativeis
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
  INNER JOIN pg_attribute AS a
    ON a.attrelid = 'item_homologado'::regclass
   AND a.attname = esperado.nome
   AND a.attnum > 0
   AND NOT a.attisdropped
  WHERE format_type(a.atttypid, a.atttypmod) <> esperado.tipo;

  IF colunas_incompativeis IS NOT NULL THEN
    RAISE EXCEPTION 'Colunas existentes com tipos incompativeis: %.', colunas_incompativeis;
  END IF;
END;
$$;

ALTER TABLE item_homologado
  ADD COLUMN IF NOT EXISTS aplicacao_beneficio_me_epp BOOLEAN,
  ADD COLUMN IF NOT EXISTS incentivo_produtivo_basico BOOLEAN,
  ADD COLUMN IF NOT EXISTS exigencia_conteudo_nacional BOOLEAN,
  ADD COLUMN IF NOT EXISTS aplicabilidade_margem_preferencia_normal BOOLEAN,
  ADD COLUMN IF NOT EXISTS aplicabilidade_margem_preferencia_adicional BOOLEAN,
  ADD COLUMN IF NOT EXISTS tipo_margem_preferencia_codigo INTEGER,
  ADD COLUMN IF NOT EXISTS tipo_margem_preferencia_nome TEXT,
  ADD COLUMN IF NOT EXISTS percentual_margem_preferencia_normal NUMERIC,
  ADD COLUMN IF NOT EXISTS percentual_margem_preferencia_adicional NUMERIC,
  ADD COLUMN IF NOT EXISTS aplicacao_margem_preferencia BOOLEAN,
  ADD COLUMN IF NOT EXISTS amparo_legal_margem_preferencia_id INTEGER,
  ADD COLUMN IF NOT EXISTS amparo_legal_margem_preferencia_nome TEXT,
  ADD COLUMN IF NOT EXISTS amparo_legal_margem_preferencia_descricao TEXT,
  ADD COLUMN IF NOT EXISTS aplicacao_criterio_desempate BOOLEAN,
  ADD COLUMN IF NOT EXISTS amparo_legal_criterio_desempate_id INTEGER,
  ADD COLUMN IF NOT EXISTS amparo_legal_criterio_desempate_nome TEXT,
  ADD COLUMN IF NOT EXISTS amparo_legal_criterio_desempate_descricao TEXT,
  ADD COLUMN IF NOT EXISTS percentual_desconto NUMERIC;

COMMENT ON COLUMN item_homologado.aplicacao_beneficio_me_epp IS
  'Indica a aplicacao de beneficio para microempresa ou empresa de pequeno porte no resultado do item.';
COMMENT ON COLUMN item_homologado.incentivo_produtivo_basico IS
  'Indica a aplicacao de incentivo ao processo produtivo basico no item licitado.';
COMMENT ON COLUMN item_homologado.exigencia_conteudo_nacional IS
  'Indica a exigencia de conteudo nacional no item licitado.';
COMMENT ON COLUMN item_homologado.aplicabilidade_margem_preferencia_normal IS
  'Indica a aplicabilidade de margem de preferencia normal no item licitado.';
COMMENT ON COLUMN item_homologado.aplicabilidade_margem_preferencia_adicional IS
  'Indica a aplicabilidade de margem de preferencia adicional no item licitado.';
COMMENT ON COLUMN item_homologado.tipo_margem_preferencia_codigo IS
  'Codigo do tipo de margem de preferencia do item licitado.';
COMMENT ON COLUMN item_homologado.tipo_margem_preferencia_nome IS
  'Nome do tipo de margem de preferencia do item licitado.';
COMMENT ON COLUMN item_homologado.percentual_margem_preferencia_normal IS
  'Percentual da margem de preferencia normal do item licitado.';
COMMENT ON COLUMN item_homologado.percentual_margem_preferencia_adicional IS
  'Percentual da margem de preferencia adicional do item licitado.';
COMMENT ON COLUMN item_homologado.aplicacao_margem_preferencia IS
  'Indica a aplicacao de margem de preferencia no resultado do item.';
COMMENT ON COLUMN item_homologado.amparo_legal_margem_preferencia_id IS
  'Identificador do amparo legal da margem de preferencia aplicada ao resultado do item.';
COMMENT ON COLUMN item_homologado.amparo_legal_margem_preferencia_nome IS
  'Nome do amparo legal da margem de preferencia aplicada ao resultado do item.';
COMMENT ON COLUMN item_homologado.amparo_legal_margem_preferencia_descricao IS
  'Descricao do amparo legal da margem de preferencia aplicada ao resultado do item.';
COMMENT ON COLUMN item_homologado.aplicacao_criterio_desempate IS
  'Indica a aplicacao de criterio de desempate no resultado do item.';
COMMENT ON COLUMN item_homologado.amparo_legal_criterio_desempate_id IS
  'Identificador do amparo legal do criterio de desempate aplicado ao resultado do item.';
COMMENT ON COLUMN item_homologado.amparo_legal_criterio_desempate_nome IS
  'Nome do amparo legal do criterio de desempate aplicado ao resultado do item.';
COMMENT ON COLUMN item_homologado.amparo_legal_criterio_desempate_descricao IS
  'Descricao do amparo legal do criterio de desempate aplicado ao resultado do item.';
COMMENT ON COLUMN item_homologado.percentual_desconto IS
  'Percentual de desconto informado no resultado do item, sem restricao de faixa.';

COMMIT;
