# Verificação de compras judiciais

Esta task analisa descrições de compras públicas para localizar registros com possíveis indícios de atendimento a demandas judiciais.

O trabalho é exploratório e parte de uma regra textual simples, transparente e auditável. Uma compra é marcada quando o conteúdo normalizado da coluna `objeto_compra` contém o trecho `judic`, reconhecendo palavras como `judicial` e `judiciais`.

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

O trecho `judic` contempla palavras como `judicial` e `judiciais` e é procurado
literalmente no texto normalizado.

A função `limpa_texto`:

1. converte o texto para minúsculas;
2. remove as 207 stopwords em português do NLTK 3.9.1;
3. remove acentos com normalização Unicode NFKD;
4. normaliza os espaços em branco.

A função `possui_indicativo_judicial` retorna `False` para descrições ausentes,
aplica `limpa_texto` e procura o trecho definido em
`REGEX_TERMO_JUDICIAL`.

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
- NLTK e seu corpus de stopwords em português;
- módulos `re` e `unicodedata` da biblioteca padrão.

O notebook localiza automaticamente a raiz do repositório e monta os caminhos de entrada e saída a partir dela.

## Validação dos dados

Foi realizada uma validação por amostragem dos registros do início, do meio e do fim do dataset resultante, com o objetivo de verificar a aderência à regra de identificação e a ausência de falsos positivos nas amostras analisadas.

## Versionamento do snapshot histórico

| Versão | Arquivo | Registros | `TRUE` | `FALSE` | Entrada em produção | Integração ao ETL |
| --- | --- | ---: | ---: | ---: | --- | --- |
| 0 | `outputs/compras-judiciais-completo.csv` | 101.387 | 15.770 | 85.617 | 26/06/2026 | 11/08/2026 |

O arquivo `outputs/compras-judiciais-completo.csv` é um snapshot histórico para
auditoria e validação da paridade da implementação em R. Ele não é lido pelo
loader nem deve ser tratado como fonte operacional para cargas futuras.

O snapshot da versão 0 foi validado localmente com:

- `101.387` registros;
- `101.387` valores únicos de `numero_controle_pncp`;
- `15.770` registros com `compra_judicial = True`;
- `85.617` registros com `compra_judicial = False`;
- nenhum valor diferente de `True` ou `False`.

## Inclusão da classificação no banco

### Banco existente com schema antigo

Os scripts em `src/sql/` permanecem como ferramentas de migração pontual para
bancos criados antes da integração da coluna ao ETL. Eles adicionam a coluna e
aplicam o backfill usando o snapshot histórico, mas não fazem parte da execução
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
- `src/ETL/loaders/carrega-dados.R` calcula a classificação diretamente de
  `data.objetoCompra`, depois de filtrar as contratações de medicamentos;
- descrições ausentes recebem `FALSE` e as demais seguem a mesma normalização
  e regra `judic` do notebook;
- o upsert recalcula e atualiza a classificação quando `objeto_compra` mudar;
- o snapshot histórico não é consultado durante a carga.
