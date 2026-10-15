# Recuperação de itens com quantidade fracionária

Esta tarefa insere no banco os itens de medicamentos que a carga rejeitava e
que, por isso, nunca entraram em `item_homologado` ou `item_licitado`.

## Motivo

As colunas `quantidade_estimada` e `quantidade_homologada` são `INTEGER`, mas o
PNCP envia quantidades fracionárias (3.5, 0.23). O loader mandava o valor
como veio (`"3.5"`) e o PostgreSQL rejeitava a linha inteira. Pela mesma razão,
itens com `ncmNbsCodigo` não numérico (`"false"`, `"NS"`) também eram rejeitados.
Na maior parte das cargas isso não ficou registrado, porque os logs de carga só
passaram a ser guardados no data-package em abril de 2026.

O loader foi corrigido (`trunca_quantidade_pncp()` e
`normaliza_medicamentos_carga()` em `src/ETL/loaders/utils.R`). A partir dessa
correção, as cargas não rejeitam mais esses itens. Esta tarefa recupera os itens
das cargas anteriores.

## Regra adotada

As quantidades são **truncadas**: 3.5 vira 3 e 0.23 vira 0. É a mesma regra do
`int()` usado nos pacotes OCDS (`tasks/mapeamento-ocds/src/mapeamento-pncp-ocds.py`).
O esquema do banco não muda, e a aplicação
[medicamentos-transparentes](https://github.com/Transparencia-Brasil/medicamentos-transparentes),
cujas entidades declaram as quantidades como `integer`, não é afetada. A
quantidade original continua nos CSVs do data-package.

O `ncmNbsCodigo` não numérico vira `NULL`. Os códigos gravados como decimal nos
pacotes de 2025 (`"30041012.0"`) são preservados como inteiro.

## Impacto nos dados existentes

| Aspecto | Efeito |
|---|---|
| Itens já no banco | Não são alterados. A recuperação só **insere** itens ausentes. |
| `contratacao` e `contratante` | Não são gravados. As contratações reaparecem atualizadas em pacotes posteriores, e regravá-las a partir de um pacote antigo desfaria essas atualizações. |
| `fornecedor` | Inserido com a consulta da carga (`ON CONFLICT DO NOTHING`), sem alterar fornecedores existentes. |
| Itens recuperados | Entram com a quantidade truncada. Quantidades menores que 1 entram como 0, igual aos dados abertos OCDS. |
| Dez/2025 | A recoleta de resultados de dez/2025 (166 linhas com notação científica, `"1e+05"`) fica fora, porque exigiria acessar a API do PNCP. |

## Arquivos

- `src/R/lista-candidatos.R`: percorre `coleta/data-package/` e lista os itens com
  quantidade fracionária ou NCM inválido. Não acessa o banco.
- `src/R/recupera-itens.R`: monta as linhas com as funções da carga, verifica o
  banco com consultas só de leitura e insere os itens ausentes.
- `outputs/candidatos.csv`: itens candidatos por pacote, com motivo e valor original.
- `outputs/verificacao-banco.csv`: situação de cada item (`inserir`, `já existe`
  ou `pendente: <motivo>`). É gerado pelo `--dry-run` e regravado na execução.
- `outputs/run-*.log`: logs das execuções.

### Leitura tolerante dos pacotes antigos

Parte dos pacotes anteriores a abr/2026 não passa na leitura tipada atual do
loader. Só nesta recuperação, `recupera-itens.R` aplica uma leitura tolerante
(o loader de produção não muda):

- `itens-medicamentos.csv` com o artefato `"FALSE,,"` em `exigenciaConteudoNacional`
  (jul/2025 a mar/2026): a coluna é lida como texto e normalizada para o primeiro
  valor;
- `contratacoes.csv` com linhas desalinhadas (fev a jun/2025): o arquivo é lido
  como texto.

Em todos os pacotes, uma contratação só é usada se `data.numeroControlePNCP` for
coerente com o CNPJ, o ano e o sequencial da própria linha. Itens cuja
contratação não passa nessa validação ficam pendentes.

Quando o mesmo item aparece em mais de um pacote, vale a versão do pacote mais
recente.

## Execução

Na raiz do repositório, com o `.env` do banco (os scripts usam
`conecta_bd_medicamentos_transparentes()`):

```bash
TAREFA=tasks/alteracoes-no-banco-de-dados/recupera-itens-quantidade-fracionaria

# 1. Lista os candidatos (sem banco)
Rscript.exe $TAREFA/src/R/lista-candidatos.R

# 2. Monta as linhas sem acessar o banco (conferência local)
Rscript.exe $TAREFA/src/R/recupera-itens.R --sem-banco

# 3. Verifica o banco com consultas só de leitura e grava outputs/verificacao-banco.csv
Rscript.exe $TAREFA/src/R/recupera-itens.R --dry-run 2>&1 | tee $TAREFA/outputs/run-dry-run.log
```

Revise `outputs/verificacao-banco.csv` antes de continuar. Depois, faça backup do
banco e execute a inserção:

```bash
Rscript.exe $TAREFA/src/R/recupera-itens.R 2>&1 | tee $TAREFA/outputs/run-recupera-itens.log
```

A inserção usa uma única transação: se qualquer linha falhar, nada é gravado.
Ao final, o script registra as contagens antes e depois em
`src/ETL/loaders/historico-cargas.csv` (rotina `recuperacao_quantidade_fracionaria`)
e confere os deltas. O esperado é:

- `item_homologado` e `item_licitado`: delta igual ao número de itens com status `inserir`;
- `contratacao` e `contratante`: delta 0.

## Como desfazer

Os itens inseridos são os que têm status `inserir` em `outputs/verificacao-banco.csv`.
Para removê-los:

```sql
DELETE FROM item_homologado
WHERE (numero_controle_pncp, numero_item) IN (VALUES ('<numero_controle_pncp>', <numero_item>), ...);
-- idem para item_licitado
```

Os fornecedores eventualmente inseridos podem permanecer, pois são registros
válidos e independentes.
