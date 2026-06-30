-- Atualiza item_homologado_marcas de forma incremental a partir do CSV da task api-compras.
--
-- Pre-requisito:
-- executar antes:
-- tasks/alteracoes-no-banco-de-dados/tabela-marcas-compras-gov/src/sql/create-table-item-homologado-marcas.sql.
--
-- Uso esperado:
-- psql -d medicamentos_transparentes \
--   -v dataset_csv='tasks/api-compras/outputs/tabela-marcas.csv' \
--   -f tasks/alteracoes-no-banco-de-dados/tabela-marcas-compras-gov/src/sql/update-item-homologado-marcas.sql

\set ON_ERROR_STOP on

BEGIN;

DROP TABLE IF EXISTS pg_temp.tmp_item_homologado_marcas_csv;
DROP TABLE IF EXISTS pg_temp.tmp_item_homologado_marcas;
DROP TABLE IF EXISTS pg_temp.tmp_item_homologado_marcas_distintas;
DROP TABLE IF EXISTS pg_temp.tmp_item_homologado_marcas_ja_existentes;
DROP TABLE IF EXISTS pg_temp.tmp_item_homologado_marcas_inseridas;

CREATE TEMP TABLE tmp_item_homologado_marcas_csv (
  numero_controle_pncp TEXT,
  numero_item TEXT,
  ni_fornecedor TEXT,
  codigo_item_catalogo TEXT,
  id_compra TEXT,
  id_compra_item TEXT,
  codigo_item_catalogo_tbl_itens TEXT,
  codigo_item_catalogo_tbl_marcas TEXT,
  quantidade_homologada TEXT,
  valor_unitario_homologado TEXT,
  marca TEXT,
  descricao_detalhada_item TEXT,
  sigla_unidade_fornecimento TEXT,
  nome_unidade_fornecimento TEXT,
  sigla_unidade_medida TEXT,
  nome_unidade_medida TEXT
);

\copy tmp_item_homologado_marcas_csv FROM :'dataset_csv' WITH (FORMAT csv, HEADER true, NULL '')

DO $$
DECLARE
  linhas_invalidas INTEGER;
BEGIN
  SELECT COUNT(*)
  INTO linhas_invalidas
  FROM tmp_item_homologado_marcas_csv
  WHERE NULLIF(btrim(numero_controle_pncp), '') IS NULL
     OR NULLIF(btrim(numero_item), '') IS NULL
     OR NULLIF(btrim(ni_fornecedor), '') IS NULL
     OR NULLIF(btrim(codigo_item_catalogo), '') IS NULL
     OR NULLIF(btrim(id_compra), '') IS NULL
     OR NULLIF(btrim(id_compra_item), '') IS NULL
     OR NULLIF(btrim(codigo_item_catalogo_tbl_marcas), '') IS NULL
     OR NULLIF(btrim(quantidade_homologada), '') IS NULL
     OR NULLIF(btrim(valor_unitario_homologado), '') IS NULL
     OR NULLIF(btrim(marca), '') IS NULL;

  IF linhas_invalidas > 0 THEN
    RAISE EXCEPTION
      'O CSV contem % linha(s) com campos obrigatorios vazios.', linhas_invalidas;
  END IF;

  SELECT COUNT(*)
  INTO linhas_invalidas
  FROM tmp_item_homologado_marcas_csv
  WHERE btrim(numero_item) !~ '^[0-9]+$'
     OR btrim(codigo_item_catalogo) !~ '^[0-9]+$'
     OR btrim(codigo_item_catalogo_tbl_marcas) !~ '^[0-9]+$'
     OR btrim(quantidade_homologada) !~ '^[0-9]+$'
     OR btrim(valor_unitario_homologado) !~ '^[0-9]+([.][0-9]+)?$'
     OR (
       NULLIF(btrim(codigo_item_catalogo_tbl_itens), '') IS NOT NULL
       AND upper(btrim(codigo_item_catalogo_tbl_itens)) <> 'NA'
       AND btrim(codigo_item_catalogo_tbl_itens) !~ '^[0-9]+$'
     );

  IF linhas_invalidas > 0 THEN
    RAISE EXCEPTION
      'O CSV contem % linha(s) com valores numericos invalidos.', linhas_invalidas;
  END IF;
END;
$$;

CREATE TEMP TABLE tmp_item_homologado_marcas (
  numero_controle_pncp VARCHAR(30) NOT NULL,
  numero_item INTEGER NOT NULL,
  ni_fornecedor VARCHAR(100) NOT NULL,
  codigo_item_catalogo INTEGER NOT NULL,
  id_compra VARCHAR(30) NOT NULL,
  id_compra_item VARCHAR(30) NOT NULL,
  codigo_item_catalogo_tbl_itens INTEGER,
  codigo_item_catalogo_tbl_marcas INTEGER NOT NULL,
  quantidade_homologada INTEGER NOT NULL,
  valor_unitario_homologado NUMERIC NOT NULL,
  marca VARCHAR(255) NOT NULL,
  descricao_detalhada_item TEXT,
  sigla_unidade_fornecimento VARCHAR(50),
  nome_unidade_fornecimento VARCHAR(100),
  sigla_unidade_medida VARCHAR(50),
  nome_unidade_medida VARCHAR(100)
);

INSERT INTO tmp_item_homologado_marcas (
  numero_controle_pncp,
  numero_item,
  ni_fornecedor,
  codigo_item_catalogo,
  id_compra,
  id_compra_item,
  codigo_item_catalogo_tbl_itens,
  codigo_item_catalogo_tbl_marcas,
  quantidade_homologada,
  valor_unitario_homologado,
  marca,
  descricao_detalhada_item,
  sigla_unidade_fornecimento,
  nome_unidade_fornecimento,
  sigla_unidade_medida,
  nome_unidade_medida
)
SELECT
  btrim(numero_controle_pncp),
  btrim(numero_item)::INTEGER,
  btrim(ni_fornecedor),
  btrim(codigo_item_catalogo)::INTEGER,
  btrim(id_compra),
  btrim(id_compra_item),
  CASE
    WHEN NULLIF(btrim(codigo_item_catalogo_tbl_itens), '') IS NULL
      OR upper(btrim(codigo_item_catalogo_tbl_itens)) = 'NA'
    THEN NULL
    ELSE btrim(codigo_item_catalogo_tbl_itens)::INTEGER
  END,
  btrim(codigo_item_catalogo_tbl_marcas)::INTEGER,
  btrim(quantidade_homologada)::INTEGER,
  btrim(valor_unitario_homologado)::NUMERIC,
  btrim(marca),
  CASE
    WHEN NULLIF(btrim(descricao_detalhada_item), '') IS NULL
      OR upper(btrim(descricao_detalhada_item)) = 'NA'
    THEN NULL
    ELSE btrim(descricao_detalhada_item)
  END,
  CASE
    WHEN NULLIF(btrim(sigla_unidade_fornecimento), '') IS NULL
      OR upper(btrim(sigla_unidade_fornecimento)) = 'NA'
    THEN NULL
    ELSE btrim(sigla_unidade_fornecimento)
  END,
  CASE
    WHEN NULLIF(btrim(nome_unidade_fornecimento), '') IS NULL
      OR upper(btrim(nome_unidade_fornecimento)) = 'NA'
    THEN NULL
    ELSE btrim(nome_unidade_fornecimento)
  END,
  CASE
    WHEN NULLIF(btrim(sigla_unidade_medida), '') IS NULL
      OR upper(btrim(sigla_unidade_medida)) = 'NA'
    THEN NULL
    ELSE btrim(sigla_unidade_medida)
  END,
  CASE
    WHEN NULLIF(btrim(nome_unidade_medida), '') IS NULL
      OR upper(btrim(nome_unidade_medida)) = 'NA'
    THEN NULL
    ELSE btrim(nome_unidade_medida)
  END
FROM tmp_item_homologado_marcas_csv;

CREATE TEMP TABLE tmp_item_homologado_marcas_distintas AS
SELECT DISTINCT *
FROM tmp_item_homologado_marcas;

DO $$
DECLARE
  chaves_divergentes INTEGER;
  itens_nao_encontrados INTEGER;
  conflitos_existentes INTEGER;
BEGIN
  SELECT COUNT(*)
  INTO chaves_divergentes
  FROM (
    SELECT
      numero_controle_pncp,
      numero_item,
      ni_fornecedor,
      id_compra_item,
      marca
    FROM tmp_item_homologado_marcas_distintas
    GROUP BY
      numero_controle_pncp,
      numero_item,
      ni_fornecedor,
      id_compra_item,
      marca
    HAVING COUNT(*) > 1
  ) AS divergentes;

  IF chaves_divergentes > 0 THEN
    RAISE EXCEPTION
      'O CSV contem % chave(s) naturais com valores divergentes para item_homologado_marcas.',
      chaves_divergentes;
  END IF;

  SELECT COUNT(*)
  INTO itens_nao_encontrados
  FROM tmp_item_homologado_marcas_distintas AS marcas
  LEFT JOIN item_homologado AS item
    ON item.numero_controle_pncp = marcas.numero_controle_pncp
   AND item.numero_item = marcas.numero_item
  WHERE item.numero_controle_pncp IS NULL;

  IF itens_nao_encontrados > 0 THEN
    RAISE EXCEPTION
      'O CSV contem % linha(s) sem item correspondente em item_homologado.', itens_nao_encontrados;
  END IF;

  SELECT COUNT(*)
  INTO conflitos_existentes
  FROM tmp_item_homologado_marcas_distintas AS lote
  INNER JOIN item_homologado_marcas AS existente
    ON existente.numero_controle_pncp = lote.numero_controle_pncp
   AND existente.numero_item = lote.numero_item
   AND existente.ni_fornecedor = lote.ni_fornecedor
   AND existente.id_compra_item = lote.id_compra_item
   AND existente.marca = lote.marca
  WHERE lote.codigo_item_catalogo IS DISTINCT FROM existente.codigo_item_catalogo
     OR lote.id_compra IS DISTINCT FROM existente.id_compra
     OR lote.codigo_item_catalogo_tbl_itens IS DISTINCT FROM existente.codigo_item_catalogo_tbl_itens
     OR lote.codigo_item_catalogo_tbl_marcas IS DISTINCT FROM existente.codigo_item_catalogo_tbl_marcas
     OR lote.quantidade_homologada IS DISTINCT FROM existente.quantidade_homologada
     OR lote.valor_unitario_homologado IS DISTINCT FROM existente.valor_unitario_homologado
     OR lote.descricao_detalhada_item IS DISTINCT FROM existente.descricao_detalhada_item
     OR lote.sigla_unidade_fornecimento IS DISTINCT FROM existente.sigla_unidade_fornecimento
     OR lote.nome_unidade_fornecimento IS DISTINCT FROM existente.nome_unidade_fornecimento
     OR lote.sigla_unidade_medida IS DISTINCT FROM existente.sigla_unidade_medida
     OR lote.nome_unidade_medida IS DISTINCT FROM existente.nome_unidade_medida;

  IF conflitos_existentes > 0 THEN
    RAISE EXCEPTION
      'O lote contem % linha(s) com chave ja existente e valores divergentes em item_homologado_marcas.',
      conflitos_existentes;
  END IF;
END;
$$;

CREATE TEMP TABLE tmp_item_homologado_marcas_ja_existentes AS
SELECT
  lote.numero_controle_pncp,
  lote.numero_item,
  lote.ni_fornecedor,
  lote.id_compra_item,
  lote.marca
FROM tmp_item_homologado_marcas_distintas AS lote
INNER JOIN item_homologado_marcas AS existente
  ON existente.numero_controle_pncp = lote.numero_controle_pncp
 AND existente.numero_item = lote.numero_item
 AND existente.ni_fornecedor = lote.ni_fornecedor
 AND existente.id_compra_item = lote.id_compra_item
 AND existente.marca = lote.marca;

CREATE TEMP TABLE tmp_item_homologado_marcas_inseridas AS
WITH inseridas AS (
  INSERT INTO item_homologado_marcas (
    numero_controle_pncp,
    numero_item,
    ni_fornecedor,
    codigo_item_catalogo,
    id_compra,
    id_compra_item,
    codigo_item_catalogo_tbl_itens,
    codigo_item_catalogo_tbl_marcas,
    quantidade_homologada,
    valor_unitario_homologado,
    marca,
    descricao_detalhada_item,
    sigla_unidade_fornecimento,
    nome_unidade_fornecimento,
    sigla_unidade_medida,
    nome_unidade_medida
  )
  SELECT
    numero_controle_pncp,
    numero_item,
    ni_fornecedor,
    codigo_item_catalogo,
    id_compra,
    id_compra_item,
    codigo_item_catalogo_tbl_itens,
    codigo_item_catalogo_tbl_marcas,
    quantidade_homologada,
    valor_unitario_homologado,
    marca,
    descricao_detalhada_item,
    sigla_unidade_fornecimento,
    nome_unidade_fornecimento,
    sigla_unidade_medida,
    nome_unidade_medida
  FROM tmp_item_homologado_marcas_distintas
  ORDER BY numero_controle_pncp, numero_item, id_compra_item, marca
  ON CONFLICT (
    numero_controle_pncp,
    numero_item,
    ni_fornecedor,
    id_compra_item,
    marca
  ) DO NOTHING
  RETURNING 1
)
SELECT COUNT(*)::BIGINT AS novas_inseridas
FROM inseridas;

COMMIT;

WITH itens AS (
  SELECT
    numero_controle_pncp,
    numero_item,
    COUNT(*) AS total_linhas,
    COUNT(DISTINCT marca) AS marcas_distintas
  FROM item_homologado_marcas
  GROUP BY numero_controle_pncp, numero_item
)
SELECT
  (SELECT COUNT(*) FROM tmp_item_homologado_marcas_csv) AS linhas_csv,
  (SELECT COUNT(*) FROM tmp_item_homologado_marcas_distintas) AS linhas_distintas,
  (
    (SELECT COUNT(*) FROM tmp_item_homologado_marcas)
    - (SELECT COUNT(*) FROM tmp_item_homologado_marcas_distintas)
  ) AS duplicatas_exatas_ignoradas,
  (SELECT COUNT(*) FROM tmp_item_homologado_marcas_ja_existentes) AS ja_existentes_iguais,
  (SELECT novas_inseridas FROM tmp_item_homologado_marcas_inseridas) AS novas_inseridas,
  (SELECT COUNT(*) FROM item_homologado_marcas) AS total_final,
  (SELECT COUNT(*) FROM itens) AS itens_distintos,
  (SELECT COUNT(*) FROM itens WHERE marcas_distintas > 1) AS itens_com_multiplas_marcas,
  (SELECT COUNT(DISTINCT marca) FROM item_homologado_marcas) AS marcas_distintas;
