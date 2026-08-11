-- Cria uma cópia independente de catalogo, identificada pelo horário UTC.
-- O nome é exibido como BACKUP_CATALOGO no log do psql.

\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
  nome_backup TEXT := format(
    'catalogo_backup_%s',
    to_char(CURRENT_TIMESTAMP AT TIME ZONE 'UTC', 'YYYYMMDD_HH24MISS')
  );
  total_catalogo BIGINT;
  total_backup BIGINT;
BEGIN
  EXECUTE format(
    'CREATE TABLE %I (LIKE catalogo INCLUDING ALL)',
    nome_backup
  );
  EXECUTE format(
    'INSERT INTO %I SELECT * FROM catalogo',
    nome_backup
  );
  SELECT count(*) INTO total_catalogo FROM catalogo;
  EXECUTE format('SELECT count(*) FROM %I', nome_backup) INTO total_backup;

  IF total_backup <> total_catalogo THEN
    RAISE EXCEPTION
      'Backup incompleto: catalogo=%, backup=%',
      total_catalogo,
      total_backup;
  END IF;

  RAISE NOTICE
    'BACKUP_CATALOGO=% REGISTROS=%',
    nome_backup,
    total_backup;
END
$$;

COMMIT;
