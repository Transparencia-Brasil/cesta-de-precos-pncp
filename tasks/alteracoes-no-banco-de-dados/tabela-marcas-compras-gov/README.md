# Task: `tabela-marcas-compras-gov`

## Resumo

Esta task prepara a criação e a carga da tabela `item_homologado_marcas`, que relaciona itens homologados do Medicamentos Transparentes às marcas coletadas na API Compras.gov.

O fluxo fica isolado em `tasks/alteracoes-no-banco-de-dados/` e não altera `src/ETL/`. O CSV canônico de entrada é `tasks/api-compras/outputs/tabela-marcas.csv`.

## Arquivos da task

- `docs/marcas.ipynb`: notebook de exploração do CSV, do join temporário com `item_homologado` e da classificação incremental.
- `src/sql/test-item-homologado-marcas.sql`: simulação segura para rodar no SQLTools.
- `src/sql/create-table-item-homologado-marcas.sql`: script operacional para criar a tabela no banco real via `psql`.
- `src/sql/update-item-homologado-marcas.sql`: script operacional para carregar incrementalmente a tabela a partir do CSV via `psql`.

## Modelo da tabela

A tabela `item_homologado_marcas` mantém as 16 colunas de `tabela-marcas.csv` e adiciona `data_insercao`.

A chave primária é natural e permite múltiplas marcas para o mesmo item homologado:

```sql
PRIMARY KEY (
  numero_controle_pncp,
  numero_item,
  ni_fornecedor,
  id_compra_item,
  marca
)
```

A tabela referencia `item_homologado(numero_controle_pncp, numero_item)`. Os identificadores do Compras.gov (`id_compra` e `id_compra_item`) são tratados como texto, porque podem ultrapassar a faixa segura de inteiros convencionais.

## Como testar no SQLTools

O arquivo `src/sql/test-item-homologado-marcas.sql` simula o fluxo incremental usando tabelas temporárias:

1. cria uma amostra mínima de `item_homologado`;
2. simula uma tabela `item_homologado_marcas` já populada;
3. simula linhas do CSV, incluindo duplicata exata e múltiplas marcas para um mesmo item;
4. deduplica linhas exatamente iguais no lote;
5. normaliza `NA` e vazios para `NULL` em colunas auxiliares;
6. insere apenas marcas novas com `ON CONFLICT DO NOTHING`;
7. faz join com a tabela temporária de itens homologados;
8. executa validações com `RAISE EXCEPTION`;
9. termina com `ROLLBACK`.

Para testar, conecte o SQLTools a um banco PostgreSQL, abra o arquivo e execute todo o script com `Run on active connection`. Nenhuma tabela real é alterada.

## Como aplicar no banco

Execute primeiro o script de criação, a partir da raiz do repositório, em um
terminal Bash/WSL com o cliente `psql` disponível:

```bash
(
  set -a
  source <(sed 's/\r$//' .env)
  set +a

  export PGHOST="$DB_HOST"
  export PGPORT="$DB_PORT"
  export PGUSER="$DB_USER"
  export PGPASSWORD="$DB_PASS"
  export PGDATABASE="medicamentos_transparentes"

  psql -f tasks/alteracoes-no-banco-de-dados/tabela-marcas-compras-gov/src/sql/create-table-item-homologado-marcas.sql
)
```

Depois, execute a carga incremental:

```bash
(
  set -a
  source <(sed 's/\r$//' .env)
  set +a

  export PGHOST="$DB_HOST"
  export PGPORT="$DB_PORT"
  export PGUSER="$DB_USER"
  export PGPASSWORD="$DB_PASS"
  export PGDATABASE="medicamentos_transparentes"

  dataset_csv="$PWD/tasks/api-compras/outputs/tabela-marcas.csv"

  psql -f <(
    sed "s|FROM :'dataset_csv'|FROM '$dataset_csv'|" \
      tasks/alteracoes-no-banco-de-dados/tabela-marcas-compras-gov/src/sql/update-item-homologado-marcas.sql
  )
)
```

O subshell evita que credenciais exportadas permaneçam no ambiente do terminal. O arquivo `.env` deve conter `DB_HOST`, `DB_PORT`, `DB_USER` e `DB_PASS`; não imprima nem copie esses valores para logs, documentação ou commits.

## Validações do update

O script `update-item-homologado-marcas.sql` executa a carga em transação e:

- carrega o CSV em uma tabela temporária textual;
- valida campos obrigatórios;
- valida casts numéricos;
- converte `NA` e campos vazios para `NULL` nas colunas auxiliares;
- deduplica linhas exatamente iguais no lote;
- rejeita chaves naturais repetidas com valores divergentes no mesmo CSV;
- rejeita linhas sem correspondência em `item_homologado`;
- rejeita linhas cuja chave natural já exista na tabela final com valores divergentes;
- insere apenas chaves novas com `ON CONFLICT DO NOTHING`;
- preserva `data_insercao` das linhas já existentes;
- mostra contagens finais de linhas do CSV, duplicatas exatas ignoradas, linhas já existentes iguais, linhas novas inseridas e total final.

Se qualquer validação falhar, a transação é interrompida antes de inserir novas linhas.

## Pontos de atenção

- Esta rotina não atualiza `src/ETL/BD/cria-esquema.sql`; a mudança permanece isolada nesta task.
- `tasks/api-compras/outputs/tabela-marcas.csv` é tratado como lote operacional de entrada.
- A carga é append-only: marcas ausentes em um CSV novo não são removidas da tabela.
- Correções de linhas já existentes devem ser tratadas por uma rotina própria futura, para preservar rastreabilidade.
- O CSV pode conter mais de uma marca por item homologado; por isso a chave da tabela inclui `marca`.
