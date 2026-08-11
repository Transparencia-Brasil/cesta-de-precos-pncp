# Verificação de compras judiciais

Esta task analisa descrições de compras públicas para localizar registros com possíveis indícios de atendimento a demandas judiciais.

O trabalho é exploratório e parte de uma regra textual simples, transparente e auditável. Uma compra é marcada quando o conteúdo da coluna `objeto_compra` contém uma palavra iniciada por `judic`, reconhecendo palavras como `judicial` e `judiciais`.

## Estrutura

```text
tasks/alteracoes-no-banco-de-dados/verifica-compras-judiciais/
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

O notebook localiza automaticamente a raiz do repositório e monta os caminhos de entrada e saída a partir dela.

## Validação dos dados

Foi realizada uma validação por amostragem dos registros do início, do meio e do fim do dataset resultante, com o objetivo de verificar a aderência à regra de identificação e a ausência de falsos positivos nas amostras analisadas.

## Versionamento do dataset

| Versão | Fonte versionada | Registros | `TRUE` | `FALSE` | Entrada em produção | Integração ao ETL |
| --- | --- | ---: | ---: | ---: | --- | --- |
| 0 | `outputs/compras-judiciais-completo.csv` | 101.387 | 15.770 | 85.617 | 26/06/2026 | 11/08/2026 |

O loader usa sempre o caminho estável
`outputs/compras-judiciais-completo.csv`. Para publicar uma nova classificação:

1. arquive o arquivo atual como
   `outputs/compras-judiciais-completo-v<versão-atual>.csv`;
2. atualize a entrada ou a regra de identificação e execute novamente o
   notebook `docs/contagem-compras-judiciais.ipynb`;
3. mantenha o novo resultado no caminho estável usado pelo loader;
4. valide o total de registros, a unicidade de `numero_controle_pncp` e o
   domínio booleano de `compra_judicial`;
5. acrescente a nova versão e suas contagens à tabela acima.

## Inclusão da classificação no banco

O arquivo `outputs/compras-judiciais-completo.csv` é a fonte versionada da
classificação. A integração relaciona o CSV à tabela `contratacao` pela chave
`numero_controle_pncp` e copia os valores `True` e `False` da coluna
`compra_judicial`.

O dataset da versão 0 foi validado localmente com:

- `101.387` registros;
- `101.387` valores únicos de `numero_controle_pncp`;
- `15.770` registros com `compra_judicial = True`;
- `85.617` registros com `compra_judicial = False`;
- nenhum valor diferente de `True` ou `False`.

### Banco existente com schema antigo

Os scripts em `src/sql/` são ferramentas de migração pontual para bancos
criados antes da integração da coluna ao ETL. Eles não fazem parte da execução
regular do loader.

Execute primeiro o script que adiciona a coluna:

```bash
psql -d medicamentos_transparentes \
  -f tasks/alteracoes-no-banco-de-dados/verifica-compras-judiciais/src/sql/alter-contratacao-compra-judicial.sql
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
  export PGDATABASE="medicamentos_transparentes"

  dataset_csv="$PWD/tasks/alteracoes-no-banco-de-dados/verifica-compras-judiciais/outputs/compras-judiciais-completo.csv"

  psql -f <(
    sed "s|FROM :'dataset_csv'|FROM '$dataset_csv'|" \
      tasks/alteracoes-no-banco-de-dados/verifica-compras-judiciais/src/sql/update-contratacao-compra-judicial.sql
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

O arquivo `src/sql/test-populacao-sqltools.sql` continua disponível para
simular esse fluxo legado com tabelas temporárias e `ROLLBACK`.

### Banco novo ou carga futura

- `src/ETL/BD/cria-esquema.sql` cria e documenta a coluna nullable
  `compra_judicial BOOLEAN`;
- `src/ETL/loaders/carrega-dados.R` lê diretamente a fonte versionada usando
  `here::here()`;
- o loader seleciona e valida apenas `numero_controle_pncp` e
  `compra_judicial` antes de se conectar ao banco;
- contratações sem correspondência permanecem com `NULL`;
- o upsert atualiza classificações existentes quando o CSV mudar.
