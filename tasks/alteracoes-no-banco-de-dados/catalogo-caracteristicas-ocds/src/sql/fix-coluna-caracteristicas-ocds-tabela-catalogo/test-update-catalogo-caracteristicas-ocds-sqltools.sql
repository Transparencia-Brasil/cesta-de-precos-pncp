-- Simulacao da correcao de catalogo.caracteristicas_ocds para rodar no SQLTools.
--
-- Este script nao usa \copy, nao altera tabelas reais e termina com ROLLBACK.
-- Ele simula uma catalogo ja populada com valores do dataset antigo
-- outputs/tabela-mapeamento-ocds-old.csv e aplica o update com amostras do
-- dataset corrigido outputs/tabela-mapeamento-ocds.csv.
--
-- Nao ha ALTER TABLE neste teste: a coluna caracteristicas_ocds ja existe.

BEGIN;

CREATE TEMP TABLE catalogo (
  codigo_item INTEGER PRIMARY KEY,
  nome_item TEXT NOT NULL,
  caracteristicas_ocds JSONB
) ON COMMIT DROP;

CREATE TEMP TABLE tmp_catalogo_caracteristicas_ocds_antigas (
  codigo_item INTEGER PRIMARY KEY,
  nome_item TEXT NOT NULL,
  caracteristicas_ocds TEXT
) ON COMMIT DROP;

INSERT INTO tmp_catalogo_caracteristicas_ocds_antigas (
  codigo_item,
  nome_item,
  caracteristicas_ocds
)
VALUES
  (
    233632,
    'Petrolato, Aspecto Fisico:Liquido, Tipo:Laxativo, Uso:Oral',
    $$[{"nomeCaracteristica": "activeIngredients", "nomeValorCaracteristica": "Petrolato"}, {"nomeCaracteristica": "dosageForm", "nomeValorCaracteristica": "Liquido"}, {"nomeCaracteristica": "administrationRoute", "nomeValorCaracteristica": "Oral"}]$$
  ),
  (
    260160,
    'Imunoglobulina Humana, Tipo:Hiper Imuni Para Hepatite B, Dosagem:50 Ui/Ml, Apresentacao:Solucao Injetavel',
    $$[{"nomeCaracteristica": "activeIngredients", "nomeValorCaracteristica": "Imunoglobulina Humana"}, {"nomeCaracteristica": "administrationRoute", "nomeValorCaracteristica": "Solucao Injetavel"}, {"nomeCaracteristica": "strengthValue", "nomeValorCaracteristica": "50"}, {"nomeCaracteristica": "strengthUnit", "nomeValorCaracteristica": "UI/ML"}]$$
  ),
  (
    266532,
    'Fenoterol Bromidrato, Dosagem:0,2mg / Dose, Apresentacao:Aerossol, Frasco Dosificador + Aerocamara',
    $$[{"nomeCaracteristica": "activeIngredients", "nomeValorCaracteristica": "Fenoterol Bromidrato"}, {"nomeCaracteristica": "dosageForm", "nomeValorCaracteristica": "Aerossol, Frasco Dosificador + Aerocamara"}, {"nomeCaracteristica": "strengthValue", "nomeValorCaracteristica": "0,2"}, {"nomeCaracteristica": "strengthUnit", "nomeValorCaracteristica": "MG"}, {"nomeCaracteristica": "immediateContainer", "nomeValorCaracteristica": "frasco dosificador aerocamara"}]$$
  ),
  (
    266699,
    'Budesonida, Apresentacao:Aerossol Bucal, Concentracao:50mcg/Dose, Caracteristicas Adicionais:Frasco Com Valvula Dosificadora',
    $$[{"nomeCaracteristica": "activeIngredients", "nomeValorCaracteristica": "Budesonida"}, {"nomeCaracteristica": "administrationRoute", "nomeValorCaracteristica": "Aerossol Bucal"}, {"nomeCaracteristica": "strengthValue", "nomeValorCaracteristica": "50"}, {"nomeCaracteristica": "strengthUnit", "nomeValorCaracteristica": "MCG"}, {"nomeCaracteristica": "immediateContainer", "nomeValorCaracteristica": "frasco com valvula dosificadora"}]$$
  ),
  (
    267087,
    'Genfibrozila, Dosagem:900 MG',
    $$[{"nomeCaracteristica": "activeIngredients", "nomeValorCaracteristica": "Genfibrozila"}, {"nomeCaracteristica": "strengthValue", "nomeValorCaracteristica": "900"}, {"nomeCaracteristica": "strengthUnit", "nomeValorCaracteristica": "MG"}]$$
  );

INSERT INTO catalogo (
  codigo_item,
  nome_item,
  caracteristicas_ocds
)
SELECT
  codigo_item,
  nome_item,
  caracteristicas_ocds::jsonb
FROM tmp_catalogo_caracteristicas_ocds_antigas;

SELECT
  '01 CATALOGO COM VALORES DO DATASET ANTIGO' AS etapa,
  codigo_item,
  nome_item,
  caracteristicas_ocds
FROM catalogo
ORDER BY codigo_item;

CREATE TEMP TABLE tmp_catalogo_caracteristicas_ocds_corrigidas (
  codigo_item INTEGER PRIMARY KEY,
  caracteristicas_ocds TEXT
) ON COMMIT DROP;

INSERT INTO tmp_catalogo_caracteristicas_ocds_corrigidas (
  codigo_item,
  caracteristicas_ocds
)
VALUES
  (
    233632,
    $$[{"nomeCaracteristica":["dosageForm"],"nomeValorCaracteristica":["Liquido"]},{"nomeCaracteristica":["administrationRoute"],"nomeValorCaracteristica":["Oral"]},{"nomeCaracteristica":["activeIngredients"],"nomeValorCaracteristica":["Petrolato"]}]$$
  ),
  (
    260160,
    $$[{"nomeCaracteristica":["administrationRoute"],"nomeValorCaracteristica":["Solucao Injetavel"]},{"nomeCaracteristica":["activeIngredients"],"nomeValorCaracteristica":["Imunoglobulina Humana"]},{"nomeCaracteristica":["strength"],"nomeValorCaracteristica":["50 UI/ML"]}]$$
  ),
  (
    266532,
    $$[{"nomeCaracteristica":["dosageForm"],"nomeValorCaracteristica":["Aerossol Frasco Dosificador Aerocamara"]},{"nomeCaracteristica":["activeIngredients"],"nomeValorCaracteristica":["Fenoterol Bromidrato"]},{"nomeCaracteristica":["strength"],"nomeValorCaracteristica":["0.2 MG"]}]$$
  ),
  (
    266699,
    $$[{"nomeCaracteristica":["administrationRoute"],"nomeValorCaracteristica":["Aerossol Bucal"]},{"nomeCaracteristica":["activeIngredients"],"nomeValorCaracteristica":["Budesonida"]},{"nomeCaracteristica":["strength"],"nomeValorCaracteristica":["50 MCG"]}]$$
  ),
  (
    267087,
    $$[{"nomeCaracteristica":["activeIngredients"],"nomeValorCaracteristica":["Genfibrozila"]},{"nomeCaracteristica":["strength"],"nomeValorCaracteristica":["900 MG"]}]$$
  );

SELECT
  '02 DATASET CORRIGIDO PARA UPDATE' AS etapa,
  codigo_item,
  caracteristicas_ocds::jsonb AS caracteristicas_ocds
FROM tmp_catalogo_caracteristicas_ocds_corrigidas
ORDER BY codigo_item;

WITH mapeamento AS (
  SELECT
    codigo_item,
    NULLIF(btrim(caracteristicas_ocds), '')::jsonb AS caracteristicas_ocds
  FROM tmp_catalogo_caracteristicas_ocds_corrigidas
  WHERE NULLIF(btrim(caracteristicas_ocds), '') IS NOT NULL
),
atualizados AS (
  UPDATE catalogo AS c
  SET caracteristicas_ocds = m.caracteristicas_ocds
  FROM mapeamento AS m
  WHERE c.codigo_item = m.codigo_item
    AND c.caracteristicas_ocds IS DISTINCT FROM m.caracteristicas_ocds
  RETURNING c.codigo_item
)
SELECT
  '03 LINHAS ATUALIZADAS' AS etapa,
  COUNT(*) AS total_linhas_atualizadas
FROM atualizados;

SELECT
  '04 CATALOGO DEPOIS DO UPDATE' AS etapa,
  codigo_item,
  nome_item,
  caracteristicas_ocds
FROM catalogo
ORDER BY codigo_item;

SELECT
  '05 CONFERENCIA COM DATASET CORRIGIDO' AS etapa,
  c.codigo_item,
  c.caracteristicas_ocds = t.caracteristicas_ocds::jsonb AS atualizado_com_valor_esperado
FROM catalogo AS c
JOIN tmp_catalogo_caracteristicas_ocds_corrigidas AS t
  ON t.codigo_item = c.codigo_item
ORDER BY c.codigo_item;

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
