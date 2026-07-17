-- Teste autocontido para PostgreSQL/SQLTools. Nao altera tabelas permanentes.
BEGIN;

CREATE TEMP TABLE item_homologado (
  numero_controle_pncp VARCHAR(30),
  numero_item INTEGER NOT NULL,
  codigo_item_catalogo INTEGER,
  descricao TEXT,
  valor_unitario_homologado NUMERIC,
  quantidade_homologada INTEGER,
  PRIMARY KEY (numero_controle_pncp, numero_item)
);

INSERT INTO item_homologado VALUES
  ('33781055000135-1-000933/2025', 1, 268370, 'Aciclovir', 2.59, 400),
  ('33781055000135-1-000933/2025', 7, 268292, 'Folinato De Cálcio', 2.65, 4070),
  ('00394452000103-1-014637/2025', 1, 271666, 'Aceclofenaco', 0.46, 400),
  ('00394452000103-1-014637/2025', 2, 480350, 'Acetilcisteína', 4.79, 300),
  ('00394452000103-1-014637/2025', 3, 480350, 'Acetilcisteína', 0.82, 300);

SELECT '01 ANTES DO ALTER' AS etapa, * FROM item_homologado ORDER BY numero_controle_pncp, numero_item;

ALTER TABLE item_homologado
  ADD COLUMN aplicabilidade_margem_preferencia_normal TEXT,
  ADD COLUMN percentual_margem_preferencia_normal TEXT,
  ADD COLUMN aplicabilidade_margem_preferencia_adicional TEXT,
  ADD COLUMN percentual_margem_preferencia_adicional TEXT,
  ADD COLUMN tipo_margem_preferencia_codigo TEXT,
  ADD COLUMN tipo_margem_preferencia_nome TEXT,
  ADD COLUMN tipo_margem_preferencia TEXT,
  ADD COLUMN exigencia_conteudo_nacional TEXT;

CREATE TEMP TABLE tmp_item_homologado_margens_csv (
  numero_controle_pncp TEXT,
  numero_item INTEGER,
  aplicabilidade_normal TEXT,
  percentual_normal TEXT,
  aplicabilidade_adicional TEXT,
  percentual_adicional TEXT,
  codigo_tipo TEXT,
  nome_tipo TEXT,
  tipo_margem TEXT,
  exigencia_conteudo TEXT
);

-- Valores reais de itens_homologados_atualizados_com_legado.csv.
INSERT INTO tmp_item_homologado_margens_csv VALUES
  ('33781055000135-1-000933/2025', 1, 'True', '5.0', 'True', '10.0', '2.0', 'Resolução CICS', NULL, 'False'),
  ('33781055000135-1-000933/2025', 7, 'True', '5.0', 'True', '10.0', '2.0', 'Resolução CICS', NULL, 'False'),
  ('00394452000103-1-014637/2025', 1, 'True', '5.0', 'True', '10.0', '2.0', 'Resolução CICS', NULL, 'False'),
  ('00394452000103-1-014637/2025', 2, 'True', '5.0', 'True', '10.0', '2.0', 'Resolução CICS', NULL, 'False'),
  ('00394452000103-1-014637/2025', 3, 'True', '5.0', 'True', '10.0', '2.0', 'Resolução CICS', NULL, 'False');

UPDATE item_homologado AS i
SET aplicabilidade_margem_preferencia_normal = t.aplicabilidade_normal,
    percentual_margem_preferencia_normal = t.percentual_normal,
    aplicabilidade_margem_preferencia_adicional = t.aplicabilidade_adicional,
    percentual_margem_preferencia_adicional = t.percentual_adicional,
    tipo_margem_preferencia_codigo = t.codigo_tipo,
    tipo_margem_preferencia_nome = t.nome_tipo,
    tipo_margem_preferencia = t.tipo_margem,
    exigencia_conteudo_nacional = t.exigencia_conteudo
FROM tmp_item_homologado_margens_csv AS t
WHERE i.numero_controle_pncp = t.numero_controle_pncp
  AND i.numero_item = t.numero_item;

SELECT '02 DEPOIS DO UPDATE' AS etapa, * FROM item_homologado ORDER BY numero_controle_pncp, numero_item;

DO $$
BEGIN
  IF (SELECT COUNT(*) FROM item_homologado) <> 5 THEN
    RAISE EXCEPTION 'O teste alterou a cardinalidade de item_homologado.';
  END IF;
  IF (SELECT COUNT(*) FROM item_homologado WHERE percentual_margem_preferencia_normal = '5.0') <> 5 THEN
    RAISE EXCEPTION 'O UPDATE nao preencheu os cinco registros.';
  END IF;
END;
$$;

ROLLBACK;
