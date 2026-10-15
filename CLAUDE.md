# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Leia [AGENTS.md](AGENTS.md) primeiro.** Ele é a fonte canônica de instruções (perfil, convenções por linguagem, dados que não devem ser versionados, Git/PR em PT-BR, base de PR `coleta-orquestrada`). Este arquivo só complementa com comandos e arquitetura; em caso de conflito, `AGENTS.md` prevalece.

## Comandos

Execução do pipeline completo (WSL, a partir da raiz; acessa APIs reais do PNCP — só rode se pedido):

```bash
find . -name "*.sh" -exec dos2unix {} \;
cd src/ETL
./run-coletores.sh "2026-07/QUINZENA-1" "2026-07-01" "2026-07-15" | tee log/run-coletores-2026-07-QUINZENA-1.log
```

Argumentos posicionais: `ALIAS_COLETA PRIMEIRO_DIA ULTIMO_DIA`. O script é interativo (pergunta sobre carga no banco, recoleta e sobrescrita), então não roda sem TTY. O nome do log `src/ETL/log/run-coletores-<AAAA>-<MM>-<QUINZENA-N>.log` importa: o empacotador procura exatamente esse nome para copiar para o data-package.

Validações sem rede/banco:

```bash
# Parse de R alterado
Rscript -e "parse(file='src/ETL/loaders/utils.R')"
# Testes do loader (dados fictícios, sem PostgreSQL)
Rscript src/ETL/dados-de-teste/testa-loader-csv-tipado.R
Rscript src/ETL/dados-de-teste/testa-loader-catalogo.R
# Validar CATMAT real sem gravar no banco
Rscript src/ETL/loaders/carrega-catalogo.R data/catmat/catmat-1.rds --validar-apenas
# Python
python -m py_compile src/ETL/classificador/filtra-medicamentos.py
# Smoke test do classificador (baixa/usa modelo de embeddings; ver README da pasta)
.venv/Scripts/python.exe src/ETL/classificador/filtra-medicamentos.py src/ETL/dados-de-teste/classificador/itens-sample.csv src/ETL/dados-de-teste/classificador/catmat-sample.csv
```

Validador de templates (consulta só a documentação OpenAPI do PNCP, não endpoints de coleta): `bash src/ETL/template/run-validador-template.sh` (usa `PYTHON_BIN`, padrão `./.venv/Scripts/python.exe`, com fallback para `python`).

## Arquitetura (visão que exige ler vários arquivos)

**Encadeamento por arquivos, não por chamadas.** Cada etapa lê o CSV da anterior em `coleta/<etapa>/<ALIAS_COLETA>/`:
contratações `dados.csv` → itens (`coleta-itens.R` recebe o `dados.csv` de contratações) → classificador gera `itens/.../medicamentos.csv` → resultados recebe `medicamentos.csv`. O orquestrador detecta término de etapa pela existência desses arquivos e por polling de `screen -list`; por isso nomes de arquivos e de screens (`coletor-<etapa>-<PRIMEIRO_DIA>-ate-<ULTIMO_DIA>`) são contrato entre scripts.

**Wrappers Bash** recebem args no formato `CHAVE=valor` (ex.: `ALIAS_COLETA=2026-07/QUINZENA-1`) e removem o prefixo com `sed 's/^[^=]*=//'`. Cada wrapper faz `cd` para a raiz do projeto, cria a screen e redireciona a saída do `Rscript.exe` para `run-coletor-<etapa>-*.log` no diretório de saída.

**Motor de coleta genérico** em `src/ETL/coletores/utils.R`: `coleta(endpoints, output_dir, tamanho_lote, template)` processa endpoints em lotes, gravando parciais em `<output_dir>/temp/`. A retomada (`checkpoint()`) compara a coluna `endpoint` já salva com a lista pedida — toda linha coletada precisa carregar `endpoint`. `salva_resultados()` copia `dados/erros/monitoramento.csv` para o diretório final e apaga `temp/`. Variáveis `PATH_*` são globais (`<<-`).

**Templates de schema** (`src/ETL/template/templates/template-*.csv`) fixam colunas das respostas da API. `run-coletores.sh` roda o validador antes de coletar; `atualiza-templates.py` reescreve os templates a partir do OpenAPI preservando campos legados para compatibilidade com CSVs históricos e loaders. O dicionário de dados fica em `src/ETL/template/README.md`.

**Classificador** (`filtra-medicamentos.py`): detecta o PDM na descrição do item, vetoriza o catálogo CATMAT (cache `catalogo-vetorizado.csv`, invalidado se `embedding_model`/hash mudar) e marca `medicamento = similaridade >= 0.5`. Modelo padrão via `EMBEDDING_MODEL` (`Snowflake/snowflake-arctic-embed-l-v2.0`).

**Empacotamento e carga**: após resultados, `run-coletores.sh` copia CSVs/logs para `coleta/data-package/<ANO>/<N - Mês>/<QUINZENA-N>/{DATA,LOG}` com nomes renomeados (`contratacoes.csv`, `itens-medicamentos.csv`, `itens-medicamentos-resultados.csv`, ...). Se escolhido, roda `Rscript.exe src/ETL/loaders/carrega-dados.R <contratacoes> <medicamentos> <resultados>`, que lê com tipagem via `le_csv_pncp()` (`loaders/utils.R`), monta chaves a partir de `endpoint`, insere no PostgreSQL e registra contagens antes/depois em `loaders/historico-cargas.csv` (`utils-historico.R`).

**`tasks/`** são análises e pipelines auxiliares independentes (cada um com seu README), p.ex. `tasks/mapeamento-ocds/` (PNCP → OCDS, ZIP, upload S3). Não fazem parte do fluxo de `run-coletores.sh`.
