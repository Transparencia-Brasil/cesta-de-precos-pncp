-- Adiciona a coluna catalogo.caracteristicas_ocds.
--
-- Uso esperado:
-- psql -d medicamentos-transparentes \
--   -f tasks/catalogo-caracteristicas-ocds/src/sql/alter-catalogo-caracteristicas-ocds.sql

\set ON_ERROR_STOP on

BEGIN;

ALTER TABLE catalogo
ADD COLUMN IF NOT EXISTS caracteristicas_ocds JSONB;

COMMENT ON COLUMN catalogo.caracteristicas_ocds IS
  'Atributos técnicos do medicamento mapeados para o padrão OCDS.';

COMMIT;
