# Instruções para agentes de IA neste repositório

Este repo implementa um ETL para coletar e preparar dados de contratações do PNCP focados em medicamentos, com orquestração em Bash, coleta/processamento em R e uma etapa de classificação/filtragem com Python. Use estas diretrizes para manter compatibilidade com os fluxos atuais.

## Visão geral da arquitetura e fluxos
- Pipeline principal (arquivo-chave: `src/ETL/run-coletores.sh`):
  1) Coleta de contratações → `src/ETL/coletores/coletor-contratacoes.sh` chama `coleta-contratacoes.R`.
  2) Coleta de itens → `src/ETL/coletores/coletor-itens.sh` chama `coleta-itens.R`.
  3) Classificação/filtragem de medicamentos → `src/ETL/classificador/filtra-medicamentos.sh` (usa Python/embeddings; ver abaixo).
  4) Coleta de resultados → `src/ETL/coletores/coletor-resultados.sh` chama `coleta-resultados.R`.
- Empacotamento pós-pipeline no próprio `run-coletores.sh`: copia CSVs e logs para `coleta/data-package/<ANO>/<MÊS>/<QUINZENA>/{DATA,LOG}`.
- Verificações de carga/volume: `src/ETL/loaders/historico.sql` traz consultas de sanity check em tabelas do DW `medicamentos_transparentes.public` (ex.: `contratante`, `fornecedor`, `contratacao`, `item_homologado`, `item_licitado`).

## Convenções e padrões do projeto
- Alias de coleta (padrão oficial): `AAAA-MM/QUINZENA-1|2` (ex.: `2025-08/QUINZENA-1`). Define a raiz dos diretórios de saída:
  - `coleta/contratacoes/<ALIAS>` | `coleta/itens/<ALIAS>` | `coleta/resultados/<ALIAS>`
- Saídas esperadas por etapa (mantenha esses nomes ao criar/alterar scripts):
  - `dados.csv`, `erros.csv`, `monitoramento.csv` e, para itens, `medicamentos.csv`.
- Execução desacoplada: scripts de coletor criam uma sessão `screen` (nomeado com datas) e salvam logs em `<DIR_SAIDA>/run-<coletor>-<periodo>.log`. O orquestrador aguarda encerramento das screens quando necessário.
- Passagem de parâmetros: coletores R são invocados via `Rscript.exe` com args posicionais e/ou `PATH_OUTPUT_DIR=...`. Preserve esse formato (vide `coletor-*.sh`).
- Normalização Windows/WSL: use `dos2unix` nos `.sh` ao trabalhar no Windows; os scripts assumem `screen` e `tree` disponíveis (ambiente Linux/WSL). `Rscript.exe` é usado explicitamente para compatibilidade com R no Windows.

## Integrações e dependências
- R 4.0+: scripts em `src/ETL/coletores/*.R` e loaders em `src/ETL/loaders/*.R`. Temas/estilo gráfico em `setup/rsetup.R` (não crítico para o ETL).
- Python 3.8+: classificador em `src/ETL/classificador/filtra-medicamentos.py` (requisitos em `requirements.txt`: `sentence-transformers`, `nltk`, `pandas`, etc.). Detalhes:
  - Modelo de embedding padrão: `Snowflake/snowflake-arctic-embed-l-v2.0`.
  - Parametrização opcional (sem quebrar rotinas existentes):
    - `EMBEDDING_MODEL` para trocar o modelo de embeddings.
    - `CATALOGO_VETORIZADO_PATH` para sobrescrever o caminho do cache de embeddings do catálogo.
  - Cache dos embeddings do catálogo (padrão): `data/catmat/catalogo-vetorizado.csv`.
  - Saída gerada: `coleta/itens/<ALIAS>/medicamentos.csv` com colunas incluindo `codigo_br` e `similaridade`.
- Banco/warehouse (PostgreSQL): consultas de auditoria em `src/ETL/loaders/historico.sql`. Se criar novos loaders, siga o padrão de contagens/“últimos inseridos”. Documentar DSN/cliente quando disponível.

## Como rodar localmente (resumo operacional)
- Pré-passos no Windows/WSL: garantir `screen`, `tree`, R (acessível como `Rscript.exe`) e Python com deps instaladas. Converter finais de linha dos `.sh` se necessário.
- Execução típica do pipeline:
  - `src/ETL/run-coletores.sh "<ALIAS>" "<AAAA-MM-DD>" "<AAAA-MM-DD>"` → cria screens para cada etapa e escreve logs nos diretórios de `coleta/...`.
  - O empacotamento final moverá CSVs e logs para `coleta/data-package/...` conforme a data inicial define `QUINZENA`.
- Logs: procure o arquivo mais recente em `src/ETL/**/*.log` e nos diretórios de saída de cada etapa.
  - Observação: `src/ETL/classificador/filtra-medicamentos.sh` referencia um caminho específico do Python no Windows (`/mnt/c/Users/.../WindowsApps/python.exe`); ajuste conforme seu ambiente.

## Ao editar/criar etapas
- Scripts novos devem seguir nomes/padrão: `coletor-*.sh` que chamam `Rscript.exe <script>.R` ou `python` e escrevem em `<base>/<ALIAS>/{dados,erros,monitoramento}.csv`.
- Orquestração: adicione a etapa em `src/ETL/run-coletores.sh` e ajuste a parte de empacotamento para copiar os novos artefatos.
- Idempotência controlada: `run-coletores.sh` pergunta antes de sobrescrever saídas existentes (exceto resultados). Preserve essa UX ao alterar.

## Exemplos úteis
- Estrutura de saída esperada após rodar uma quinzena:
  - `coleta/contratacoes/<ALIAS>/{dados,erros,monitoramento}.csv`
  - `coleta/itens/<ALIAS>/{dados,erros,monitoramento,medicamentos}.csv`
  - `coleta/resultados/<ALIAS>/{dados,erros,monitoramento}.csv`
  - `coleta/data-package/<ANO>/<MÊS>/<QUINZENA>/{DATA,LOG}` com cópias dos CSVs e logs.

## Testes rápidos
- Classificador (smoke test): veja `src/ETL/dados-de-teste/classificador/README.md` para rodar um teste mínimo com fixtures (`itens-sample.csv`, `catmat-sample.csv`).
- Parametrização opcional: defina `EMBEDDING_MODEL` e/ou `CATALOGO_VETORIZADO_PATH` para testar outros modelos/locais de cache; o script revectoriza se detectar incompatibilidade do cache com o modelo.

---
Notas para evoluções futuras:
- Documentar DSN/cliente PostgreSQL para uso do `historico.sql` quando houver padronização definida.
- Se futuramente outro modelo de embedding for adotado, basta definir `EMBEDDING_MODEL` no ambiente; o fluxo atual permanece inalterado por padrão.
