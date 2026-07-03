# Fix da coluna `catalogo.caracteristicas_ocds`

Esta pasta documenta e concentra a correção da população da coluna
`catalogo.caracteristicas_ocds`.

A coluna já foi criada anteriormente pela task
`tasks/alteracoes-no-banco-de-dados/catalogo-caracteristicas-ocds/`. Esta
correção não executa `ALTER TABLE`: ela apenas repopula a coluna com os dados
atualizados do dataset `outputs/tabela-mapeamento-ocds.csv`.

## Contexto

A primeira população de `catalogo.caracteristicas_ocds` usou o dataset antigo:

- `tasks/alteracoes-no-banco-de-dados/catalogo-caracteristicas-ocds/outputs/tabela-mapeamento-ocds-old.csv`

Depois, o mapeamento OCDS foi ajustado e passou a ser representado pelo dataset
corrigido:

- `tasks/alteracoes-no-banco-de-dados/catalogo-caracteristicas-ocds/outputs/tabela-mapeamento-ocds.csv`

O objetivo desta correção é atualizar os valores de `catalogo.caracteristicas_ocds`
no banco real usando o dataset novo como fonte de verdade.

## Arquivos criados

- `update-catalogo-caracteristicas-ocds.sql`: script operacional para atualizar
  a tabela real `catalogo`.
- `test-update-catalogo-caracteristicas-ocds-sqltools.sql`: teste transacional
  para rodar no SQLTools, sem alterar tabelas reais.

## Teste no SQLTools

O teste simula o fluxo completo em tabelas temporárias:

1. Cria uma tabela temporária `catalogo` com a coluna `caracteristicas_ocds`.
2. Cria uma tabela temporária com 5 amostras do dataset antigo.
3. Popula `catalogo.caracteristicas_ocds` com esses valores antigos.
4. Cria uma tabela temporária com 5 amostras do dataset corrigido.
5. Executa o mesmo padrão de `UPDATE` usado no script operacional.
6. Compara se o valor final da `catalogo` ficou igual ao dataset corrigido.
7. Termina com `ROLLBACK`.

Arquivo:

```text
tasks/alteracoes-no-banco-de-dados/catalogo-caracteristicas-ocds/src/sql/fix-coluna-caracteristicas-ocds-tabela-catalogo/test-update-catalogo-caracteristicas-ocds-sqltools.sql
```

## Update operacional

O script operacional espera receber o caminho do CSV corrigido via variável
`dataset_csv` do `psql`.

Exemplo:

```bash
psql -d medicamentos-transparentes \
  -v dataset_csv='tasks/alteracoes-no-banco-de-dados/catalogo-caracteristicas-ocds/outputs/tabela-mapeamento-ocds.csv' \
  -f tasks/alteracoes-no-banco-de-dados/catalogo-caracteristicas-ocds/src/sql/fix-coluna-caracteristicas-ocds-tabela-catalogo/update-catalogo-caracteristicas-ocds.sql
```

O CSV esperado deve conter as colunas:

```text
codigo_item,caracteristicas_ocds
```

## Explicação do trecho principal

O trecho principal do update é:

```sql
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
  RETURNING c.codigo_item
)
```

### `mapeamento`

- `mapeamento` monta uma lista limpa dos dados novos vindos do CSV corrigido.

Ela:

- pega `codigo_item` como chave de atualização;
- remove espaços antes e depois de `caracteristicas_ocds` com `btrim`;
- transforma string vazia em `NULL` com `NULLIF`;
- descarta linhas sem valor em `caracteristicas_ocds`;
- converte o texto final para `jsonb`.

Em outras palavras: ela pega apenas os mapeamentos novos válidos e transforma
`caracteristicas_ocds` em JSONB antes do update.

### `atualizados`

- aplica a correção na tabela real `catalogo`.

Ela:

- encontra o item da `catalogo` pelo mesmo `codigo_item` do CSV;
- repopula `catalogo.caracteristicas_ocds` com o valor corrigido do dataset novo;
- retorna os `codigo_item` que foram atualizados.

O `WHERE` faz apenas o pareamento pela chave do catálogo:

```sql
WHERE c.codigo_item = m.codigo_item
```

Essa decisão foi tomada porque a correção do mapeamento OCDS mudou praticamente
todo o dataset, principalmente pela unificação de `strengthValue` e
`strengthUnit` em uma única característica `strength`.

Exemplo do formato antigo:

```json
[
  {"nomeCaracteristica": "activeIngredients", "nomeValorCaracteristica": "Genfibrozila"},
  {"nomeCaracteristica": "strengthValue", "nomeValorCaracteristica": "900"},
  {"nomeCaracteristica": "strengthUnit", "nomeValorCaracteristica": "MG"}
]
```

Exemplo do formato corrigido:

```json
[
  {"nomeCaracteristica": ["activeIngredients"], "nomeValorCaracteristica": ["Genfibrozila"]},
  {"nomeCaracteristica": ["strength"], "nomeValorCaracteristica": ["900 MG"]}
]
```

Como o CSV corrigido passa a ser a fonte de verdade, o script atualiza todos os
itens encontrados no dataset novo. Isso deixa a operação mais direta: a coluna
`catalogo.caracteristicas_ocds` passa a refletir integralmente o mapeamento OCDS
corrigido.

## Resultado esperado

Ao final do script operacional, o banco deve exibir:

- total de linhas repopuladas a partir do dataset corrigido;
- quantidade de itens da `catalogo` com e sem `caracteristicas_ocds`;
- tipos JSONB presentes na coluna preenchida.

O script roda dentro de transação com `ON_ERROR_STOP`, então erros de leitura do
CSV ou JSON inválido interrompem a execução antes de deixar uma atualização
parcial confirmada.
