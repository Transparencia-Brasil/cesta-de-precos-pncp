# Carga híbrida e atômica do catálogo CATMAT

Este procedimento atualiza os códigos presentes na nova versão do CATMAT,
insere códigos novos e preserva códigos antigos ausentes na fonte. A carga não
executa `DELETE` nem `TRUNCATE`.

## Preparação

Pause os loaders que escrevem no banco e valide a fonte sem abrir conexão:

```bash
Rscript.exe src/ETL/loaders/carrega-catalogo.R \
  data/catmat/catmat-1.rds --validar-apenas
```

O resultado esperado para a versão 1 é `6740 itens prontos para carga`.

Configure o `psql` com as variáveis `DB_HOST`, `DB_PORT`, `DB_USER` e `DB_PASS`
do ambiente, sem copiar seus valores para comandos versionados ou logs.

## Migração e backup

No banco `medicamentos_transparentes`, execute nesta ordem:

```bash
psql -d medicamentos_transparentes \
  -f tasks/alteracoes-no-banco-de-dados/catalogo-upsert-atomico/src/sql/alter-catalogo-data-atualizacao.sql
psql -d medicamentos_transparentes \
  -f tasks/alteracoes-no-banco-de-dados/catalogo-upsert-atomico/src/sql/backup-catalogo.sql
```

Registre o nome exibido como `BACKUP_CATALOGO`. O backup não é removido
automaticamente.

## Carga

```bash
Rscript.exe src/ETL/loaders/carrega-catalogo.R data/catmat/catmat-1.rds
```

O loader mostra as quantidades atualizada, inserida e preservada. Qualquer erro
de linha ou divergência nas verificações finais provoca rollback de toda a carga.

Após o commit, confira:

```sql
SELECT count(*) AS total_catalogo,
       count(*) FILTER (WHERE data_atualizacao IS NULL) AS sem_data_atualizacao
FROM catalogo;

SELECT c.codigo_item, c.nome_item, c.data_insercao, c.data_atualizacao,
       count(ih.*) AS referencias
FROM catalogo AS c
LEFT JOIN item_homologado AS ih
  ON ih.codigo_item_catalogo = c.codigo_item
GROUP BY c.codigo_item, c.nome_item, c.data_insercao, c.data_atualizacao
ORDER BY referencias DESC
LIMIT 20;
```

## Reversão posterior ao commit

Mantenha os loaders pausados e use exatamente o nome registrado no backup:

```bash
psql -d medicamentos_transparentes \
  -v backup_table=catalogo_backup_AAAAMMDD_HHMMSS \
  -f tasks/alteracoes-no-banco-de-dados/catalogo-upsert-atomico/src/sql/restaura-catalogo.sql
```

A restauração é transacional. Se um código novo já tiver recebido referências,
a chave estrangeira impedirá sua remoção e toda a restauração será revertida.

## Teste SQL isolado

O teste usa uma tabela temporária, cobre o cenário `100/200/300` para
`100/200/400`, simula uma falha intermediária e termina com `ROLLBACK`:

```bash
psql -d medicamentos_transparentes \
  -f tasks/alteracoes-no-banco-de-dados/catalogo-upsert-atomico/src/sql/test-upsert-catalogo.sql
```
