-- Adiciona a coluna contratacao.compra_judicial.
--
-- Uso esperado:
-- psql -d medicamentos_transparentes \
--   -f tasks/alteracoes-no-banco-de-dados/verifica-compras-judiciais/src/sql/alter-contratacao-compra-judicial.sql

\set ON_ERROR_STOP on

BEGIN;

ALTER TABLE contratacao
ADD COLUMN IF NOT EXISTS compra_judicial BOOLEAN;

COMMENT ON COLUMN contratacao.compra_judicial IS
  'Indica se o objeto da contratação contém possível referência a demanda judicial.';

COMMIT;
