# Coletores

Scripts de coleta de dados da API do PNCP. Cada etapa segue o mesmo padrão: um **script R** com a lógica de coleta e um **wrapper Bash** que cria a sessão `screen`, define o diretório de saída e registra o log.

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

1. Invoca cada wrapper na ordem correta.
2. Aguarda o término de cada `screen` antes de avançar.
3. Solicita confirmação antes de sobrescrever saídas existentes (exceto na etapa de resultados).

## utils.R

Funções compartilhadas por todos os scripts R:

- `coleta_endpoint()` — faz a requisição GET ao endpoint com retry e timeout configuráveis.
- `coleta()` — itera sobre uma lista de endpoints, consolida dados, erros e monitoramento.
- `salva_resultados()` — persiste os três CSVs de saída no diretório especificado.
