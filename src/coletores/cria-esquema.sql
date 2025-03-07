-- Conectar ao banco de dados desejado (caso necessário)
\c medicamentos-transparentes;


-- Criar tabelas dentro do esquema
CREATE TABLE catalogo (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo_classe SMALLINT NOT NULL,
    nome_classe VARCHAR(100) NOT NULL,
    codigo_pdm INTEGER NOT NULL,
    nome_pdm VARCHAR(100) NOT NULL,
    codigo_item INTEGER NOT NULL UNIQUE,
    nome_item VARCHAR(1000) NOT NULL,
    item_suspenso BOOLEAN,
    item_ativo BOOLEAN,
    item_sustentavel BOOLEAN,
    características JSONB NOT NULL,
    unidades_fornecimento JSONB NOT NULL,
    data_insercao TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE contratante (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cnpj CHAR(14) NOT NULL,
    razao_social VARCHAR(1000) NOT NULL,
    esfera CHAR(1),
    poder CHAR(1),
    codigo_unidade VARCHAR(100) NOT NULL,
    nome_unidade VARCHAR(1000) NOT NULL,
    codigo_ibge_municipio INTEGER,
    nome_municipio VARCHAR(100),
    sigla_uf CHAR(2),
    nome_uf VARCHAR(100),
    data_insercao TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE fornecedor (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ni VARCHAR(20) NOT NULL UNIQUE,
    nome VARCHAR(1000) NOT NULL,
    codigo_pais CHAR(3),
    tipo_pessoa CHAR(2),
    codigo_porte SMALLINT,
    nome_porte VARCHAR(100),
    codigo_natureza_juridica VARCHAR(10),
    nome_natureza_juridica VARCHAR(1000),
    data_insercao TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE processo_licitatorio (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo_tipo_instrumento_convocatorio SMALLINT NOT NULL,
    nome_tipo_instrumento_convocatorio VARCHAR(100) NOT NULL,
    codigo_modalidade SMALLINT NOT NULL,
    nome_modalidade VARCHAR(100) NOT NULL,
    codigo_amparo_legal SMALLINT NOT NULL,
    nome_amparo_legal VARCHAR(100) NOT NULL,
    codigo_modo_disputa SMALLINT NOT NULL,
    nome_modo_disputa VARCHAR(100) NOT NULL,
    codigo_criterio_julgamento SMALLINT NOT NULL, 
    nome_criterio_julgamento VARCHAR(100) NOT NULL,
    data_insercao TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE item_homologado (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_catalogo INT REFERENCES catalogo(id) ON DELETE RESTRICT NOT NULL,
    id_contratante INT REFERENCES contratante(id) ON DELETE RESTRICT NOT NULL,
    id_contratante_subrogado INT REFERENCES contratante(id) ON DELETE SET NULL,
    id_fornecedor INT REFERENCES fornecedor(id) ON DELETE RESTRICT NOT NULL,
    id_processo_licitatorio INT REFERENCES processo_licitatorio(id) ON DELETE RESTRICT NOT NULL,
    numero_controle_pncp VARCHAR(30) NOT NULL,
    ano_compra SMALLINT NOT NULL,
    sequencial_compra INTEGER NOT NULL,
    objeto_compra TEXT,
    data_abertura_proposta TIMESTAMP,
    data_encerramento_proposta TIMESTAMP,
    valor_estimado_compra NUMERIC,
    valor_homologado_compra NUMERIC,
    srp BOOLEAN ,
    numero_item INTEGER NOT NULL,
    descricao TEXT,
    unidade_medida VARCHAR(1000),
    material_servico CHAR(1),
    codigo_categoria_item INTEGER,
    nome_categoria_item VARCHAR(1000),
    catalogo VARCHAR(1000),
    categoria_item_catalogo VARCHAR(1000),
    codigo_item_catalogo VARCHAR(1000),
    codigo_ncm_nbs INTEGER,
    descricao_ncm_nbs VARCHAR(1000),
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
    url_api VARCHAR(1000) NOT NULL,
    url_pncp VARCHAR(1000) NOT NULL,
    data_insercao TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


CREATE UNIQUE INDEX idx_unique_cnpj_codigo_unidade 
ON contratante (cnpj, codigo_unidade);

-- Criar indice em catalogo.codigo_br, contratante.cnpj
-- Criar indice em contratante.cnpj, contratante.codigo_unidade
-- Adicionar contraint unique em (contratante.cnpj, contratante.codigo_unidade)
