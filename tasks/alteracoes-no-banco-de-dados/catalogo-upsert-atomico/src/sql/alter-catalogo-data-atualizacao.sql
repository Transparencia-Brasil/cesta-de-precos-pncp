-- Adiciona e inicializa catalogo.data_atualizacao em bancos existentes.
-- A migração é idempotente e não altera data_insercao.

\set ON_ERROR_STOP on

BEGIN;

ALTER TABLE catalogo
ADD COLUMN IF NOT EXISTS data_atualizacao TIMESTAMP;

UPDATE catalogo
SET data_atualizacao = COALESCE(data_insercao, CURRENT_TIMESTAMP)
WHERE data_atualizacao IS NULL;

ALTER TABLE catalogo
ALTER COLUMN data_atualizacao SET DEFAULT CURRENT_TIMESTAMP,
ALTER COLUMN data_atualizacao SET NOT NULL;

COMMENT ON COLUMN catalogo.data_atualizacao IS
  'Data da inserção ou da atualização mais recente pelo loader do catálogo.';

COMMIT;
