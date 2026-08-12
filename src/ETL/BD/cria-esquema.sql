-- Conectar ao banco de dados desejado
\c medicamentos-transparentes;

-- Criar tabelas dentro do esquema
CREATE TABLE catalogo (
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
    caracteristicas_ocds JSONB,
    unidades_fornecimento JSONB NOT NULL,
    data_insercao TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON COLUMN catalogo.caracteristicas_ocds IS
    'Atributos técnicos do medicamento mapeados para o padrão OCDS.';

CREATE TABLE contratante (
    cnpj BIGINT,
    razao_social VARCHAR(1000) NOT NULL,
    esfera CHAR(1),
    poder CHAR(1),
    codigo_unidade VARCHAR(100) NOT NULL,
    nome_unidade VARCHAR(1000) NOT NULL,
    codigo_ibge_municipio INTEGER,
    nome_municipio VARCHAR(100),
    sigla_uf CHAR(2),
    nome_uf VARCHAR(100),
    data_insercao TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
    PRIMARY KEY (cnpj, codigo_unidade)
);

CREATE TABLE fornecedor (
    ni VARCHAR(100) PRIMARY KEY,
    nome VARCHAR(1000) NOT NULL,
    codigo_pais CHAR(3),
    tipo_pessoa CHAR(2),
    codigo_porte SMALLINT,
    nome_porte VARCHAR(100),
    codigo_natureza_juridica VARCHAR(10),
    nome_natureza_juridica VARCHAR(1000),
    data_insercao TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE contratacao (
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
    compra_judicial BOOLEAN,
    data_insercao TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON COLUMN contratacao.compra_judicial IS
  'Indica se o objeto da contratação contém possível referência a demanda judicial.';

CREATE TABLE item_homologado (
    numero_controle_pncp VARCHAR(30),
    codigo_item_catalogo INT,
    cnpj_contratante BIGINT,
    codigo_unidade_contratante VARCHAR(100),
    cnpj_contratante_subrogado BIGINT,
    codigo_unidade_contratante_subrogado VARCHAR(100),
    ni_fornecedor VARCHAR(100),
    numero_item INTEGER NOT NULL,
    descricao TEXT,
    unidade_medida VARCHAR(1000),
    material_servico CHAR(1),
    codigo_categoria_item INTEGER,
    nome_categoria_item VARCHAR(1000),
    codigo_catalogo INT,
    nome_catalogo VARCHAR(100),
    codigo_categoria_item_catalogo INT,
    nome_categoria_item_catalogo VARCHAR(1000),
    codigo_item_catalogo_pncp VARCHAR(100),
    codigo_ncm_nbs INTEGER,
    descricao_ncm_nbs VARCHAR(1000),
    codigo_criterio_julgamento SMALLINT NOT NULL, 
    nome_criterio_julgamento VARCHAR(100) NOT NULL,
    codigo_situacao_item INTEGER,
    nome_situacao_item VARCHAR(100),
    codigo_tipo_beneficio SMALLINT,
    nome_tipo_beneficio VARCHAR(100),
    orcamento_sigiloso BOOLEAN,
    valor_unitario_estimado NUMERIC,
    valor_total_estimado NUMERIC,
    quantidade_estimada INTEGER,
    codigo_situacao_resultado SMALLINT,
    nome_situacao_resultado VARCHAR(100),
    valor_unitario_homologado NUMERIC,
    valor_total_homologado NUMERIC,
    quantidade_homologada INTEGER,
    moeda_estrangeira CHAR(3),
    valor_nominal_moeda_estrangeira NUMERIC,
    data_resultado TIMESTAMP,
    data_cancelamento TIMESTAMP,
    motivo_cancelamento VARCHAR(1000),
    aplicacao_beneficio_me_epp BOOLEAN,
    incentivo_produtivo_basico BOOLEAN,
    exigencia_conteudo_nacional BOOLEAN,
    aplicabilidade_margem_preferencia_normal BOOLEAN,
    aplicabilidade_margem_preferencia_adicional BOOLEAN,
    tipo_margem_preferencia_codigo INTEGER,
    tipo_margem_preferencia_nome TEXT,
    percentual_margem_preferencia_normal NUMERIC,
    percentual_margem_preferencia_adicional NUMERIC,
    aplicacao_margem_preferencia BOOLEAN,
    amparo_legal_margem_preferencia_id INTEGER,
    amparo_legal_margem_preferencia_nome TEXT,
    amparo_legal_margem_preferencia_descricao TEXT,
    aplicacao_criterio_desempate BOOLEAN,
    amparo_legal_criterio_desempate_id INTEGER,
    amparo_legal_criterio_desempate_nome TEXT,
    amparo_legal_criterio_desempate_descricao TEXT,
    percentual_desconto NUMERIC,
    url_api VARCHAR(1000) NOT NULL,
    url_pncp VARCHAR(1000) NOT NULL,
    data_insercao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (numero_controle_pncp, numero_item),
    FOREIGN KEY (numero_controle_pncp) REFERENCES contratacao (numero_controle_pncp) ON DELETE RESTRICT,
    FOREIGN KEY (codigo_item_catalogo) REFERENCES catalogo (codigo_item) ON DELETE RESTRICT,
    FOREIGN KEY (cnpj_contratante, codigo_unidade_contratante) REFERENCES contratante (cnpj, codigo_unidade) ON DELETE RESTRICT,
    FOREIGN KEY (cnpj_contratante_subrogado, codigo_unidade_contratante_subrogado) REFERENCES contratante (cnpj, codigo_unidade) ON DELETE SET NULL,
    FOREIGN KEY (ni_fornecedor) REFERENCES fornecedor (ni) ON DELETE RESTRICT
);

COMMENT ON COLUMN item_homologado.aplicacao_beneficio_me_epp IS
  'Indica a aplicacao de beneficio para microempresa ou empresa de pequeno porte no resultado do item.';
COMMENT ON COLUMN item_homologado.incentivo_produtivo_basico IS
  'Indica a aplicacao de incentivo ao processo produtivo basico no item licitado.';
COMMENT ON COLUMN item_homologado.exigencia_conteudo_nacional IS
  'Indica a exigencia de conteudo nacional no item licitado.';
COMMENT ON COLUMN item_homologado.aplicabilidade_margem_preferencia_normal IS
  'Indica a aplicabilidade de margem de preferencia normal no item licitado.';
COMMENT ON COLUMN item_homologado.aplicabilidade_margem_preferencia_adicional IS
  'Indica a aplicabilidade de margem de preferencia adicional no item licitado.';
COMMENT ON COLUMN item_homologado.tipo_margem_preferencia_codigo IS
  'Codigo do tipo de margem de preferencia do item licitado.';
COMMENT ON COLUMN item_homologado.tipo_margem_preferencia_nome IS
  'Nome do tipo de margem de preferencia do item licitado.';
COMMENT ON COLUMN item_homologado.percentual_margem_preferencia_normal IS
  'Percentual da margem de preferencia normal do item licitado.';
COMMENT ON COLUMN item_homologado.percentual_margem_preferencia_adicional IS
  'Percentual da margem de preferencia adicional do item licitado.';
COMMENT ON COLUMN item_homologado.aplicacao_margem_preferencia IS
  'Indica a aplicacao de margem de preferencia no resultado do item.';
COMMENT ON COLUMN item_homologado.amparo_legal_margem_preferencia_id IS
  'Identificador do amparo legal da margem de preferencia aplicada ao resultado do item.';
COMMENT ON COLUMN item_homologado.amparo_legal_margem_preferencia_nome IS
  'Nome do amparo legal da margem de preferencia aplicada ao resultado do item.';
COMMENT ON COLUMN item_homologado.amparo_legal_margem_preferencia_descricao IS
  'Descricao do amparo legal da margem de preferencia aplicada ao resultado do item.';
COMMENT ON COLUMN item_homologado.aplicacao_criterio_desempate IS
  'Indica a aplicacao de criterio de desempate no resultado do item.';
COMMENT ON COLUMN item_homologado.amparo_legal_criterio_desempate_id IS
  'Identificador do amparo legal do criterio de desempate aplicado ao resultado do item.';
COMMENT ON COLUMN item_homologado.amparo_legal_criterio_desempate_nome IS
  'Nome do amparo legal do criterio de desempate aplicado ao resultado do item.';
COMMENT ON COLUMN item_homologado.amparo_legal_criterio_desempate_descricao IS
  'Descricao do amparo legal do criterio de desempate aplicado ao resultado do item.';
COMMENT ON COLUMN item_homologado.percentual_desconto IS
  'Percentual de desconto informado no resultado do item, sem restricao de faixa.';

CREATE TABLE item_licitado (
    numero_controle_pncp VARCHAR(30) NOT NULL,
    codigo_item_catalogo INT NOT NULL,
    cnpj_contratante BIGINT NOT NULL,
    codigo_unidade_contratante VARCHAR(100) NOT NULL,
    cnpj_contratante_subrogado BIGINT,
    codigo_unidade_contratante_subrogado VARCHAR(100),
    numero_item INTEGER NOT NULL,
    descricao TEXT,
    unidade_medida VARCHAR(1000),
    material_servico CHAR(1),
    codigo_categoria_item INTEGER,
    nome_categoria_item VARCHAR(1000),
    codigo_catalogo INT,
    nome_catalogo VARCHAR(100),
    codigo_categoria_item_catalogo INT,
    nome_categoria_item_catalogo VARCHAR(1000),
    codigo_item_catalogo_pncp VARCHAR(100),
    codigo_ncm_nbs INTEGER,
    descricao_ncm_nbs VARCHAR(1000),
    codigo_criterio_julgamento SMALLINT NOT NULL, 
    nome_criterio_julgamento VARCHAR(100) NOT NULL,
    codigo_situacao_item INTEGER,
    nome_situacao_item VARCHAR(100),
    codigo_tipo_beneficio SMALLINT,
    nome_tipo_beneficio VARCHAR(100),
    orcamento_sigiloso BOOLEAN,
    valor_unitario_estimado NUMERIC,
    valor_total_estimado NUMERIC,
    quantidade_estimada INTEGER,
    url_api VARCHAR(1000) NOT NULL,
    url_pncp VARCHAR(1000) NOT NULL,
    data_insercao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (numero_controle_pncp, numero_item)
);
