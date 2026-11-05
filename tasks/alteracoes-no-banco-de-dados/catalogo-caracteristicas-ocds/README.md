# Task: `catalogo-caracteristicas-ocds`

## Resumo

Esta task mantém a fonte versionada e as ferramentas de migração da coluna
nullable `catalogo.caracteristicas_ocds JSONB`. A coluna armazena atributos
técnicos dos medicamentos mapeados para o padrão OCDS.

Desde a resolução da issue #52, bancos novos recebem a coluna por meio de
`src/ETL/BD/cria-esquema.sql`, e cargas futuras são feitas pelo loader
`src/ETL/loaders/carrega-catalogo.R`. Os scripts SQL deste diretório ficam
restritos à atualização pontual de bancos criados com o schema anterior.

## Versionamento do catálogo

| Versão | Fonte versionada | Registros validados | Entrada em produção | Resolução da issue de integração | Homologado em |
| --- | --- | ---: | --- | --- | --- |
| 0 | `data/catmat/OLD/0/tabela-mapeamento-ocds-0.csv` | 5.771 | 18/06/2026 | 30/07/2026 | 04/08/2026 |
| 1 | `data/catmat/tabela-mapeamento-ocds-1.csv` | 6.740 | 14/08/2026 | — | — |

A carga do catálogo faz upsert: os códigos de uma versão nova são atualizados e os que ficaram fora dela são
preservados. Por isso o banco tem a união das versões (6.807 códigos): os 6.740 da v1 com as características da v1 e
os 67 que só existem na v0 com as características da v0.

## Fonte versionada

Desde a versão 1, a tabela é gerada e versionada pela task [`atualiza-catmat`](../../atualiza-catmat/README.md),
junto com o catálogo, em `data/catmat/tabela-mapeamento-ocds-N.csv` (a versão vigente é o maior N; as anteriores
ficam em `data/catmat/OLD/N/`). É esse arquivo que `src/ETL/loaders/carrega-catalogo.R` lê, a partir do
`catmat-N.rds` de mesma versão.

## Como atualizar o CSV

Siga o fluxo da task [`atualiza-catmat`](../../atualiza-catmat/README.md): `01-importa-caracteristicas-ocds.R` gera a
tabela e `03-versionamento.R` a promove para `data/catmat/`.

O script `src/R/tabela-caracteristicas-ocds.R` desta task é legado: gerava a versão 0 em
`outputs/tabela-mapeamento-ocds.csv`, que não é mais usada.

## Fluxos de banco de dados

### Banco existente com schema antigo

Use os scripts SQL como migração pontual, nesta ordem:

```text
src/sql/alter-catalogo-caracteristicas-ocds.sql
src/sql/update-catalogo-caracteristicas-ocds.sql
```

Execute o update a partir da raiz do repositório em Bash/WSL:

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

# versão vigente da tabela (ajuste N)
dataset_csv="$PWD/data/catmat/tabela-mapeamento-ocds-1.csv"

psql -f <(
  sed "s|FROM :'dataset_csv'|FROM '$dataset_csv'|" \
    tasks/alteracoes-no-banco-de-dados/catalogo-caracteristicas-ocds/src/sql/update-catalogo-caracteristicas-ocds.sql
  )
)
```

**Esses scripts não fazem parte do ETL automatizado e não devem ser executados em
toda carga.**

### Banco novo ou carga futura

- `src/ETL/BD/cria-esquema.sql` cria `caracteristicas_ocds JSONB` e documenta a
  coluna;
- `src/ETL/loaders/carrega-catalogo.R` recebe `data/catmat/catmat-N.rds` e lê a
  `tabela-mapeamento-ocds-N.csv` de mesma versão;
- a carga usa upsert, permitindo que versões futuras atualizem os valores
  existentes sem executar os scripts de migração.

## Arquivos principais

- `data/catmat/tabela-mapeamento-ocds-N.csv`: fonte versionada usada pelo loader
  (gerada pela task `atualiza-catmat`);
- `src/R/tabela-caracteristicas-ocds.R` e `src/R/utils.R`: geração legada da
  versão 0;
- `outputs/tabela-mapeamento-ocds-old.csv`: versão histórica anterior;
- `src/sql/alter-catalogo-caracteristicas-ocds.sql`: migração do schema antigo;
- `src/sql/update-catalogo-caracteristicas-ocds.sql`: população pontual de
  bancos antigos;
- `src/sql/test-populacao-sqltools.sql`: teste transacional já executado para a
  versão 0.
