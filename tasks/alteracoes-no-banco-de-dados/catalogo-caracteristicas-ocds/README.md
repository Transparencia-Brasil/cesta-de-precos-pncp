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

| Versão | Fonte versionada | Registros validados | Entrada em produção | Resolução da issue de integração |
| --- | --- | ---: | --- | --- |
| 0 | `outputs/tabela-mapeamento-ocds.csv` | 5.771 | 18/06/2026 | 30/07/2026 |

A versão 0 já foi validada e não deve ser testada novamente durante a execução
normal do ETL. Uma nova rodada de validação só é necessária quando uma nova
versão da tabela catálogo for gerada; nesse caso, registre a nova versão nesta
tabela antes de publicá-la.

## Fonte versionada

O arquivo usado pelo loader é:

```text
tasks/alteracoes-no-banco-de-dados/catalogo-caracteristicas-ocds/outputs/tabela-mapeamento-ocds.csv
```

Ele contém somente:

- `codigo_item`: código CATMAT usado como chave única;
- `caracteristicas_ocds`: JSON textual com os atributos OCDS.

O loader seleciona apenas essas duas colunas, valida a unicidade de
`codigo_item` e a sintaxe dos valores JSON preenchidos e integra o mapeamento
por `catalogo.codigo_br = mapeamento.codigo_item`. Itens sem correspondência
permanecem com `caracteristicas_ocds = NULL`.

## Como atualizar o CSV

Quando a fonte OCDS mudar, execute a partir da raiz do repositório:

```bash
Rscript.exe tasks/alteracoes-no-banco-de-dados/catalogo-caracteristicas-ocds/src/R/tabela-caracteristicas-ocds.R
```

O gerador consulta a fonte versionada no repositório
`Transparencia-Brasil/medicine-extension-ocds` e requer `GITHUB_TOKEN` no
ambiente. Ele sobrescreve `outputs/tabela-mapeamento-ocds.csv`; por isso, não o
execute durante cargas normais do catálogo.

Para uma nova versão:

1. revise a alteração da fonte OCDS e do CSV gerado;
2. valide quantidade de linhas, unicidade de `codigo_item`, preenchimento e
   sintaxe JSON;
3. execute os testes SQL transacionais desta task em um banco local ou de
   teste;
4. registre a nova versão e suas datas na tabela de versionamento acima;
5. publique o CSV e o código do gerador no mesmo PR.

## Fluxos de banco de dados

### Banco existente com schema antigo

Use os scripts SQL como migração pontual, nesta ordem:

```text
src/sql/alter-catalogo-caracteristicas-ocds.sql
src/sql/update-catalogo-caracteristicas-ocds.sql
```

O primeiro adiciona a coluna nullable. O segundo importa o CSV de duas colunas
em uma tabela temporária e atualiza o catálogo por `codigo_item`. Ambos usam
transação e `ON_ERROR_STOP`; JSON inválido interrompe a operação.

Como `\copy` não expande `:'dataset_csv'` como uma consulta SQL comum, execute
o update a partir da raiz do repositório em Bash/WSL:

```bash
dataset_csv="$PWD/tasks/alteracoes-no-banco-de-dados/catalogo-caracteristicas-ocds/outputs/tabela-mapeamento-ocds.csv"

psql -f <(
  sed "s|FROM :'dataset_csv'|FROM '$dataset_csv'|" \
    tasks/alteracoes-no-banco-de-dados/catalogo-caracteristicas-ocds/src/sql/update-catalogo-caracteristicas-ocds.sql
)
```

Configure a conexão por variáveis `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD` e
`PGDATABASE` no ambiente sem imprimir nem versionar credenciais.

Esses scripts não fazem parte do ETL automatizado e não devem ser executados em
toda carga.

### Banco novo ou carga futura

- `src/ETL/BD/cria-esquema.sql` cria `caracteristicas_ocds JSONB` e documenta a
  coluna;
- `src/ETL/loaders/carrega-catalogo.R` lê diretamente o CSV versionado com
  `here::here()`;
- a carga usa upsert, permitindo que versões futuras atualizem os valores
  existentes sem executar os scripts de migração.

## Evidências de validação da versão 0

Os testes já realizados nesta task comprovaram:

- 5.771 linhas no mapeamento;
- nenhum `codigo_item` duplicado;
- 5.771 valores preenchidos;
- aceitação dos valores como `JSONB` pelo PostgreSQL;
- população por `codigo_item` sem alterar `características`, unidades de
  fornecimento, chaves ou relacionamentos;
- execução transacional dos testes com `ROLLBACK`.

Os arquivos de evidência e operação permanecem em `src/sql/`, incluindo os
testes para SQLTools e o histórico da correção aplicada à versão 0.

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
