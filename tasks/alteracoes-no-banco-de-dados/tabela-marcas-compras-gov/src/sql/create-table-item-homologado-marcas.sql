-- Cria a tabela item_homologado_marcas.
--
-- Uso esperado:
-- psql -d medicamentos_transparentes \
--   -f tasks/alteracoes-no-banco-de-dados/tabela-marcas-compras-gov/src/sql/create-table-item-homologado-marcas.sql

\set ON_ERROR_STOP on

BEGIN;

CREATE TABLE IF NOT EXISTS item_homologado_marcas (
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
  ),
  FOREIGN KEY (numero_controle_pncp, numero_item)
    REFERENCES item_homologado (numero_controle_pncp, numero_item)
    ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_item_homologado_marcas_marca
ON item_homologado_marcas (marca);

CREATE INDEX IF NOT EXISTS idx_item_homologado_marcas_id_compra_item
ON item_homologado_marcas (id_compra_item);

COMMENT ON TABLE item_homologado_marcas IS
  'Marcas de itens homologados obtidas via API Compras.gov e relacionadas aos itens homologados do Medicamentos Transparentes.';

COMMENT ON COLUMN item_homologado_marcas.numero_controle_pncp IS
  'Identificador PNCP da contratação. Compõe a chave estrangeira para item_homologado.';

COMMENT ON COLUMN item_homologado_marcas.numero_item IS
  'Número do item no PNCP. Compõe a chave estrangeira para item_homologado.';

COMMENT ON COLUMN item_homologado_marcas.ni_fornecedor IS
  'Número de identificação do fornecedor retornado no fluxo de marcas.';

COMMENT ON COLUMN item_homologado_marcas.codigo_item_catalogo IS
  'Código do item de catálogo usado no item homologado do Medicamentos Transparentes.';

COMMENT ON COLUMN item_homologado_marcas.id_compra IS
  'Identificador da compra no Compras.gov.';

COMMENT ON COLUMN item_homologado_marcas.id_compra_item IS
  'Identificador do item da compra no Compras.gov.';

COMMENT ON COLUMN item_homologado_marcas.codigo_item_catalogo_tbl_itens IS
  'Código do item de catálogo retornado pela consulta de itens do Compras.gov.';

COMMENT ON COLUMN item_homologado_marcas.codigo_item_catalogo_tbl_marcas IS
  'Código do item de catálogo retornado pela consulta de marcas do Compras.gov.';

COMMENT ON COLUMN item_homologado_marcas.quantidade_homologada IS
  'Quantidade homologada usada no pareamento entre PNCP, Compras.gov e marcas.';

COMMENT ON COLUMN item_homologado_marcas.valor_unitario_homologado IS
  'Valor unitário homologado usado no pareamento entre PNCP, Compras.gov e marcas.';

COMMENT ON COLUMN item_homologado_marcas.marca IS
  'Marca observada para o item homologado no Compras.gov.';

COMMENT ON COLUMN item_homologado_marcas.descricao_detalhada_item IS
  'Descrição detalhada do item retornada pelo Compras.gov.';

COMMENT ON COLUMN item_homologado_marcas.sigla_unidade_fornecimento IS
  'Sigla da unidade de fornecimento retornada pelo Compras.gov.';

COMMENT ON COLUMN item_homologado_marcas.nome_unidade_fornecimento IS
  'Nome da unidade de fornecimento retornada pelo Compras.gov.';

COMMENT ON COLUMN item_homologado_marcas.sigla_unidade_medida IS
  'Sigla da unidade de medida retornada pelo Compras.gov.';

COMMENT ON COLUMN item_homologado_marcas.nome_unidade_medida IS
  'Nome da unidade de medida retornada pelo Compras.gov.';

COMMENT ON COLUMN item_homologado_marcas.data_insercao IS
  'Data e hora de inserção do registro na tabela.';

COMMIT;
