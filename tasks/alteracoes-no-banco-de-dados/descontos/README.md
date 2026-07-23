# Inclusão de descontos em `item_homologado`

Esta task adiciona e popula em `item_homologado` os atributos de benefícios,
margens de preferência, critérios de desempate e desconto disponíveis no
dataset `src/inputs/descontos.csv`.

A atualização usa a chave composta `(numero_controle_pncp, numero_item)`. Ela
altera somente itens já existentes no banco e não insere chaves ausentes.

## Arquivos

- `src/inputs/descontos.csv`: dataset usado no backfill;
- `src/sql/alter-item-homologado-descontos.sql`: adiciona e comenta as colunas;
- `src/sql/update-item-homologado-descontos.sql`: valida, converte e carrega o CSV;
- `src/sql/test-populacao-sqltools.sql`: teste autocontido que termina com `ROLLBACK`;
- `src/sql/rollback-item-homologado-descontos.sql`: rollback emergencial do schema.

Os arquivos `tasks/verifica-descontos/src/join-descontos.R` e
`src/ETL/BD/cria-esquema.sql` são referências desta alteração e não são
modificados pela task.

## Colunas de destino

Todas as colunas são nullable e não possuem `DEFAULT`.

| Coluna | Tipo PostgreSQL |
|---|---|
| `aplicacao_beneficio_me_epp` | `BOOLEAN` |
| `incentivo_produtivo_basico` | `BOOLEAN` |
| `exigencia_conteudo_nacional` | `BOOLEAN` |
| `aplicabilidade_margem_preferencia_normal` | `BOOLEAN` |
| `aplicabilidade_margem_preferencia_adicional` | `BOOLEAN` |
| `tipo_margem_preferencia_codigo` | `INTEGER` |
| `tipo_margem_preferencia_nome` | `TEXT` |
| `percentual_margem_preferencia_normal` | `NUMERIC` |
| `percentual_margem_preferencia_adicional` | `NUMERIC` |
| `aplicacao_margem_preferencia` | `BOOLEAN` |
| `amparo_legal_margem_preferencia_id` | `INTEGER` |
| `amparo_legal_margem_preferencia_nome` | `TEXT` |
| `amparo_legal_margem_preferencia_descricao` | `TEXT` |
| `aplicacao_criterio_desempate` | `BOOLEAN` |
| `amparo_legal_criterio_desempate_id` | `INTEGER` |
| `amparo_legal_criterio_desempate_nome` | `TEXT` |
| `amparo_legal_criterio_desempate_descricao` | `TEXT` |
| `percentual_desconto` | `NUMERIC` |

O script de alteração interrompe a execução se encontrar alguma coluna de
destino com tipo incompatível. Se as 18 colunas já existirem com os tipos
corretos, o `ALTER` pode ser reexecutado.

Os percentuais usam `NUMERIC` sem restrição de faixa. Isso preserva os valores
de origem, inclusive `percentual_desconto` superior a 100.

## Dataset validado

O arquivo `src/inputs/descontos.csv` foi inspecionado com os seguintes
resultados:

- 200.205 linhas e 20 colunas, incluindo as duas chaves;
- nenhuma chave nula ou duplicada;
- 61.279 linhas com os 18 atributos nulos;
- sete colunas booleanas contendo somente `TRUE`, `FALSE` ou nulo;
- inteiros e números sem valores inválidos;
- `percentual_desconto` entre `0` e `559.32` nos registros preenchidos.

Na carga, vazio, `NA`, `N/A`, `NULL` e `null` são convertidos para SQL `NULL`,
reproduzindo a leitura defensiva de `join-descontos.R`. Para uma chave
encontrada, esses nulos substituem qualquer valor anterior porque o CSV é a
fonte autoritativa do backfill.

Os booleanos aceitos são os mesmos da leitura defensiva:

- verdadeiros: `true`, `t`, `1`, `sim`, `s`, `yes`, `y`, `verdadeiro`, `v`;
- falsos: `false`, `f`, `0`, `nao`, `não`, `n`, `no`, `falso`.

Valores fora desses domínios, chaves inválidas, chaves duplicadas e números não
conversíveis interrompem toda a transação.

## Teste no SQLTools

Abra `src/sql/test-populacao-sqltools.sql` em uma conexão PostgreSQL e execute o
arquivo inteiro. O teste:

1. cria uma representação temporária de `item_homologado`;
2. adiciona as 18 colunas com os tipos de produção;
3. simula registros completos, parciais, totalmente nulos e uma chave ausente;
4. executa o backfill e valida tipos, valores, cardinalidade e normalização;
5. comprova que nulos do CSV substituem valores anteriores;
6. termina com `ROLLBACK`.

O resultado esperado é a exibição de três itens atualizados e nenhuma exceção.
Nenhuma tabela permanente é alterada.

## Aplicação no banco

Antes da execução, faça backup do banco e programe uma janela de manutenção. O
`ALTER TABLE`, o `UPDATE` e o rollback adquirem locks sobre
`item_homologado`; o backfill processa aproximadamente 200 mil registros.

Execute primeiro o `ALTER`:

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

  psql -v ON_ERROR_STOP=1 \
    -f tasks/alteracoes-no-banco-de-dados/descontos/src/sql/alter-item-homologado-descontos.sql
)
```

Depois, a partir da raiz do repositório, execute o backfill em Bash/WSL com o
cliente `psql` disponível:

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

  dataset_csv="$PWD/tasks/alteracoes-no-banco-de-dados/descontos/src/inputs/descontos.csv"

  psql -f <(
    sed "s|FROM :'dataset_csv'|FROM '$dataset_csv'|" \
      tasks/alteracoes-no-banco-de-dados/descontos/src/sql/update-item-homologado-descontos.sql
  )
)
```

O subshell impede que as credenciais exportadas permaneçam no terminal. O
script informa, antes do `COMMIT`:

- total de linhas no dataset;
- itens encontrados e não encontrados;
- total de linhas atualizadas;
- valores nulos e preenchidos em cada uma das 18 colunas.

Chaves ausentes são somente contabilizadas. Elas não são inseridas e não
interrompem a carga.

## Rollback emergencial

O rollback remove as 18 colunas e todos os dados nelas armazenados. Use-o
somente para reverter esta task e somente depois de confirmar que existe um
backup recuperável:

```bash
psql -d medicamentos_transparentes \
  -f tasks/alteracoes-no-banco-de-dados/descontos/src/sql/rollback-item-homologado-descontos.sql
```

O rollback usa uma única transação e `ON_ERROR_STOP`.
