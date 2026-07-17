-- Adiciona a item_homologado os campos de margem de preferencia do PNCP.
-- Os identificadores das colunas de destino seguem a convencao snake_case.

\set ON_ERROR_STOP on

BEGIN;

ALTER TABLE item_homologado
  ADD COLUMN IF NOT EXISTS aplicabilidade_margem_preferencia_normal TEXT,
  ADD COLUMN IF NOT EXISTS percentual_margem_preferencia_normal TEXT,
  ADD COLUMN IF NOT EXISTS aplicabilidade_margem_preferencia_adicional TEXT,
  ADD COLUMN IF NOT EXISTS percentual_margem_preferencia_adicional TEXT,
  ADD COLUMN IF NOT EXISTS tipo_margem_preferencia_codigo TEXT,
  ADD COLUMN IF NOT EXISTS tipo_margem_preferencia_nome TEXT,
  ADD COLUMN IF NOT EXISTS tipo_margem_preferencia TEXT,
  ADD COLUMN IF NOT EXISTS exigencia_conteudo_nacional TEXT;

COMMENT ON COLUMN item_homologado.aplicabilidade_margem_preferencia_normal IS 'Origem PNCP: aplicabilidadeMargemPreferenciaNormal.';
COMMENT ON COLUMN item_homologado.percentual_margem_preferencia_normal IS 'Origem PNCP: percentualMargemPreferenciaNormal.';
COMMENT ON COLUMN item_homologado.aplicabilidade_margem_preferencia_adicional IS 'Origem PNCP: aplicabilidadeMargemPreferenciaAdicional.';
COMMENT ON COLUMN item_homologado.percentual_margem_preferencia_adicional IS 'Origem PNCP: percentualMargemPreferenciaAdicional.';
COMMENT ON COLUMN item_homologado.tipo_margem_preferencia_codigo IS 'Origem PNCP: tipoMargemPreferencia.codigo.';
COMMENT ON COLUMN item_homologado.tipo_margem_preferencia_nome IS 'Origem PNCP: tipoMargemPreferencia.nome.';
COMMENT ON COLUMN item_homologado.tipo_margem_preferencia IS 'Origem PNCP: tipoMargemPreferencia.';
COMMENT ON COLUMN item_homologado.exigencia_conteudo_nacional IS 'Origem PNCP: exigenciaConteudoNacional.';

COMMIT;
