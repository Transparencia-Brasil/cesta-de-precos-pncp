-- Restaura catalogo exatamente a partir de um backup criado por backup-catalogo.sql.
-- Uso: psql -v backup_table=catalogo_backup_AAAAMMDD_HHMMSS -f restaura-catalogo.sql

\set ON_ERROR_STOP on

\if :{?backup_table}
\else
  \echo 'Informe -v backup_table=catalogo_backup_AAAAMMDD_HHMMSS'
  \quit 2
\endif

BEGIN;

LOCK TABLE catalogo IN ACCESS EXCLUSIVE MODE;

INSERT INTO catalogo (
  codigo_classe,
  nome_classe,
  codigo_pdm,
  nome_pdm,
  codigo_item,
  nome_item,
  item_suspenso,
  item_ativo,
  item_sustentavel,
  características,
  caracteristicas_ocds,
  unidades_fornecimento,
  data_insercao,
  data_atualizacao
)
SELECT
  codigo_classe,
  nome_classe,
  codigo_pdm,
  nome_pdm,
  codigo_item,
  nome_item,
  item_suspenso,
  item_ativo,
  item_sustentavel,
  características,
  caracteristicas_ocds,
  unidades_fornecimento,
  data_insercao,
  data_atualizacao
FROM :"backup_table"
ON CONFLICT (codigo_item)
DO UPDATE SET
  codigo_classe = EXCLUDED.codigo_classe,
  nome_classe = EXCLUDED.nome_classe,
  codigo_pdm = EXCLUDED.codigo_pdm,
  nome_pdm = EXCLUDED.nome_pdm,
  nome_item = EXCLUDED.nome_item,
  item_suspenso = EXCLUDED.item_suspenso,
  item_ativo = EXCLUDED.item_ativo,
  item_sustentavel = EXCLUDED.item_sustentavel,
  características = EXCLUDED.características,
  caracteristicas_ocds = EXCLUDED.caracteristicas_ocds,
  unidades_fornecimento = EXCLUDED.unidades_fornecimento,
  data_insercao = EXCLUDED.data_insercao,
  data_atualizacao = EXCLUDED.data_atualizacao;

DELETE FROM catalogo AS atual
WHERE NOT EXISTS (
  SELECT 1
  FROM :"backup_table" AS backup
  WHERE backup.codigo_item = atual.codigo_item
);

CREATE TEMP TABLE controle_restauracao_catalogo AS
SELECT count(*)::BIGINT AS total_esperado
FROM :"backup_table";

DO $$
DECLARE
  total_esperado BIGINT;
  total_restaurado BIGINT;
BEGIN
  SELECT c.total_esperado
  INTO total_esperado
  FROM controle_restauracao_catalogo AS c;

  SELECT count(*) INTO total_restaurado FROM catalogo;

  IF total_restaurado <> total_esperado THEN
    RAISE EXCEPTION
      'Restauração incompleta: esperado=%, restaurado=%',
      total_esperado,
      total_restaurado;
  END IF;
END
$$;

COMMIT;
