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
| 0 | `outputs/tabela-mapeamento-ocds.csv` | 5.771 | 18/06/2026 | 30/07/2026 | 04/08/2026 |

## Fonte versionada

O arquivo usado pelo loader é:

```text
tasks/alteracoes-no-banco-de-dados/catalogo-caracteristicas-ocds/outputs/tabela-mapeamento-ocds.csv
```

## Como atualizar o CSV

Quando a fonte OCDS mudar, execute a partir da raiz do repositório:

```bash
Rscript.exe tasks/alteracoes-no-banco-de-dados/catalogo-caracteristicas-ocds/src/R/tabela-caracteristicas-ocds.R
```

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

dataset_csv="$PWD/tasks/alteracoes-no-banco-de-dados/catalogo-caracteristicas-ocds/outputs/tabela-mapeamento-ocds.csv"

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
- `src/ETL/loaders/carrega-catalogo.R` lê diretamente o CSV versionado com
  `here::here()`;
- a carga usa upsert, permitindo que versões futuras atualizem os valores
  existentes sem executar os scripts de migração.

## Arquivos principais

- `src/R/tabela-caracteristicas-ocds.R`: gera o CSV a partir da fonte OCDS;
- `src/R/utils.R`: transforma o documento OCDS no mapeamento;
- `outputs/tabela-mapeamento-ocds.csv`: fonte versionada usada pelo loader;
- `outputs/tabela-mapeamento-ocds-old.csv`: versão histórica anterior;
- `src/sql/alter-catalogo-caracteristicas-ocds.sql`: migração do schema antigo;
- `src/sql/update-catalogo-caracteristicas-ocds.sql`: população pontual de
  bancos antigos;
- `src/sql/test-populacao-sqltools.sql`: teste transacional já executado para a
  versão 0.
