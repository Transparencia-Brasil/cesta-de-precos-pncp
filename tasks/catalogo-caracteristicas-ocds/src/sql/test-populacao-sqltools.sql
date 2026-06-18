-- Simulacao da populacao de catalogo.caracteristicas_ocds para rodar no SQLTools.
--
-- Este script nao usa \copy, nao altera tabelas reais e termina com ROLLBACK.
-- Ele reproduz a tabela catalogo a partir do schema real, insere amostras do
-- catmat.csv e aplica o backfill com amostras do dataset
-- tasks/catalogo-caracteristicas-ocds/input/tabela-mapeamento-ocds.csv.
--
-- Observacao: PostgreSQL nao permite escolher a posicao fisica de uma coluna
-- nova com ALTER TABLE. A coluna caracteristicas_ocds e adicionada ao fim da
-- tabela, mas os SELECTs abaixo exibem a coluna logo depois de caracteristicas
-- para facilitar a conferencia visual.

BEGIN;

CREATE TEMP TABLE catalogo (
  codigo_classe SMALLINT NOT NULL,
  nome_classe VARCHAR(100) NOT NULL,
  codigo_pdm INTEGER NOT NULL,
  nome_pdm VARCHAR(100) NOT NULL,
  codigo_item INTEGER PRIMARY KEY,
  nome_item VARCHAR(1000) NOT NULL,
  item_suspenso BOOLEAN,
  item_ativo BOOLEAN,
  item_sustentavel BOOLEAN,
  características JSONB NOT NULL,
  unidades_fornecimento JSONB NOT NULL,
  data_insercao TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ON COMMIT DROP;

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
  unidades_fornecimento,
  data_insercao
)
VALUES
  (
    6505,
    'DROGAS E MEDICAMENTOS',
    14597,
    'Petrolato',
    233632,
    'Petrolato, Aspecto Fisico:Liquido, Tipo:Laxativo, Uso:Oral',
    FALSE,
    TRUE,
    FALSE,
    '[]'::jsonb,
    '[{"nomeUnidadeMedida": "Grama", "siglaUnidadeMedida": "G", "capacidadeUnidadeMedida": 10, "nomeUnidadeFornecimento": "Bisnaga", "siglaUnidadeFornecimento": "BIS"}]'::jsonb,
    '2025-03-20T19:57:26Z'::timestamp
  ),
  (
    6505,
    'DROGAS E MEDICAMENTOS',
    8325,
    'Imunoglobulina Humana',
    260160,
    'Imunoglobulina Humana, Tipo:Hiper Imuni Para Hepatite B, Dosagem:50 Ui/Ml, Apresentacao:Solucao Injetavel',
    FALSE,
    TRUE,
    FALSE,
    '[{"nomeCaracteristica": "Tipo", "nomeValorCaracteristica": "Hiper Imuni Para Hepatite B"}]'::jsonb,
    '[{"nomeUnidadeMedida": "Mililitro", "siglaUnidadeMedida": "ML", "capacidadeUnidadeMedida": 0.5, "nomeUnidadeFornecimento": "Ampola", "siglaUnidadeFornecimento": "AM"}]'::jsonb,
    '2025-03-20T19:57:26Z'::timestamp
  );

SELECT
  '01 CATALOGO ANTES DO ALTER TABLE' AS etapa,
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
  unidades_fornecimento,
  data_insercao
FROM catalogo
ORDER BY codigo_item;

ALTER TABLE catalogo
ADD COLUMN IF NOT EXISTS caracteristicas_ocds JSONB;

SELECT
  '02 CATALOGO APOS ALTER TABLE, ANTES DO UPDATE' AS etapa,
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
  CASE
    WHEN caracteristicas_ocds IS NULL THEN 'sem mapeamento OCDS'
    ELSE 'com mapeamento OCDS'
  END AS status_ocds
FROM catalogo
ORDER BY codigo_item;

CREATE TEMP TABLE tmp_catalogo_caracteristicas_ocds (
  codigo_classe TEXT,
  nome_classe TEXT,
  codigo_pdm TEXT,
  codigo_item INTEGER PRIMARY KEY,
  nome_item TEXT,
  item_suspenso TEXT,
  item_ativo TEXT,
  item_sustentavel TEXT,
  caracteristicas TEXT,
  unidades_fornecimento TEXT,
  data_insercao TEXT,
  caracteristicas_ocds TEXT
) ON COMMIT DROP;

INSERT INTO tmp_catalogo_caracteristicas_ocds (
  codigo_classe,
  nome_classe,
  codigo_pdm,
  codigo_item,
  nome_item,
  item_suspenso,
  item_ativo,
  item_sustentavel,
  caracteristicas,
  unidades_fornecimento,
  data_insercao,
  caracteristicas_ocds
)
VALUES
  (
    '6505',
    'DROGAS E MEDICAMENTOS',
    '14597',
    233632,
    'Petrolato, Aspecto Fisico:Liquido, Tipo:Laxativo, Uso:Oral',
    'False',
    'True',
    'False',
    '[]',
    '[{"nomeUnidadeMedida": "Grama", "siglaUnidadeMedida": "G", "capacidadeUnidadeMedida": 10, "nomeUnidadeFornecimento": "Bisnaga", "siglaUnidadeFornecimento": "BIS"}]',
    '2025-03-20T19:57:26Z',
    '[{"nomeCaracteristica": "activeIngredients", "nomeValorCaracteristica": "Petrolato"}, {"nomeCaracteristica": "dosageForm", "nomeValorCaracteristica": "Liquido"}, {"nomeCaracteristica": "administrationRoute", "nomeValorCaracteristica": "Oral"}]'
  ),
  (
    '6505',
    'DROGAS E MEDICAMENTOS',
    '8325',
    260160,
    'Imunoglobulina Humana, Tipo:Hiper Imuni Para Hepatite B, Dosagem:50 Ui/Ml, Apresentacao:Solucao Injetavel',
    'False',
    'True',
    'False',
    '[{"nomeCaracteristica": "Tipo", "nomeValorCaracteristica": "Hiper Imuni Para Hepatite B"}]',
    '[{"nomeUnidadeMedida": "Mililitro", "siglaUnidadeMedida": "ML", "capacidadeUnidadeMedida": 0.5, "nomeUnidadeFornecimento": "Ampola", "siglaUnidadeFornecimento": "AM"}]',
    '2025-03-20T19:57:26Z',
    '[{"nomeCaracteristica": "activeIngredients", "nomeValorCaracteristica": "Imunoglobulina Humana"}, {"nomeCaracteristica": "administrationRoute", "nomeValorCaracteristica": "Solucao Injetavel"}, {"nomeCaracteristica": "strengthValue", "nomeValorCaracteristica": "50"}, {"nomeCaracteristica": "strengthUnit", "nomeValorCaracteristica": "UI/ML"}]'
  );

SELECT
  '03 DATASET DE MAPEAMENTO OCDS' AS etapa,
  codigo_item,
  nome_item,
  caracteristicas_ocds::jsonb AS caracteristicas_ocds
FROM tmp_catalogo_caracteristicas_ocds
ORDER BY codigo_item;

UPDATE catalogo AS c
SET caracteristicas_ocds = NULLIF(btrim(t.caracteristicas_ocds), '')::jsonb
FROM tmp_catalogo_caracteristicas_ocds AS t
WHERE c.codigo_item = t.codigo_item
  AND NULLIF(btrim(t.caracteristicas_ocds), '') IS NOT NULL;

SELECT
  '04 CATALOGO DEPOIS DO UPDATE' AS etapa,
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
  CASE
    WHEN caracteristicas_ocds IS NULL THEN 'sem mapeamento OCDS'
    ELSE 'com mapeamento OCDS'
  END AS status_ocds
FROM catalogo
ORDER BY codigo_item;

SELECT
  COUNT(*) AS total_catalogo,
  COUNT(*) FILTER (WHERE caracteristicas_ocds IS NULL) AS sem_caracteristicas_ocds,
  COUNT(*) FILTER (WHERE caracteristicas_ocds IS NOT NULL) AS com_caracteristicas_ocds
FROM catalogo;

SELECT
  jsonb_typeof(caracteristicas_ocds) AS tipo_jsonb,
  COUNT(*) AS total
FROM catalogo
WHERE caracteristicas_ocds IS NOT NULL
GROUP BY jsonb_typeof(caracteristicas_ocds)
ORDER BY total DESC;

ROLLBACK;
