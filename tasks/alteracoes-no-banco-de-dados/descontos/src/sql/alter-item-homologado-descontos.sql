-- Adiciona a item_homologado os campos de margem de preferencia do PNCP.
-- Os identificadores preservam exatamente os nomes recebidos da API do PNCP.

\set ON_ERROR_STOP on

BEGIN;

ALTER TABLE item_homologado
  ADD COLUMN IF NOT EXISTS "aplicabilidadeMargemPreferenciaNormal" TEXT,
  ADD COLUMN IF NOT EXISTS "percentualMargemPreferenciaNormal" TEXT,
  ADD COLUMN IF NOT EXISTS "aplicabilidadeMargemPreferenciaAdicional" TEXT,
  ADD COLUMN IF NOT EXISTS "percentualMargemPreferenciaAdicional" TEXT,
  ADD COLUMN IF NOT EXISTS "tipoMargemPreferencia.codigo" TEXT,
  ADD COLUMN IF NOT EXISTS "tipoMargemPreferencia.nome" TEXT,
  ADD COLUMN IF NOT EXISTS "tipoMargemPreferencia" TEXT,
  ADD COLUMN IF NOT EXISTS "exigenciaConteudoNacional" TEXT;

COMMENT ON COLUMN item_homologado."aplicabilidadeMargemPreferenciaNormal" IS 'Origem PNCP: aplicabilidadeMargemPreferenciaNormal.';
COMMENT ON COLUMN item_homologado."percentualMargemPreferenciaNormal" IS 'Origem PNCP: percentualMargemPreferenciaNormal.';
COMMENT ON COLUMN item_homologado."aplicabilidadeMargemPreferenciaAdicional" IS 'Origem PNCP: aplicabilidadeMargemPreferenciaAdicional.';
COMMENT ON COLUMN item_homologado."percentualMargemPreferenciaAdicional" IS 'Origem PNCP: percentualMargemPreferenciaAdicional.';
COMMENT ON COLUMN item_homologado."tipoMargemPreferencia.codigo" IS 'Origem PNCP: tipoMargemPreferencia.codigo.';
COMMENT ON COLUMN item_homologado."tipoMargemPreferencia.nome" IS 'Origem PNCP: tipoMargemPreferencia.nome.';
COMMENT ON COLUMN item_homologado."tipoMargemPreferencia" IS 'Origem PNCP: tipoMargemPreferencia.';
COMMENT ON COLUMN item_homologado."exigenciaConteudoNacional" IS 'Origem PNCP: exigenciaConteudoNacional.';

COMMIT;
