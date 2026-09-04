# Loaders do banco Medicamentos Transparentes

Este diretório contém as rotinas R responsáveis por carregar no PostgreSQL os dados coletados e classificados pelo pipeline do PNCP. Os loaders são a ponte entre os arquivos operacionais em `coleta/` e o schema definido em [`src/ETL/BD/cria-esquema.sql`](../BD/cria-esquema.sql).

Use este diretório para duas cargas principais:

| Script | Entrada | Tabelas afetadas |
| --- | --- | --- |
| [`carrega-catalogo.R`](carrega-catalogo.R) | Catálogo CATMAT em `.rds` e mapeamento OCDS versionado | `catalogo` |
| [`carrega-dados.R`](carrega-dados.R) | CSVs de contratações, medicamentos e resultados | `contratante`, `fornecedor`, `contratacao`, `item_homologado`, `item_licitado` |

## Arquivos do diretório

| Arquivo | Função |
| --- | --- |
| [`carrega-catalogo.R`](carrega-catalogo.R) | Prepara o catálogo CATMAT, integra características OCDS, transforma campos JSON e faz upsert dos itens na tabela `catalogo`. |
| [`carrega-dados.R`](carrega-dados.R) | Lê os CSVs gerados pela coleta, monta as tabelas relacionais e executa a carga principal no banco. |
| [`utils.R`](utils.R) | Centraliza mapeamentos de colunas, consultas SQL parametrizadas, conexão com PostgreSQL e função de inserção linha a linha. |
| [`utils-historico.R`](utils-historico.R) | Conta registros antes/depois da carga e registra o histórico em [`historico-cargas.csv`](historico-cargas.csv). |
| [`historico-cargas.csv`](historico-cargas.csv) | Trilha versionada de execuções de `carrega-dados.R`, com período, tabela, contagens e delta. |
| [`historico.sql`](historico.sql) | Consultas manuais de apoio para inspeção e sanity check do banco. |

## Pré-requisitos

- Banco PostgreSQL `medicamentos_transparentes` criado e com o schema aplicado.
- Arquivo `.env` na raiz do repositório com as variáveis de conexão abaixo, sem credenciais reais versionadas:

```env
DB_HOST="..."
DB_USER="..."
DB_PASS="..."
DB_PORT="..."
```

- Pacotes R usados pelos scripts: `readr`, `dplyr`, `tidyr`, `purrr`, `here`, `jsonlite`, `stringi`, `DBI`, `RPostgres` e `dotenv`.
- Execução a partir da raiz do repositório, para que `here::here()` resolva os caminhos corretamente.

## Fluxo recomendado

No fluxo completo, a carga é acionada pelo orquestrador [`src/ETL/run-coletores.sh`](../run-coletores.sh), depois da coleta, classificação de medicamentos, coleta de resultados e empacotamento dos CSVs.

```text
coleta PNCP -> classificação de medicamentos -> resultados -> data-package -> carrega-dados.R -> PostgreSQL
```

Quando a opção de carga no banco é confirmada, o orquestrador usa os arquivos principais em:

```text
coleta/data-package/<ANO>/<MÊS>/<QUINZENA>/DATA/
├── contratacoes.csv
├── itens-medicamentos.csv
└── itens-medicamentos-resultados.csv
```

e executa:

```bash
Rscript.exe src/ETL/loaders/carrega-dados.R \
  "coleta/data-package/<ANO>/<MÊS>/<QUINZENA>/DATA/contratacoes.csv" \
  "coleta/data-package/<ANO>/<MÊS>/<QUINZENA>/DATA/itens-medicamentos.csv" \
  "coleta/data-package/<ANO>/<MÊS>/<QUINZENA>/DATA/itens-medicamentos-resultados.csv"
```

O log dessa etapa é salvo em:

```text
coleta/data-package/<ANO>/<MÊS>/<QUINZENA>/LOG/run-carrega-dados-<ANO>-<MM>-<QUINZENA>.log
```

## Carga de dados PNCP

`carrega-dados.R` exige três arquivos `.csv`, nessa ordem:

1. Contratações (`contratacoes.csv`)
2. Itens classificados como medicamentos (`itens-medicamentos.csv`)
3. Resultados dos itens de medicamentos (`itens-medicamentos-resultados.csv`)

Os três arquivos são lidos por `le_csv_pncp()`, definida em `utils.R`. Os
templates versionados em `src/ETL/template/templates/` são a fonte de verdade
para os tipos dos campos da API; campos operacionais e campos criados pelo
classificador possuem tipos complementares definidos pelo loader. Colunas novas
que ainda não estejam no template são preservadas como texto e geram aviso.
Valores incompatíveis com um tipo conhecido interrompem a execução antes da
conexão com o PostgreSQL, com indicação de linha, coluna, tipo esperado e valor
recebido.

Durante a transformação, o script:

- remove linhas sem `endpoint`;
- reconstrói URLs de rastreabilidade (`urlAPI` e `urlPNCP`);
- mantém somente contratações que possuem itens classificados como medicamentos;
- preserva `data.usuarioNome` em `contratacao.usuario_nome`;
- calcula `compra_judicial` a partir de `data.objetoCompra`;
- inclui contratantes principais e, quando existirem, contratantes sub-rogados;
- separa itens com resultado em `item_homologado` e itens sem resultado em `item_licitado`;
- preenche como `NA` colunas opcionais ausentes nos CSVs de entrada.

Na construção de `item_homologado`, o loader também combina oito campos de
benefícios e margens vindos dos itens com dez campos de benefícios, margens,
desempate e desconto vindos dos resultados. Esses campos são convertidos para
os tipos PostgreSQL esperados; valores ausentes permanecem `NULL` e
`percentual_desconto` não possui limite de faixa.

Na recoleta, somente os dez campos retornados pelo endpoint de resultados estão
disponíveis. Os oito campos exclusivos do item permanecem `NULL`, pois
`item_licitado` não armazena esses atributos. A task
`tasks/alteracoes-no-banco-de-dados/descontos/` é apenas um snapshot histórico
de auditoria e nunca é lida pela carga regular ou pela recoleta.

A ordem de inserção respeita as dependências do schema:

```text
1. contratante
2. fornecedor
3. contratacao
4. item_homologado
5. item_licitado
```

As inserções são idempotentes por chave de negócio. As consultas em [`utils.R`](utils.R) usam `ON CONFLICT`: contratantes e fornecedores duplicados são ignorados, enquanto contratações e itens já existentes são atualizados com os dados mais recentes.

Para calcular `compra_judicial`, o loader transpõe a regra do notebook da task `verifica-compras-judiciais`: converte a descrição para minúsculas, remove as stopwords em português do NLTK 3.9.1, remove acentos com normalização Unicode NFKD, normaliza espaços e procura a ocorrência literal de `judic`. Descrições ausentes recebem `FALSE`. Como o campo também faz parte do `DO UPDATE`, uma nova carga recalcula a classificação quando `objeto_compra` mudar.

O arquivo `tasks/alteracoes-no-banco-de-dados/verifica-compras-judiciais/outputs/compras-judiciais-completo.csv` é apenas um snapshot histórico para auditoria e validação de paridade; ele não é lido pelo loader.

## Carga do catálogo CATMAT

`carrega-catalogo.R` carrega medicamentos do CATMAT para a tabela `catalogo`. O catálogo de referência atual do projeto fica em:

```text
data/catmat/catmat-1.rds
```

O mapeamento OCDS correspondente fica no mesmo diretório:

```text
data/catmat/tabela-mapeamento-ocds-1.csv
```

Execução:

```bash
Rscript.exe src/ETL/loaders/carrega-catalogo.R data/catmat/catmat-1.rds
```

Validação completa da fonte, sem abrir conexão com o banco:

```bash
Rscript.exe src/ETL/loaders/carrega-catalogo.R \
  data/catmat/catmat-1.rds --validar-apenas
```

O nome do RDS deve seguir o padrão `catmat-N.rds`. O loader extrai a versão `N` e exige, no mesmo diretório, o arquivo `tabela-mapeamento-ocds-N.csv`. Assim, versões atuais e históricas são sempre carregadas com o respectivo mapeamento. Em seguida, o script seleciona até três características mais informativas por PDM e grava características e unidades de fornecimento como `jsonb`. O CSV OCDS é reduzido a `codigo_item` e `caracteristicas_ocds`, validado e integrado por `codigo_br = codigo_item`.

Itens sem correspondência no CSV recebem `NULL` em `caracteristicas_ocds`. Códigos do mapeamento que não pertencem ao RDS interrompem a carga por indicarem versões incompatíveis.

A carga usa um upsert híbrido: atualiza os códigos presentes na fonte, insere códigos novos e preserva registros antigos ausentes na nova versão. Todos os upserts e as verificações finais são executados em uma única transação; qualquer erro provoca rollback. `data_insercao` é preservada e `data_atualizacao` registra o upsert mais recente. O procedimento de migração, backup e reversão está documentado na [task `catalogo-upsert-atomico`](../../../tasks/alteracoes-no-banco-de-dados/catalogo-upsert-atomico/README.md). A versão atual e a atualização do CSV OCDS estão documentadas na [task `catalogo-caracteristicas-ocds`](../../../tasks/alteracoes-no-banco-de-dados/catalogo-caracteristicas-ocds/README.md).

## Histórico e auditoria

Ao final de `carrega-dados.R`, o loader:

- conta registros antes e depois da carga nas tabelas `contratante`, `fornecedor`, `contratacao`, `item_homologado` e `item_licitado`;
- infere `ano`, `mes`, `quinzena` e `periodo_label` a partir dos caminhos de origem;
- adiciona uma linha por tabela em [`historico-cargas.csv`](historico-cargas.csv).

Campos importantes do histórico:

| Campo | Descrição |
| --- | --- |
| `id_execucao` | Identificador derivado de data/hora, rotina e período. |
| `periodo_label` | Período da coleta, por exemplo `2026-04/QUINZENA-1`. |
| `tabela` | Tabela auditada. |
| `contagem_antes` / `contagem_depois` | Total de linhas antes e depois da carga. |
| `delta` | Diferença entre as contagens. |
| `diretorio_data_package` | Diretório `DATA` usado como origem, quando inferido. |

Use [`historico.sql`](historico.sql) para consultas exploratórias e validações manuais no banco. Ele não substitui o histórico em CSV, mas ajuda a verificar contagens e registros recentes.
