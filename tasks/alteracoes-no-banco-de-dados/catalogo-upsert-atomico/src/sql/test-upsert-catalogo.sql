-- Teste transacional do comportamento híbrido e do rollback.
-- Usa somente tabela temporária e termina com ROLLBACK.

\set ON_ERROR_STOP on

BEGIN;

CREATE TEMP TABLE catalogo (
  codigo_item INTEGER PRIMARY KEY,
  nome_item TEXT NOT NULL,
  data_insercao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  data_atualizacao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ON COMMIT DROP;

INSERT INTO catalogo (codigo_item, nome_item, data_insercao, data_atualizacao)
VALUES
  (100, 'Antigo 100', '2026-01-01', '2026-01-01'),
  (200, 'Antigo 200', '2026-01-01', '2026-01-01'),
  (300, 'Preservado 300', '2026-01-01', '2026-01-01');

INSERT INTO catalogo (codigo_item, nome_item)
VALUES
  (100, 'Novo 100'),
  (200, 'Novo 200'),
  (400, 'Novo 400')
ON CONFLICT (codigo_item)
DO UPDATE SET
  nome_item = EXCLUDED.nome_item,
  data_atualizacao = CURRENT_TIMESTAMP;

DO $$
BEGIN
  IF (SELECT count(*) FROM catalogo) <> 4 THEN
    RAISE EXCEPTION 'A carga híbrida deveria resultar em quatro códigos.';
  END IF;
  IF (SELECT nome_item FROM catalogo WHERE codigo_item = 100) <> 'Novo 100' THEN
    RAISE EXCEPTION 'O código 100 não foi atualizado.';
  END IF;
  IF (SELECT nome_item FROM catalogo WHERE codigo_item = 300) <> 'Preservado 300' THEN
    RAISE EXCEPTION 'O código antigo 300 não foi preservado.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM catalogo WHERE codigo_item = 400) THEN
    RAISE EXCEPTION 'O código novo 400 não foi inserido.';
  END IF;
  IF (SELECT data_insercao FROM catalogo WHERE codigo_item = 100) <> '2026-01-01' THEN
    RAISE EXCEPTION 'data_insercao do código atualizado foi alterada.';
  END IF;
  IF (SELECT data_atualizacao FROM catalogo WHERE codigo_item = 300) <> '2026-01-01' THEN
    RAISE EXCEPTION 'data_atualizacao do código preservado foi alterada.';
  END IF;
END
$$;

CREATE TEMP TABLE catalogo_antes_erro AS TABLE catalogo;

DO $$
BEGIN
  BEGIN
    UPDATE catalogo SET nome_item = 'Alteração que deve reverter' WHERE codigo_item = 100;
    INSERT INTO catalogo (codigo_item, nome_item) VALUES (500, NULL);
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  IF EXISTS (
    (SELECT * FROM catalogo EXCEPT SELECT * FROM catalogo_antes_erro)
    UNION ALL
    (SELECT * FROM catalogo_antes_erro EXCEPT SELECT * FROM catalogo)
  ) THEN
    RAISE EXCEPTION 'A subtransação com erro não foi integralmente revertida.';
  END IF;
END
$$;

ROLLBACK;
