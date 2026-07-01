-- Simulacao da carga incremental de item_homologado_marcas para rodar no SQLTools.
--
-- Este script nao usa \copy, nao altera tabelas reais e termina com ROLLBACK.
-- Ele cria tabelas temporarias com os nomes reais, simula uma linha ja existente,
-- carrega um lote com duplicata exata e insere somente marcas novas.

BEGIN;

-- usa somente colunas relevantes para o teste, sem constraints, indices ou comentarios
CREATE TEMP TABLE item_homologado (
  numero_controle_pncp VARCHAR(30) NOT NULL,
  numero_item INTEGER NOT NULL,
  codigo_item_catalogo INTEGER,
  ni_fornecedor VARCHAR(100),
  valor_unitario_homologado NUMERIC,
  quantidade_homologada INTEGER,
  data_resultado TIMESTAMP,
  PRIMARY KEY (numero_controle_pncp, numero_item)
) ON COMMIT DROP;

-- inspeciona item_homologado logo apos a criacao da temp table
SELECT
  'TEMP ITEM_HOMOLOGADO CRIADA' AS etapa,
  *
FROM item_homologado;

-- temp table com a mesma estrutura de item_homologado_marcas, sem constraints, indices ou comentarios
CREATE TEMP TABLE item_homologado_marcas (
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
  nome_unidade_medida VARCHAR(100),
  data_insercao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (
    numero_controle_pncp,
    numero_item,
    ni_fornecedor,
    id_compra_item,
    marca
  )
) ON COMMIT DROP;

-- inspeciona item_homologado_marcas logo apos a criacao da temp table
SELECT
  'TEMP ITEM_HOMOLOGADO_MARCAS CRIADA' AS etapa,
  *
FROM item_homologado_marcas;

-- popula item_homologado com 3 itens, para que o join com item_homologado_marcas funcione
INSERT INTO item_homologado (
  numero_controle_pncp,
  numero_item,
  codigo_item_catalogo,
  ni_fornecedor,
  valor_unitario_homologado,
  quantidade_homologada,
  data_resultado
)
VALUES
  (
    '18309724000187-1-000187/2024',
    5,
    278440,
    '27417234000195',
    6,
    60,
    '2024-08-20'
  ),
  (
    '18309724000187-1-000187/2024',
    6,
    398704,
    '23420875000148',
    45.9,
    120,
    '2024-08-20'
  ),
  (
    '87252045000131-1-000015/2024',
    1,
    267645,
    '05804216000123',
    2.05,
    13680,
    '2024-10-01'
  );

-- inspeciona item_homologado apos o insert de itens de teste
SELECT
  'ITEM_HOMOLOGADO APOS INSERT' AS etapa,
  *
FROM item_homologado
ORDER BY numero_controle_pncp, numero_item;

-- popula item_homologado_marcas com 1 linha, para simular que ja existe uma marca igual no banco
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
  nome_unidade_medida,
  data_insercao
)
VALUES (
  '18309724000187-1-000187/2024',
  5,
  '27417234000195',
  278440,
  '98467505901772024',
  '9846750590177202400005',
  277319,
  277319,
  60,
  6,
  'VIC PHARMA',
  'PEROXIDO DE HIDROGENIO (AGUA OXIGENADA), TIPO 10 VOLUMES',
  'FR',
  'FRASCO',
  'ML',
  NULL,
  '2026-01-01 00:00:00'
);

-- inspeciona item_homologado_marcas apos o insert da linha ja existente
SELECT
  'ITEM_HOMOLOGADO_MARCAS APOS INSERT INICIAL' AS etapa,
  *
FROM item_homologado_marcas
ORDER BY numero_controle_pncp, numero_item, ni_fornecedor, id_compra_item, marca;

-- temp table com a mesma estrutura de item_homologado_marcas, sem constraints, indices ou comentarios
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
) ON COMMIT DROP;

-- inspeciona tmp_item_homologado_marcas_csv logo apos a criacao da temp table
SELECT
  'TEMP TMP_ITEM_HOMOLOGADO_MARCAS_CSV CRIADA' AS etapa,
  *
FROM tmp_item_homologado_marcas_csv;

-- popula tmp_item_homologado_marcas_csv com 5 linhas, incluindo duplicata exata e linha ja existente
INSERT INTO tmp_item_homologado_marcas_csv (
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
VALUES
  (
    '18309724000187-1-000187/2024',
    '5',
    '27417234000195',
    '278440',
    '98467505901772024',
    '9846750590177202400005',
    '277319',
    '277319',
    '60',
    '6',
    'VIC PHARMA',
    'PEROXIDO DE HIDROGENIO (AGUA OXIGENADA), TIPO 10 VOLUMES',
    'FR',
    'FRASCO',
    'ML',
    'NA'
  ),
  (
    '18309724000187-1-000187/2024',
    '5',
    '27417234000195',
    '278440',
    '98467505901772024',
    '9846750590177202400005',
    '277319',
    '277319',
    '60',
    '6',
    'VIC PHARMA',
    'PEROXIDO DE HIDROGENIO (AGUA OXIGENADA), TIPO 10 VOLUMES',
    'FR',
    'FRASCO',
    'ML',
    'NA'
  ),
  (
    '18309724000187-1-000187/2024',
    '6',
    '23420875000148',
    '398704',
    '98467505901772024',
    '9846750590177202400006',
    '398705',
    '398705',
    '120',
    '45.9',
    'VIC PHARMA',
    'IODOPOVIDONA (PVPI), CONCENTRACAO A 10%',
    'FR',
    'FRASCO',
    'L',
    'NA'
  ),
  (
    '87252045000131-1-000015/2024',
    '1',
    '05804216000123',
    '267645',
    '92595805900052024',
    '9259580590005202400001',
    'NA',
    '267645',
    '13680',
    '2.05',
    'CX C/50',
    '',
    'NA',
    'NA',
    'NA',
    'NA'
  ),
  (
    '87252045000131-1-000015/2024',
    '1',
    '05804216000123',
    '267645',
    '92595805900052024',
    '9259580590005202400001',
    'NA',
    '267645',
    '13680',
    '2.05',
    'HIPOLABOR/1134301110',
    '',
    'NA',
    'NA',
    'NA',
    'NA'
  );

-- inspeciona tmp_item_homologado_marcas_csv apos o insert do lote bruto
SELECT
  'TMP_ITEM_HOMOLOGADO_MARCAS_CSV APOS INSERT' AS etapa,
  *
FROM tmp_item_homologado_marcas_csv
ORDER BY numero_controle_pncp, numero_item, ni_fornecedor, id_compra_item, marca;

-- cria tmp_item_homologado_marcas com dados tratados e convertidos para os tipos corretos
-- essa tabela temporaria simula o resultado do \copy do CSV para tmp_item_homologado_marcas_csv
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
) ON COMMIT DROP;

-- inspeciona tmp_item_homologado_marcas logo apos a criacao da temp table
SELECT
  'TEMP TMP_ITEM_HOMOLOGADO_MARCAS CRIADA' AS etapa,
  *
FROM tmp_item_homologado_marcas;

-- popula tmp_item_homologado_marcas com dados tratados que estão em tmp_item_homologado_marcas_csv
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

-- inspeciona tmp_item_homologado_marcas apos o insert com tratamento de tipos e NAs
SELECT
  'TMP_ITEM_HOMOLOGADO_MARCAS APOS INSERT TRATADO' AS etapa,
  *
FROM tmp_item_homologado_marcas
ORDER BY numero_controle_pncp, numero_item, ni_fornecedor, id_compra_item, marca;

-- Cria uma tabela temporaria com as linhas distintas de tmp_item_homologado_marcas, para detectar duplicatas exatas
CREATE TEMP TABLE tmp_item_homologado_marcas_distintas ON COMMIT DROP AS
SELECT DISTINCT *
FROM tmp_item_homologado_marcas;

-- inspeciona tmp_item_homologado_marcas_distintas apos a criacao da temp table
SELECT
  'TEMP TMP_ITEM_HOMOLOGADO_MARCAS_DISTINTAS CRIADA' AS etapa,
  *
FROM tmp_item_homologado_marcas_distintas
ORDER BY numero_controle_pncp, numero_item, ni_fornecedor, id_compra_item, marca;

-- Valida se o lote de teste tem chaves divergentes, itens sem correspondencia em item_homologado ou conflito com linha existente
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
    RAISE EXCEPTION 'Chaves divergentes inesperadas no lote de teste.';
  END IF;

-- Valida se o lote de teste tem item sem correspondencia em item_homologado
  SELECT COUNT(*)
  INTO itens_nao_encontrados
  FROM tmp_item_homologado_marcas_distintas AS marcas
  LEFT JOIN item_homologado AS item
    ON item.numero_controle_pncp = marcas.numero_controle_pncp
   AND item.numero_item = marcas.numero_item
  WHERE item.numero_controle_pncp IS NULL;

-- Se houver itens sem correspondencia, levanta excecao para que o teste falhe
  IF itens_nao_encontrados > 0 THEN
    RAISE EXCEPTION 'O lote de teste tem item sem correspondencia em item_homologado.';
  END IF;

-- Valida se o lote de teste tem conflito com linha existente em item_homologado_marcas
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

-- Se houver conflito com linha existente, levanta excecao para que o teste falhe
  IF conflitos_existentes > 0 THEN
    RAISE EXCEPTION 'Conflito com linha existente inesperado no teste.';
  END IF;
END;
$$;

-- Cria uma tabela temporaria com as linhas que ja existem em item_homologado_marcas
CREATE TEMP TABLE tmp_item_homologado_marcas_ja_existentes ON COMMIT DROP AS
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

-- inspeciona tmp_item_homologado_marcas_ja_existentes apos a criacao da temp table
SELECT
  'TEMP TMP_ITEM_HOMOLOGADO_MARCAS_JA_EXISTENTES CRIADA' AS etapa,
  *
FROM tmp_item_homologado_marcas_ja_existentes
ORDER BY numero_controle_pncp, numero_item, ni_fornecedor, id_compra_item, marca;

-- Cria uma tabela temporaria com o resultado da insercao de novas linhas em item_homologado_marcas
CREATE TEMP TABLE tmp_item_homologado_marcas_inseridas ON COMMIT DROP AS
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

-- inspeciona tmp_item_homologado_marcas_inseridas apos a criacao da temp table
SELECT
  'TEMP TMP_ITEM_HOMOLOGADO_MARCAS_INSERIDAS CRIADA' AS etapa,
  *
FROM tmp_item_homologado_marcas_inseridas;

-- inspeciona item_homologado_marcas apos o insert das novas marcas
SELECT
  'ITEM_HOMOLOGADO_MARCAS APOS INSERT FINAL' AS etapa,
  *
FROM item_homologado_marcas
ORDER BY numero_controle_pncp, numero_item, ni_fornecedor, id_compra_item, marca;

-- Cria uma tabela temporaria com o resumo das contagens de linhas
SELECT
  (SELECT COUNT(*) FROM tmp_item_homologado_marcas_csv) AS linhas_csv,
  (SELECT COUNT(*) FROM tmp_item_homologado_marcas_distintas) AS linhas_distintas,
  (
    (SELECT COUNT(*) FROM tmp_item_homologado_marcas)
    - (SELECT COUNT(*) FROM tmp_item_homologado_marcas_distintas)
  ) AS duplicatas_exatas_ignoradas,
  (SELECT COUNT(*) FROM tmp_item_homologado_marcas_ja_existentes) AS ja_existentes_iguais,
  (SELECT novas_inseridas FROM tmp_item_homologado_marcas_inseridas) AS novas_inseridas,
  (SELECT COUNT(*) FROM item_homologado_marcas) AS total_final;

-- Valida se o join com item_homologado funciona corretamente
SELECT
  'JOIN COM ITEM_HOMOLOGADO' AS etapa,
  marcas.numero_controle_pncp,
  marcas.numero_item,
  marcas.marca,
  item.codigo_item_catalogo AS codigo_item_catalogo_item_homologado,
  marcas.codigo_item_catalogo AS codigo_item_catalogo_marcas,
  item.valor_unitario_homologado AS valor_item_homologado,
  marcas.valor_unitario_homologado AS valor_marcas
FROM item_homologado_marcas AS marcas
INNER JOIN item_homologado AS item
  ON item.numero_controle_pncp = marcas.numero_controle_pncp
 AND item.numero_item = marcas.numero_item
ORDER BY marcas.numero_controle_pncp, marcas.numero_item, marcas.marca;

-- Valida se a normalizacao de NA para NULL funciona corretamente
DO $$
BEGIN
  IF (SELECT COUNT(*) FROM tmp_item_homologado_marcas_csv) <> 5 THEN
    RAISE EXCEPTION 'Total de linhas CSV inesperado no teste.';
  END IF;

  IF (SELECT COUNT(*) FROM tmp_item_homologado_marcas_distintas) <> 4 THEN
    RAISE EXCEPTION 'Deduplicacao exata nao teve o resultado esperado.';
  END IF;

  IF (SELECT COUNT(*) FROM tmp_item_homologado_marcas_ja_existentes) <> 1 THEN
    RAISE EXCEPTION 'Linha existente igual nao foi detectada no teste.';
  END IF;

  IF (SELECT novas_inseridas FROM tmp_item_homologado_marcas_inseridas) <> 3 THEN
    RAISE EXCEPTION 'Total de linhas novas inseridas inesperado no teste.';
  END IF;

  IF (SELECT COUNT(*) FROM item_homologado_marcas) <> 4 THEN
    RAISE EXCEPTION 'Total final de marcas inesperado no teste.';
  END IF;

  IF (
    SELECT COUNT(*)
    FROM item_homologado_marcas AS marcas
    INNER JOIN item_homologado AS item
      ON item.numero_controle_pncp = marcas.numero_controle_pncp
     AND item.numero_item = marcas.numero_item
  ) <> 4 THEN
    RAISE EXCEPTION 'Join com item_homologado nao encontrou todas as marcas.';
  END IF;

  IF (
    SELECT COUNT(*)
    FROM item_homologado_marcas
    WHERE codigo_item_catalogo_tbl_itens IS NULL
      AND nome_unidade_medida IS NULL
  ) <> 2 THEN
    RAISE EXCEPTION 'Normalizacao de NA para NULL nao teve o resultado esperado.';
  END IF;

  IF (
    SELECT data_insercao
    FROM item_homologado_marcas
    WHERE numero_controle_pncp = '18309724000187-1-000187/2024'
      AND numero_item = 5
      AND marca = 'VIC PHARMA'
  ) <> '2026-01-01 00:00:00'::TIMESTAMP THEN
    RAISE EXCEPTION 'Linha existente teve data_insercao alterada.';
  END IF;
END;
$$;

ROLLBACK;
