# Task: `catalogo-caracteristicas-ocds`

## Resumo

Esta task prepara a inclusão e a população da coluna `catalogo.caracteristicas_ocds`, que armazenará os atributos técnicos dos medicamentos mapeados para o padrão OCDS.

A decisão atual é manter essa mudança fora de `src/ETL/BD/cria-esquema.sql` até o fluxo estar consolidado. Primeiro, validamos a alteração em uma task separada, usando o dataset gerado pelo notebook `src/ETL/loaders/docs/tabela-caracteristicas-ocds.ipynb`.

## Arquivos da task

- `input/tabela-mapeamento-ocds.csv`: dataset com os valores OCDS a serem aplicados ao catálogo.
- `test-populacao-sqltools.sql`: simulação segura para rodar no SQLTools.
- `alter-catalogo-caracteristicas-ocds.sql`: script operacional para adicionar a coluna no banco real via `psql`.
- `update-catalogo-caracteristicas-ocds.sql`: script operacional para popular a coluna no banco real via `psql`.

## O que foi testado

Foi criado um teste no SQLTools simulando a tabela `catalogo` com o mesmo schema usado hoje no banco:

```sql
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
);
```

Depois, o teste:

- insere amostras baseadas em `src/ETL/loaders/catmat.csv`;
- mostra o catálogo antes da alteração;
- executa `ALTER TABLE catalogo ADD COLUMN IF NOT EXISTS caracteristicas_ocds JSONB`;
- mostra o catálogo após o `ALTER TABLE`, ainda com `caracteristicas_ocds = NULL`;
- simula o dataset `input/tabela-mapeamento-ocds.csv`;
- executa o `UPDATE` por `codigo_item`;
- mostra o catálogo depois do preenchimento da coluna.

O teste termina com `ROLLBACK`, então não altera nenhuma tabela real.

## Como testar no SQLTools

1. Conecte o SQLTools a qualquer banco PostgreSQL local ou de teste.
2. Abra `tasks/catalogo-caracteristicas-ocds/test-populacao-sqltools.sql`.
3. Execute o arquivo inteiro com `Run on active connection`.
4. Confira os blocos de resultado:

- `01 CATALOGO ANTES DO ALTER TABLE`: catálogo sem a coluna `caracteristicas_ocds`.
- `02 CATALOGO APOS ALTER TABLE, ANTES DO UPDATE`: coluna criada, ainda vazia.
- `03 DATASET DE MAPEAMENTO OCDS`: dados que serão usados para popular a coluna.
- `04 CATALOGO DEPOIS DO UPDATE`: `caracteristicas_ocds` preenchida para os itens mapeados.

Resultado observado no teste: a coluna foi adicionada, o `UPDATE` populou os registros esperados por `codigo_item`, e os valores foram aceitos como `JSONB`.

## Dataset validado

O arquivo `input/tabela-mapeamento-ocds.csv` foi validado localmente com:

- `5771` linhas;
- `0` `codigo_item` duplicado;
- `5771` linhas com `caracteristicas_ocds` preenchida.

Esse formato é compatível com o script operacional, que usa `codigo_item` como chave de atualização e converte `caracteristicas_ocds` para `JSONB`.

## Perspectiva para produção

Para aplicar no banco real, rodar primeiro o `ALTER TABLE`:

```bash
psql -d medicamentos-transparentes \
  -f tasks/catalogo-caracteristicas-ocds/alter-catalogo-caracteristicas-ocds.sql
```

Depois, rodar o `UPDATE` com o CSV:

```bash
psql -d medicamentos-transparentes \
  -v dataset_csv='tasks/catalogo-caracteristicas-ocds/input/tabela-mapeamento-ocds.csv' \
  -f tasks/catalogo-caracteristicas-ocds/update-catalogo-caracteristicas-ocds.sql
```

Os scripts reais:

- adicionam `catalogo.caracteristicas_ocds JSONB` com `ADD COLUMN IF NOT EXISTS`;
- mantém a coluna nullable, sem `DEFAULT`;
- carrega o CSV em tabela temporária;
- atualiza apenas `catalogo.caracteristicas_ocds`;
- preserva `catalogo.características`, `unidades_fornecimento`, chaves e relacionamentos;
- executa dentro de transação;
- mostra contagens finais e tipos `JSONB` preenchidos.

Se algum valor de `caracteristicas_ocds` estiver com JSON inválido, a transação deve falhar antes de deixar uma atualização parcial.

## Pontos de atenção

- Quando o fluxo estiver consolidado, atualizar `src/ETL/BD/cria-esquema.sql` de forma organizada.
