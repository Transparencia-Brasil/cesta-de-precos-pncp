# Banco de dados — Medicamentos Transparentes

Este diretório contém o script SQL que define o schema do banco PostgreSQL utilizado pelo pipeline de dados do projeto **Medicamentos Transparentes**.

O banco é o destino final dos dados coletados da API do PNCP, classificados como medicamentos e carregados pelos scripts R em `src/ETL/loaders/`. Ele serve de base para análises, monitoramento e publicação de preços de medicamentos em compras públicas.

---

## Pré-requisitos

- **PostgreSQL** instalado e acessível (local ou remoto).
- **Pacotes R**: `RPostgres`, `dotenv` — usados pelos loaders para conexão e leitura do `.env`.
- **Arquivo `.env`** na raiz do repositório, com as variáveis de conexão abaixo. Consulte [`.env.example`](../../../.env.example) para o modelo sem segredos:

  ```env
  DB_HOST="..."
  DB_USER="..."
  DB_PASS="..."
  DB_PORT="..."
  ```

> Nunca versione o arquivo `.env` nem exponha credenciais reais em commits, logs ou mensagens.

---

## Criação do schema

Execute os comandos abaixo para criar o banco e aplicar o schema pela primeira vez:

```bash
# Criar o banco de dados
createdb medicamentos-transparentes

# Aplicar o schema (a partir da raiz do repositório)
psql -d medicamentos-transparentes -f src/ETL/BD/cria-esquema.sql
```

> Em ambientes Windows/WSL, ajuste o comando `psql` conforme sua instalação (por exemplo, via `psql.exe`).

O script `cria-esquema.sql` já inclui a diretiva `\c medicamentos-transparentes` para garantir a conexão ao banco correto antes de criar as tabelas.

---

## Dependências entre tabelas

As seis tabelas do schema possuem a seguinte estrutura de dependências (ordem de criação e chaves estrangeiras):

```txt
catalogo         ─────────────────────────────┐
contratante (contratante + sub-rogado) ────────┤──▶ item_homologado
fornecedor       ─────────────────────────────┤
contratacao      ─────────────────────────────┘

item_licitado    (sem FK para fornecedor — independente de fornecedor)
```

`item_homologado` é a tabela mais dependente: referencia `contratacao`, `catalogo`, `contratante` (duas vezes — contratante principal e sub-rogado) e `fornecedor`. Todas as FKs usam `ON DELETE RESTRICT`, impedindo remoção de registros referenciados.

`item_licitado` registra itens ainda sem resultado de adjudicação e não possui FK para `fornecedor`.

---

## Descrição detalhada das tabelas

### `catalogo`

Armazena o catálogo CATMAT de medicamentos. Populada pelo loader [`carrega-catalogo.R`](../loaders/carrega-catalogo.R).

| Coluna | Tipo | Restrição | Descrição |
| --- | --- | --- | --- |
| `codigo_classe` | SMALLINT | NOT NULL | Código da classe CATMAT |
| `nome_classe` | VARCHAR(100) | NOT NULL | Nome da classe CATMAT |
| `codigo_pdm` | INTEGER | NOT NULL | Código do PDM (Padrão Descritivo de Material) |
| `nome_pdm` | VARCHAR(100) | NOT NULL | Nome do PDM |
| `codigo_item` | INTEGER | **PK** | Código único do item no catálogo |
| `nome_item` | VARCHAR(1000) | NOT NULL | Descrição completa do item |
| `item_suspenso` | BOOLEAN | — | Indica se o item está suspenso |
| `item_ativo` | BOOLEAN | — | Indica se o item está ativo |
| `item_sustentavel` | BOOLEAN | — | Indica critério de sustentabilidade |
| `características` | **JSONB** | NOT NULL | Atributos técnicos do medicamento (estrutura variável por PDM) |
| `unidades_fornecimento` | **JSONB** | NOT NULL | Unidades de fornecimento aceitas |
| `data_insercao` | TIMESTAMP | DEFAULT NOW() | Timestamp automático de carga |

**Comportamento em conflito:** `ON CONFLICT (codigo_item) DO NOTHING` — inserções duplicadas são ignoradas. Para atualizar o catálogo, o loader usa uma consulta de `DO UPDATE` separada.

---

### `contratante`

Órgãos e entidades públicas que realizam as contratações. Um mesmo CNPJ pode ter múltiplas unidades gestoras (`codigo_unidade`).

| Coluna | Tipo | Restrição | Descrição |
| --- | --- | --- | --- |
| `cnpj` | BIGINT | **PK (parcial)** | CNPJ do órgão contratante |
| `razao_social` | VARCHAR(1000) | NOT NULL | Nome do órgão |
| `esfera` | CHAR(1) | — | F (federal), E (estadual), M (municipal) |
| `poder` | CHAR(1) | — | E (executivo), L (legislativo), J (judiciário) |
| `codigo_unidade` | VARCHAR(100) | **PK (parcial)** | Código da unidade gestora |
| `nome_unidade` | VARCHAR(1000) | NOT NULL | Nome da unidade gestora |
| `codigo_ibge_municipio` | INTEGER | — | Código IBGE do município |
| `nome_municipio` | VARCHAR(100) | — | Nome do município |
| `sigla_uf` | CHAR(2) | — | Sigla do estado |
| `nome_uf` | VARCHAR(100) | — | Nome do estado |
| `data_insercao` | TIMESTAMP | DEFAULT NOW() | Timestamp automático de carga |

**PK composta:** `(cnpj, codigo_unidade)`.
**Comportamento em conflito:** `ON CONFLICT (cnpj, codigo_unidade) DO NOTHING`.

> A tabela também serve como destino da FK de **contratante sub-rogado** em `item_homologado` e `item_licitado`. O sub-rogado é o órgão que assume a contratação em nome de outro (SRP/ata de registro de preços).

---

### `fornecedor`

Empresas ou pessoas físicas fornecedoras de medicamentos nas licitações homologadas.

| Coluna | Tipo | Restrição | Descrição |
| --- | --- | --- | --- |
| `ni` | VARCHAR(100) | **PK** | Número identificador (CNPJ ou CPF) |
| `nome` | VARCHAR(1000) | NOT NULL | Razão social ou nome |
| `codigo_pais` | CHAR(3) | — | Código ISO do país |
| `tipo_pessoa` | CHAR(2) | — | PF (pessoa física), PJ (jurídica) |
| `codigo_porte` | SMALLINT | — | Código do porte da empresa |
| `nome_porte` | VARCHAR(100) | — | Descrição do porte (ME, EPP, grande empresa) |
| `codigo_natureza_juridica` | VARCHAR(10) | — | Código da natureza jurídica |
| `nome_natureza_juridica` | VARCHAR(1000) | — | Descrição da natureza jurídica |
| `data_insercao` | TIMESTAMP | DEFAULT NOW() | Timestamp automático de carga |

**Comportamento em conflito:** `ON CONFLICT (ni) DO NOTHING`.

---

### `contratacao`

Compras públicas registradas no PNCP. Cada registro corresponde a um processo licitatório completo.

| Coluna | Tipo | Restrição | Descrição |
| --- | --- | --- | --- |
| `numero_controle_pncp` | VARCHAR(30) | **PK** | Identificador único da compra no PNCP |
| `ano_compra` | SMALLINT | NOT NULL | Ano do processo |
| `sequencial_compra` | INTEGER | NOT NULL | Sequencial dentro do ano/órgão |
| `objeto_compra` | TEXT | — | Descrição do objeto licitado |
| `data_abertura_proposta` | TIMESTAMP | — | Data de abertura das propostas |
| `data_encerramento_proposta` | TIMESTAMP | — | Data de encerramento das propostas |
| `valor_estimado_compra` | NUMERIC | — | Valor total estimado da compra |
| `valor_homologado_compra` | NUMERIC | — | Valor total homologado |
| `srp` | BOOLEAN | — | Indica se é Sistema de Registro de Preços |
| `codigo_tipo_instrumento_convocatorio` | SMALLINT | NOT NULL | Código do instrumento (edital, aviso, etc.) |
| `nome_tipo_instrumento_convocatorio` | VARCHAR(100) | NOT NULL | Descrição do instrumento |
| `codigo_modalidade` | SMALLINT | NOT NULL | Código da modalidade licitatória |
| `nome_modalidade` | VARCHAR(100) | NOT NULL | Descrição da modalidade (pregão, concorrência, etc.) |
| `codigo_amparo_legal` | SMALLINT | NOT NULL | Código do amparo legal |
| `nome_amparo_legal` | VARCHAR(100) | NOT NULL | Descrição do amparo legal (Lei 14.133/2021, etc.) |
| `codigo_modo_disputa` | SMALLINT | NOT NULL | Código do modo de disputa |
| `nome_modo_disputa` | VARCHAR(100) | NOT NULL | Descrição do modo de disputa (aberto, fechado, etc.) |
| `data_insercao` | TIMESTAMP | DEFAULT NOW() | Timestamp automático de carga |

**Comportamento em conflito:** `ON CONFLICT (numero_controle_pncp) DO UPDATE` — atualiza todos os campos de valor, data e modalidade com os dados mais recentes.

---

### `item_homologado`

Itens de medicamentos que já receberam resultado de adjudicação ou cancelamento. É a tabela central para análise de preços e fornecedores.

| Coluna | Tipo | Restrição | Descrição |
| --- | --- | --- | --- |
| `numero_controle_pncp` | VARCHAR(30) | **PK (parcial)**, FK → `contratacao` | Compra de origem |
| `numero_item` | INTEGER | **PK (parcial)** | Número do item na compra |
| `codigo_item_catalogo` | INT | FK → `catalogo` | Código CATMAT do medicamento |
| `cnpj_contratante` | BIGINT | FK → `contratante` | CNPJ do contratante principal |
| `codigo_unidade_contratante` | VARCHAR(100) | FK → `contratante` | Unidade gestora contratante |
| `cnpj_contratante_subrogado` | BIGINT | FK → `contratante` (nullable) | CNPJ do sub-rogado (quando SRP) |
| `codigo_unidade_contratante_subrogado` | VARCHAR(100) | FK → `contratante` (nullable) | Unidade do sub-rogado |
| `ni_fornecedor` | VARCHAR(100) | FK → `fornecedor` | Identificador do fornecedor vencedor |
| `descricao` | TEXT | — | Descrição do item conforme licitação |
| `unidade_medida` | VARCHAR(1000) | — | Unidade de medida |
| `material_servico` | CHAR(1) | — | M (material) ou S (serviço) |
| `codigo_categoria_item` | INTEGER | — | Categoria do item no PNCP |
| `nome_categoria_item` | VARCHAR(1000) | — | Descrição da categoria |
| `codigo_catalogo` | INT | — | Código do catálogo de referência |
| `nome_catalogo` | VARCHAR(100) | — | Nome do catálogo (ex.: CATMAT) |
| `codigo_item_catalogo_pncp` | VARCHAR(100) | — | Código do item no PNCP |
| `codigo_ncm_nbs` | INTEGER | — | Código NCM/NBS |
| `descricao_ncm_nbs` | VARCHAR(1000) | — | Descrição NCM/NBS |
| `codigo_criterio_julgamento` | SMALLINT | NOT NULL | Código do critério de julgamento |
| `nome_criterio_julgamento` | VARCHAR(100) | NOT NULL | Menor preço, melhor técnica, etc. |
| `codigo_situacao_item` | INTEGER | — | Código da situação do item |
| `nome_situacao_item` | VARCHAR(100) | — | Descrição da situação |
| `codigo_tipo_beneficio` | SMALLINT | — | Tipo de benefício (ME/EPP, etc.) |
| `nome_tipo_beneficio` | VARCHAR(100) | — | Descrição do benefício |
| `orcamento_sigiloso` | BOOLEAN | — | Indica orçamento sigiloso |
| `valor_unitario_estimado` | NUMERIC | — | Valor unitário estimado |
| `valor_total_estimado` | NUMERIC | — | Valor total estimado |
| `quantidade_estimada` | INTEGER | — | Quantidade estimada |
| `codigo_situacao_resultado` | SMALLINT | — | Código do resultado (homologado, cancelado, etc.) |
| `nome_situacao_resultado` | VARCHAR(100) | — | Descrição do resultado |
| `valor_unitario_homologado` | NUMERIC | — | **Preço unitário final homologado** |
| `valor_total_homologado` | NUMERIC | — | Valor total homologado |
| `quantidade_homologada` | INTEGER | — | Quantidade efetivamente homologada |
| `moeda_estrangeira` | CHAR(3) | — | Código ISO da moeda estrangeira (quando aplicável) |
| `valor_nominal_moeda_estrangeira` | NUMERIC | — | Valor em moeda estrangeira |
| `data_resultado` | TIMESTAMP | — | Data do resultado |
| `data_cancelamento` | TIMESTAMP | — | Data de cancelamento (quando aplicável) |
| `motivo_cancelamento` | VARCHAR(1000) | — | Descrição do motivo de cancelamento |
| `url_api` | VARCHAR(1000) | NOT NULL | URL do endpoint da API PNCP (rastreabilidade) |
| `url_pncp` | VARCHAR(1000) | NOT NULL | URL pública no portal PNCP (rastreabilidade) |
| `data_insercao` | TIMESTAMP | DEFAULT NOW() | Timestamp automático de carga |

**PK composta:** `(numero_controle_pncp, numero_item)`.
**Chaves estrangeiras:** todas com `ON DELETE RESTRICT`.
**Comportamento em conflito:** `ON CONFLICT DO UPDATE` — atualiza todos os campos de resultado e valor.

---

### `item_licitado`

Itens de medicamentos ainda sem resultado de adjudicação. Possui o mesmo conjunto de colunas descritivas de `item_homologado`, sem as colunas de resultado.

Colunas presentes (subconjunto de `item_homologado`): `numero_controle_pncp`, `numero_item`, `codigo_item_catalogo`, `cnpj_contratante`, `codigo_unidade_contratante`, `cnpj_contratante_subrogado`, `codigo_unidade_contratante_subrogado`, `descricao`, `unidade_medida`, `material_servico`, campos de categoria e catálogo, NCM/NBS, critério de julgamento, situação do item, tipo de benefício, `orcamento_sigiloso`, valores e quantidades estimadas, `url_api`, `url_pncp`, `data_insercao`.

**Colunas ausentes em relação a `item_homologado`:** `ni_fornecedor` e todos os campos de resultado (`codigo_situacao_resultado`, `valor_unitario_homologado`, `valor_total_homologado`, `quantidade_homologada`, `moeda_estrangeira`, `valor_nominal_moeda_estrangeira`, `data_resultado`, `data_cancelamento`, `motivo_cancelamento`).

**PK composta:** `(numero_controle_pncp, numero_item)`.
**Sem FK para `fornecedor`** — o fornecedor só é registrado após adjudicação.
**Comportamento em conflito:** `ON CONFLICT DO UPDATE` — atualiza campos descritivos e estimados.

---

## Carga de dados

Os loaders em [`src/ETL/loaders/`](../loaders/) são responsáveis por popular o banco após cada coleta:

| Loader | Tabelas afetadas | Fonte de dados |
| --- | --- | --- |
| [`carrega-catalogo.R`](../loaders/carrega-catalogo.R) | `catalogo` | `data/catmat/catmat.rds` |
| [`carrega-dados.R`](../loaders/carrega-dados.R) | `contratante`, `fornecedor`, `contratacao`, `item_homologado`, `item_licitado` | CSVs em `coleta/<periodo>/` |

A ordem de inserção dentro de `carrega-dados.R` respeita as dependências de FK:

```txt
1. contratante  (+ sub-rogados)
2. fornecedor
3. contratacao
4. item_homologado
5. item_licitado
```

As queries SQL parametrizadas ficam centralizadas em [`src/ETL/loaders/utils.R`](../loaders/utils.R), que também expõe a função `conecta_bd_medicamentos_transparentes()` para leitura das variáveis do `.env`.

---

## Reprodutibilidade e boas práticas

- **Idempotência:** todas as inserções usam `ON CONFLICT`, tornando seguro reexecutar os loaders sobre os mesmos dados sem gerar duplicatas ou erros.
- **Rastreabilidade:** as colunas `url_api` e `url_pncp` em `item_homologado` e `item_licitado` permitem rastrear cada item até sua origem na API e no portal PNCP. A coluna `data_insercao` (com `DEFAULT CURRENT_TIMESTAMP`) registra o momento da carga.
- **Integridade referencial:** as FKs com `ON DELETE RESTRICT` em `item_homologado` impedem remoção acidental de registros-pai enquanto houver itens associados.
- **Credenciais:** mantenha o arquivo `.env` fora do repositório (já coberto pelo `.gitignore`). Nunca substitua variáveis de ambiente por valores literais no código.
- **Recriação do schema:** em ambiente de desenvolvimento, para recriar o schema do zero, remova as tabelas na ordem inversa das dependências (`item_homologado`, `item_licitado`, depois as tabelas-pai) antes de reaplicar `cria-esquema.sql`.
- **Backup:** antes de qualquer migração ou alteração de schema em produção, faça backup com `pg_dump`:

  ```bash
  pg_dump medicamentos-transparentes > backup_$(date +%Y%m%d).sql
  ```
