# Inclusão de margens de preferência em `item_homologado`

Esta alteração acrescenta à tabela `item_homologado` os campos de margem de preferência disponíveis no PNCP e preenche o histórico usando `tasks/verifica-descontos/outputs/itens_homologados_atualizados_com_legado.csv`.

## Arquivos

- `src/sql/alter-item-homologado-descontos.sql`: adiciona as oito colunas e seus comentários.
- `src/sql/update-item-homologado-descontos.sql`: carrega o CSV em tabela temporária, valida as chaves e atualiza os itens pela chave composta `(numero_controle_pncp, numero_item)`.
- `src/sql/test-populacao-sqltools.sql`: teste autocontido com cinco registros reais de `src/inputs/item_homologado.csv` e os valores correspondentes do CSV enriquecido.

## Mapeamento de colunas

As colunas de destino usam `snake_case`, seguindo o padrão do schema do banco. A tabela temporária de importação preserva os cabeçalhos originais do CSV para explicitar o mapeamento da origem.

| CSV/API | `item_homologado` |
|---|---|
| `aplicabilidadeMargemPreferenciaNormal` | `aplicabilidade_margem_preferencia_normal` |
| `percentualMargemPreferenciaNormal` | `percentual_margem_preferencia_normal` |
| `aplicabilidadeMargemPreferenciaAdicional` | `aplicabilidade_margem_preferencia_adicional` |
| `percentualMargemPreferenciaAdicional` | `percentual_margem_preferencia_adicional` |
| `tipoMargemPreferencia.codigo` | `tipo_margem_preferencia_codigo` |
| `tipoMargemPreferencia.nome` | `tipo_margem_preferencia_nome` |
| `tipoMargemPreferencia` | `tipo_margem_preferencia` |
| `exigenciaConteudoNacional` | `exigencia_conteudo_nacional` |

Esses identificadores não exigem aspas duplas nas consultas SQL. Exemplo: `item_homologado.exigencia_conteudo_nacional`.

As colunas são `TEXT` de forma intencional. O arquivo enriquecido reúne dados atuais e legados e contém, além de escalares como `True`, `False` e `5.0`, valores legados divergentes preservados como listas textuais. Converter diretamente para `BOOLEAN` ou `NUMERIC` descartaria informação ou faria a carga falhar.

## Teste no SQLTools

Abra `src/sql/test-populacao-sqltools.sql` em uma conexão PostgreSQL e execute o arquivo inteiro. O teste:

1. abre uma transação e cria uma tabela temporária;
2. insere cinco itens reais;
3. executa o `ALTER TABLE`;
4. insere na staging os respectivos dados enriquecidos;
5. executa o `UPDATE` e valida cardinalidade, preenchimento e preservação de um valor legado composto;
6. executa `ROLLBACK`, sem modificar o banco.

O resultado esperado é a consulta `02 DEPOIS DO UPDATE` com cinco linhas e sem exceção. O SQLTools executa esse teste porque ele contém somente SQL PostgreSQL; o script de carga real usa comandos `psql` (`\set` e `\copy`) e deve ser executado pelo terminal.

## Aplicação no banco real

Faça backup e execute primeiro o `ALTER`:

```bash
psql -d medicamentos-transparentes -f tasks/alteracoes-no-banco-de-dados/descontos/src/sql/alter-item-homologado-descontos.sql
```

Depois execute o preenchimento:

```bash
psql -d medicamentos-transparentes \
  -v dataset_csv='tasks/verifica-descontos/outputs/itens_homologados_atualizados_com_legado.csv' \
  -f tasks/alteracoes-no-banco-de-dados/descontos/src/sql/update-item-homologado-descontos.sql
```

Antes do `COMMIT`, o script mostra quantas chaves do dataset foram encontradas. Chaves ausentes não são inseridas: apenas registros existentes em `item_homologado` são atualizados. O script interrompe a transação se houver chave nula, inválida ou duplicada no CSV.

## Observação sobre o schema-base

Esta task é uma migração para uma tabela já existente e, por isso, não altera automaticamente `src/ETL/BD/cria-esquema.sql`. Depois da aplicação e homologação, as mesmas colunas devem ser incorporadas ao schema-base para que bancos criados do zero já nasçam compatíveis.
