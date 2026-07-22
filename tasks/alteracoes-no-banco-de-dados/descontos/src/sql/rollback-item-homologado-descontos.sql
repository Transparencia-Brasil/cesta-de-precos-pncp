-- Rollback emergencial da migracao de descontos em item_homologado.
-- ATENCAO: remove as 18 colunas e apaga definitivamente os dados populados.

\set ON_ERROR_STOP on

BEGIN;

ALTER TABLE item_homologado
  DROP COLUMN IF EXISTS aplicacao_beneficio_me_epp,
  DROP COLUMN IF EXISTS incentivo_produtivo_basico,
  DROP COLUMN IF EXISTS exigencia_conteudo_nacional,
  DROP COLUMN IF EXISTS aplicabilidade_margem_preferencia_normal,
  DROP COLUMN IF EXISTS aplicabilidade_margem_preferencia_adicional,
  DROP COLUMN IF EXISTS tipo_margem_preferencia_codigo,
  DROP COLUMN IF EXISTS tipo_margem_preferencia_nome,
  DROP COLUMN IF EXISTS percentual_margem_preferencia_normal,
  DROP COLUMN IF EXISTS percentual_margem_preferencia_adicional,
  DROP COLUMN IF EXISTS aplicacao_margem_preferencia,
  DROP COLUMN IF EXISTS amparo_legal_margem_preferencia_id,
  DROP COLUMN IF EXISTS amparo_legal_margem_preferencia_nome,
  DROP COLUMN IF EXISTS amparo_legal_margem_preferencia_descricao,
  DROP COLUMN IF EXISTS aplicacao_criterio_desempate,
  DROP COLUMN IF EXISTS amparo_legal_criterio_desempate_id,
  DROP COLUMN IF EXISTS amparo_legal_criterio_desempate_nome,
  DROP COLUMN IF EXISTS amparo_legal_criterio_desempate_descricao,
  DROP COLUMN IF EXISTS percentual_desconto;

COMMIT;
