# Verificação de compras judiciais

Esta task analisa descrições de compras públicas para localizar registros com possíveis indícios de atendimento a demandas judiciais.

O trabalho é exploratório e parte de uma regra textual simples, transparente e auditável. Uma compra é marcada quando o conteúdo da coluna `objeto_compra` contém uma palavra iniciada por `judic`, reconhecendo palavras como `judicial` e `judiciais`.

## Estrutura

```text
tasks/verifica-compras-judiciais/
├── docs/
│   └── contagem-compras-judiciais.ipynb
├── inputs/
│   └── objeto-compra.csv
├── outputs/
│   ├── compras-judiciais-completo.csv
│   └── compras-somente-judiciais.csv
├── src/
│   └── sql/
│       ├── alter-contratacao-compra-judicial.sql
│       ├── test-populacao-sqltools.sql
│       └── update-contratacao-compra-judicial.sql
└── README.md
```

## Regra de identificação

A expressão usada no notebook é:

```python
REGEX_TERMO_JUDICIAL = r"judic"
```

O padrão `judic\w*` contempla palavras iniciadas por `judic`, incluindo `judicial` e `judiciais`.

A função `possui_indicativo_judicial`:

1. retorna `False` para descrições ausentes;
2. converte a descrição para texto em letras minúsculas;
3. procura o trecho definido em `REGEX_TERMO_JUDICIAL`;
4. retorna `True` quando encontra uma correspondência.

Exemplo de descrição identificada:

```text
AQUISIÇÃO DE MEDICAMENTOS PARA ATENDIMENTO DE DEMANDAS JUDICIAIS COM DISPENSA DE LICITAÇÃO EMERGENCIAL SEM DISPUTA.
```

A função é aplicada à coluna `objeto_compra` para criar a coluna booleana `compra_judicial`. Em seguida, os registros positivos são reunidos no DataFrame `apenas_compras_judiciais_df`.

Com a regra atual, foram identificados 15.770 registros no arquivo analisado.

## Como executar

Abra e execute:

```text
docs/contagem-compras-judiciais.ipynb
```

O notebook utiliza:

- Python;
- pandas;
- módulo `re(regular expressions)` da biblioteca padrão.

O caminho `base_dir` está definido diretamente no notebook e deve apontar para a raiz local do repositório.

## Validação dos dados

Foi realizada uma validação por amostragem dos registros do início, do meio e do fim do dataset resultante, com o objetivo de verificar a aderência à regra de identificação e a ausência de falsos positivos nas amostras analisadas.

## Inclusão da classificação no banco

Os scripts em `src/sql/` preparam a inclusão e a população da coluna booleana
`contratacao.compra_judicial`. A mudança permanece isolada nesta task enquanto
o fluxo é validado e, por isso, ainda não altera
`src/ETL/BD/cria-esquema.sql`.

O arquivo `outputs/compras-judiciais-completo.csv` é o dataset de entrada do
backfill. A atualização relaciona o CSV à tabela `contratacao` pela chave
`numero_controle_pncp` e copia os valores `True` e `False` da coluna
`compra_judicial`.

O dataset foi validado localmente com:

- `101.387` registros;
- `101.387` valores únicos de `numero_controle_pncp`;
- `15.770` registros com `compra_judicial = True`;
- `85.617` registros com `compra_judicial = False`;
- nenhum valor diferente de `True` ou `False`.

### Como testar no SQLTools

O arquivo `src/sql/test-populacao-sqltools.sql` simula o fluxo completo usando
tabelas temporárias:

1. reproduz o schema atual de `contratacao`;
2. insere uma contratação judicial e uma não judicial;
3. adiciona a coluna `compra_judicial`;
4. simula a carga do CSV;
5. atualiza os registros por `numero_controle_pncp`;
6. mostra as contagens finais;
7. executa `ROLLBACK`.

Para testar, conecte o SQLTools a um banco PostgreSQL, abra o arquivo e execute
todo o script com `Run on active connection`. Como o teste usa tabelas
temporárias e termina com `ROLLBACK`, nenhuma tabela real é alterada.

### Como aplicar no banco

Execute primeiro o script que adiciona a coluna:

```bash
psql -d nome-do-database \
  -f tasks/verifica-compras-judiciais/src/sql/alter-contratacao-compra-judicial.sql
```

Depois, a partir da raiz do repositório, execute o backfill em um terminal
Bash/WSL com o cliente `psql` disponível:

```bash
(
  set -a
  source <(sed 's/\r$//' .env)
  set +a

  export PGHOST="$DB_HOST"
  export PGPORT="$DB_PORT"
  export PGUSER="$DB_USER"
  export PGPASSWORD="$DB_PASS"
  export PGDATABASE="nome-do-database"

  dataset_csv="$PWD/tasks/verifica-compras-judiciais/outputs/compras-judiciais-completo.csv"

  psql -f <(
    sed "s|FROM :'dataset_csv'|FROM '$dataset_csv'|" \
      tasks/verifica-compras-judiciais/src/sql/update-contratacao-compra-judicial.sql
  )
)
```

O subshell evita que as credenciais exportadas permaneçam no terminal. O
script de atualização:

- carrega o CSV em uma tabela temporária;
- interrompe a transação se encontrar um booleano inválido;
- informa quantas chaves do dataset foram ou não encontradas em `contratacao`;
- atualiza somente `contratacao.compra_judicial`;
- mostra as contagens finais de valores `NULL`, `TRUE` e `FALSE`.

O CSV em `outputs/` é um artefato operacional volumoso e não deve ser
versionado sem solicitação explícita.
