# Coletores

Scripts de coleta de dados da API do PNCP. Cada etapa segue o mesmo padrão: um **script R** com a lógica de coleta e um **wrapper Bash** que cria a sessão `screen`, define o diretório de saída e registra o log.

Os scripts R carregam os templates versionados de [`../template/templates`](../template/templates), atualizados pelo validador antes da execução do orquestrador principal.

## Estrutura

```
coletores/
├── utils.R                    # Funções base compartilhadas por todos os coletores
├── coleta-contratacoes.R      # Coleta contratações por período
├── coletor-contratacoes.sh    # Wrapper Bash para coleta-contratacoes.R
├── coleta-itens.R             # Coleta itens a partir das contratações
├── coletor-itens.sh           # Wrapper Bash para coleta-itens.R
├── coleta-resultados.R        # Coleta resultados (homologação) a partir dos itens
├── coletor-resultados.sh      # Wrapper Bash para coleta-resultados.R
├── recoleta-resultados.R      # Recoleta resultados ainda pendentes no banco
└── recoletor-resultados.sh    # Wrapper Bash para recoleta-resultados.R
```

## Fluxo de dados

A coleta é encadeada: cada etapa depende da saída da anterior.

```
coleta-contratacoes.R
  └─► coleta/contratacoes/<ALIAS>/dados.csv
        └─► coleta-itens.R
              └─► coleta/itens/<ALIAS>/dados.csv
                    └─► [classificador] → medicamentos.csv
                          └─► coleta-resultados.R
                                └─► coleta/resultados/<ALIAS>/dados.csv
                                      └─► recoleta-resultados.R  (opcional)
                                            └─► coleta/resultados/<ALIAS>/recoleta/
```

### Etapas

| Etapa | Script R | Endpoint PNCP |
|---|---|---|
| Contratações | `coleta-contratacoes.R` | `consultarContratacaoPorDataUltimaAtualizacao` |
| Itens | `coleta-itens.R` | `pesquisarCompraItem` |
| Resultados | `coleta-resultados.R` | `recuperarResultados` |
| Recoleta de resultados | `recoleta-resultados.R` | `recuperarResultados` (itens pendentes no banco) |

### Saídas por etapa

Cada etapa gera 3 arquivos no diretório de saída:

- `dados.csv` — registros coletados.
- `erros.csv` — endpoints que retornaram erro e a respectiva mensagem.
- `monitoramento.csv` — metadados de duração por lote.

### Benefícios, margens, desempate e descontos

Os templates de itens e resultados preservam os 18 campos usados em
`item_homologado`. Oito campos vêm do endpoint de `itens_licitados`
(`incentivoProdutivoBasico`, conteúdo nacional, aplicabilidade, tipo e
percentuais de margem) e dez vêm do endpoint de resultados (benefício ME/EPP,
margem aplicada, amparos legais, desempate e `percentualDesconto`).

Quando a API omite um campo ou o devolve como nulo, o template mantém a coluna
no `dados.csv` com valor vazio. Assim, o schema dos artefatos permanece estável
sem substituir dados da API por fontes externas.

## Parâmetros dos wrappers Bash

Todos os wrappers recebem os mesmos três argumentos posicionais:

```bash
./coletor-<etapa>.sh ALIAS_COLETA PRIMEIRO_DIA ULTIMO_DIA
# Exemplo:
./coletor-contratacoes.sh "2026-03/QUINZENA-1" "PRIMEIRO_DIA=2026-03-01" "ULTIMO_DIA=2026-03-15"
```

- `ALIAS_COLETA` — identifica a coleta e define o subdiretório de saída dentro de `coleta/`.
- `PRIMEIRO_DIA` / `ULTIMO_DIA` — janela temporal da coleta, no formato `YYYY-MM-DD`.

Os wrappers repassam esses argumentos ao script R via `Rscript.exe` (compatibilidade com R no Windows executado em WSL).

## Orquestrador principal

Para executar a cadeia completa, use `src/ETL/run-coletores.sh`. Ele:

1. Atualiza os templates dos coletores a partir da documentação OpenAPI oficial do PNCP.
2. Invoca cada wrapper na ordem correta.
3. Aguarda o término de cada `screen` antes de avançar.
4. Solicita confirmação antes de sobrescrever saídas existentes (exceto na etapa de resultados).

## utils.R

Funções compartilhadas por todos os scripts R:

- `coleta_endpoint()` — faz a requisição GET ao endpoint com retry e timeout configuráveis.
- `coleta()` — itera sobre uma lista de endpoints, consolida dados, erros e monitoramento.
- `salva_resultados()` — persiste os três CSVs de saída no diretório especificado.

### Controle de taxa e novas tentativas

Todas as etapas que usam `coleta_endpoint()` compartilham a mesma política por
processo R. A variável de ambiente `PNCP_INTERVALO_REQUISICOES_SEGUNDOS`
define o intervalo mínimo entre chamadas ao PNCP, em segundos. Quando ela não
é informada, o intervalo padrão é de 2 segundos.

Respostas transitórias usam até 15 novas tentativas com espera exponencial e
jitter, limitada a 60 segundos. Quando o PNCP envia o cabeçalho `Retry-After`,
o tempo indicado pela API tem precedência. Na descoberta inicial das
contratações, todas as modalidades são consultadas e seus erros são salvos em
`erros.csv`; se alguma falhar, a paginação não é iniciada para evitar uma
coleta incompleta.

Respostas HTTP 204 são tratadas como sucesso sem registros em contratações,
itens e resultados. Elas não geram linhas em `dados.csv` nem entradas em
`erros.csv`. Na descoberta de contratações, uma modalidade com HTTP 204 recebe
zero registros e zero páginas, e a coleta continua com as demais modalidades.
Outros status de sucesso com corpo vazio continuam sendo tratados como erro.

O controle de taxa vale apenas dentro de um processo R. Não execute coletores
simultâneos contra o PNCP sem coordenar o limite total de requisições.
