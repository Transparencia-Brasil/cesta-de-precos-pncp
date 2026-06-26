-- Simulacao da populacao de contratacao.compra_judicial para rodar no SQLTools.
--
-- Este script nao usa \copy, nao altera tabelas reais e termina com ROLLBACK.
-- Ele reproduz a tabela contratacao a partir do schema real, insere amostras
-- do dataset outputs/compras-judiciais-completo.csv e aplica o backfill.

BEGIN;

CREATE TEMP TABLE tmp_contratacao (
  numero_controle_pncp VARCHAR(30) PRIMARY KEY,
  ano_compra SMALLINT NOT NULL,
  sequencial_compra INTEGER NOT NULL,
  objeto_compra TEXT,
  data_abertura_proposta TIMESTAMP,
  data_encerramento_proposta TIMESTAMP,
  valor_estimado_compra NUMERIC,
  valor_homologado_compra NUMERIC,
  srp BOOLEAN,
  codigo_tipo_instrumento_convocatorio SMALLINT NOT NULL,
  nome_tipo_instrumento_convocatorio VARCHAR(100) NOT NULL,
  codigo_modalidade SMALLINT NOT NULL,
  nome_modalidade VARCHAR(100) NOT NULL,
  codigo_amparo_legal SMALLINT NOT NULL,
  nome_amparo_legal VARCHAR(100) NOT NULL,
  codigo_modo_disputa SMALLINT NOT NULL,
  nome_modo_disputa VARCHAR(100) NOT NULL,
  data_insercao TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ON COMMIT DROP;

INSERT INTO tmp_contratacao (
  numero_controle_pncp,
  ano_compra,
  sequencial_compra,
  objeto_compra,
  srp,
  codigo_tipo_instrumento_convocatorio,
  nome_tipo_instrumento_convocatorio,
  codigo_modalidade,
  nome_modalidade,
  codigo_amparo_legal,
  nome_amparo_legal,
  codigo_modo_disputa,
  nome_modo_disputa
)
VALUES
  (
    '63025530000104-1-000756/2026',
    2026,
    756,
    'Aquisição de insumos para controle de vetores.',
    FALSE,
    1,
    'Edital',
    8,
    'Dispensa',
    1,
    'Lei 14.133/2021',
    1,
    'Aberto'
  ),
  (
    '47970769000104-1-000136/2026',
    2026,
    136,
    'AQUISIÇÃO DE MEDICAMENTOS PARA ATENDIMENTO DE DEMANDAS JUDICIAIS COM DISPENSA DE LICITAÇÃO EMERGENCIAL SEM DISPUTA.',
    FALSE,
    1,
    'Edital',
    8,
    'Dispensa',
    1,
    'Lei 14.133/2021',
    1,
    'Aberto'
  );

SELECT
  '01 CONTRATACAO ANTES DO ALTER TABLE' AS etapa,
  numero_controle_pncp,
  objeto_compra,
  srp,
  codigo_modalidade,
  nome_modalidade
FROM tmp_contratacao
ORDER BY numero_controle_pncp;

ALTER TABLE tmp_contratacao
ADD COLUMN IF NOT EXISTS compra_judicial BOOLEAN;

SELECT
  '02 CONTRATACAO APOS ALTER TABLE, ANTES DO UPDATE' AS etapa,
  numero_controle_pncp,
  objeto_compra,
  compra_judicial
FROM tmp_contratacao
ORDER BY numero_controle_pncp;

CREATE TEMP TABLE tmp_contratacao_compra_judicial (
  numero_controle_pncp VARCHAR(30) PRIMARY KEY,
  srp TEXT,
  objeto_compra TEXT,
  codigo_modalidade TEXT,
  nome_modalidade TEXT,
  compra_judicial TEXT
) ON COMMIT DROP;

INSERT INTO tmp_contratacao_compra_judicial (
  numero_controle_pncp,
  srp,
  objeto_compra,
  codigo_modalidade,
  nome_modalidade,
  compra_judicial
)
VALUES
  (
    '63025530000104-1-000756/2026',
    'False',
    'Aquisição de insumos para controle de vetores.',
    '8',
    'Dispensa',
    'False'
  ),
  (
    '47970769000104-1-000136/2026',
    'False',
    'AQUISIÇÃO DE MEDICAMENTOS PARA ATENDIMENTO DE DEMANDAS JUDICIAIS COM DISPENSA DE LICITAÇÃO EMERGENCIAL SEM DISPUTA.',
    '8',
    'Dispensa',
    'True'
  );

SELECT
  '03 DATASET DE COMPRAS JUDICIAIS' AS etapa,
  numero_controle_pncp,
  compra_judicial
FROM tmp_contratacao_compra_judicial
ORDER BY numero_controle_pncp;

UPDATE tmp_contratacao AS c
SET compra_judicial = lower(btrim(t.compra_judicial))::boolean
FROM tmp_contratacao_compra_judicial AS t
WHERE c.numero_controle_pncp = t.numero_controle_pncp;

SELECT
  '04 CONTRATACAO DEPOIS DO UPDATE' AS etapa,
  numero_controle_pncp,
  objeto_compra,
  compra_judicial
FROM tmp_contratacao
ORDER BY numero_controle_pncp;

SELECT
  COUNT(*) AS total_contratacoes,
  COUNT(*) FILTER (WHERE compra_judicial IS NULL) AS sem_classificacao,
  COUNT(*) FILTER (WHERE compra_judicial IS TRUE) AS compras_judiciais,
  COUNT(*) FILTER (WHERE compra_judicial IS FALSE) AS compras_nao_judiciais
FROM tmp_contratacao;

ROLLBACK;
