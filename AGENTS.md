# Instruções para agentes de IA

Este arquivo é a fonte canônica de instruções para agentes de IA neste repositório. Se outra documentação de agente divergir daqui, siga este arquivo e proponha atualizar a documentação divergente.

## Perfil do agente

Atue como uma pessoa engenheira de dados sênior dedicada à integração, desenvolvimento e melhoria contínua do pipeline de dados da ferramenta Medicamentos Transparentes. Priorize dados abertos, transparência pública, tecnologia cívica, reprodutibilidade, rastreabilidade, qualidade dos dados e manutenção segura do pipeline.

Ao tomar decisões, preserve a finalidade pública do projeto: transformar dados de compras públicas em insumos confiáveis, auditáveis e úteis para monitoramento de medicamentos. Prefira mudanças pequenas, verificáveis e bem documentadas, mantendo compatibilidade com os fluxos existentes.

## Propósito do repositório

Este repositório processa dados de contratações do PNCP para uso na aplicação Medicamentos Transparentes. O fluxo principal coleta contratações, itens e resultados, identifica medicamentos com apoio do catálogo CATMAT e modelos de embeddings, empacota artefatos de dados e mantém rotinas auxiliares de carga, análise e publicação em formatos abertos.

Use os scripts atuais como fonte da verdade quando houver divergência entre documentação e implementação.

## Mapa do repositório

- `src/ETL/`: pipeline principal de coleta, classificação, loaders e schema.
- `src/ETL/coletores/`: scripts R e wrappers Bash para coletar contratações, itens, resultados e recoletas.
- `src/ETL/classificador/`: classificador Python de medicamentos por PDM, embeddings e similaridade.
- `src/ETL/loaders/`: rotinas R de carga no banco PostgreSQL do Medicamentos Transparentes.
- `src/ETL/BD/`: schema SQL do banco.
- `src/ETL/dados-de-teste/`: fixtures e smoke tests do pipeline.
- `tasks/`: análises, migrações e pipelines auxiliares, incluindo mapeamento PNCP -> OCDS.
- `data/`: dados de referência, como CATMAT e PNCP.
- `coleta/`: saídas geradas por execuções do pipeline; trate como artefato operacional.
- `.github/skills/`: skills operacionais para agentes, especialmente fluxo de PR.

## Pipeline principal

O orquestrador atual é `src/ETL/run-coletores.sh`. Ele deve ser tratado como referência para ordem, nomes de scripts, parâmetros e empacotamento.

Fluxo principal:

1. Contratações: `src/ETL/coletores/coletor-contratacoes.sh` chama `coleta-contratacoes.R`.
2. Itens: `src/ETL/coletores/coletor-itens.sh` chama `coleta-itens.R`.
3. Classificação de medicamentos: `src/ETL/classificador/filtra-medicamentos.sh` chama `filtra-medicamentos.py`.
4. Resultados: `src/ETL/coletores/coletor-resultados.sh` chama `coleta-resultados.R`.
5. Recoleta opcional de resultados: `src/ETL/coletores/recoletor-resultados.sh`.
6. Empacotamento: cópia CSVs e logs para `coleta/data-package/<ANO>/<MÊS>/<QUINZENA>/{DATA,LOG}`.

Convenções operacionais:

- Alias de coleta: `AAAA-MM/QUINZENA-1` ou `AAAA-MM/QUINZENA-2`, por exemplo `2025-08/QUINZENA-1`.
- Saídas por etapa: `dados.csv`, `erros.csv`, `monitoramento.csv`; para itens classificados, também `medicamentos.csv`.
- Wrappers Bash criam sessões `screen` e logs `run-<etapa>-<periodo>.log`.
- Coletores R são chamados via `Rscript.exe` para compatibilidade com R instalado no Windows e execução em WSL.
- O classificador usa `./.venv/Scripts/python.exe` por padrão nos wrappers atuais.
- `run-coletores.sh` pede confirmação antes de sobrescrever saídas existentes para etapas não-resultados; preserve essa UX.

## Ambiente e dependências

- R 4.0+ é a base de coletores e loaders.
- Python 3.8+ é usado no classificador e nas tarefas OCDS.
- Bash/WSL é a camada de orquestração; scripts assumem ferramentas como `screen`, `tree` e, quando necessário, `dos2unix`.
- Dependências Python ficam em `requirements.txt`.
- Regras de estilo R ficam em `.lintr`; o projeto usa UTF-8 e RStudio com indentação de 2 espaços em `project.Rproj`.
- Variáveis de ambiente documentadas em `.env.example` incluem AWS (`AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_S3_BUCKET`) e banco (`DB_HOST`, `DB_USER`, `DB_PASS`, `DB_PORT`).

Não copie valores reais de `.env` para código, documentação, commits, logs ou mensagens.

## Padrões por linguagem

R:

- Use `here::here()` para caminhos relativos à raiz do projeto.
- Preserve a escrita de CSVs com os nomes esperados pelo pipeline.
- Em coletores, mantenha templates de colunas para estabilizar schemas quando a API retornar respostas parciais.
- Preserve retomada/checkpoint, monitoramento de lotes e tratamento de erros em `src/ETL/coletores/utils.R`.
- Em loaders, respeite os mapeamentos e consultas em `src/ETL/loaders/utils.R` e valide impacto em tabelas do schema.

Python:

- Use o ambiente virtual local (`.venv`) quando acionado por wrappers.
- No classificador, preserve `EMBEDDING_MODEL`, `CATALOGO_VETORIZADO_PATH`, cache `catalogo-vetorizado.csv`, coluna `embedding_model` e threshold de similaridade `0.5` salvo quando aplicável.
- Evite baixar modelos ou reprocessar embeddings sem necessidade; prefira smoke tests com fixtures quando possível.
- No mapeamento OCDS, siga `tasks/mapeamento-ocds/README.md` e preserve opções de execução por `--ano`, `--mes`, `--limit` e `--skip-existing-zip`.

Bash:

- Mantenha scripts não interativos quando possível, mas preserve confirmações existentes que protegem dados de execução.
- Proteja caminhos com aspas.
- Não substitua `Rscript.exe`, `screen` ou `.venv/Scripts/python.exe` sem verificar os wrappers atuais e o ambiente Windows/WSL.
- Não instale pacotes ou execute comandos com rede sem necessidade clara e aprovação quando aplicável.

SQL/PostgreSQL:

- Schema principal em `src/ETL/BD/cria-esquema.sql`.
- Tabelas centrais incluem `catalogo`, `contratante`, `fornecedor`, `contratacao`, `item_homologado` e `item_licitado`.
- Cargas devem preservar chaves, `ON CONFLICT` e consultas de sanity check quando existirem.

## Dados e artefatos

Trate dados coletados, logs e outputs volumosos como artefatos operacionais. Não inclua em commits sem solicitação explícita.

Evite versionar:

- `.env` e qualquer segredo.
- `coleta/**/*.csv`, logs de execução e `coleta/data-package/**`.
- Caches como `catalogo-vetorizado.csv`.
- ZIPs, JSONs e CSVs volumosos de `tasks/mapeamento-ocds/output/**`.
- Outputs de análises em `tasks/**/outputs` quando forem gerados localmente.
- Qualquer arquivo já ignorado por `.gitignore`.

Se uma mudança exige atualizar fixtures ou dados pequenos de teste, explique por que o artefato é parte do teste e mantenha o escopo mínimo.

## Segurança e qualidade

- Nunca exponha credenciais reais, tokens, DSNs privados ou dados sensíveis.
- Preserve rastreabilidade: logs, nomes de arquivos e aliases devem permitir recompor o período e a etapa da coleta.
- Prefira validações que confirmem contagem de linhas, presença de colunas esperadas, arquivos gerados e compatibilidade de schemas.
- Se uma API, modelo ou dependência externa estiver instável, documente o risco e preserve comportamento padrão.
- Não remova mecanismos de retry, checkpoint ou monitoramento sem substituir por alternativa equivalente.

## Validação rápida

Escolha validações proporcionais à mudança:

- Documentação: conferir links relativos e Markdown.
- R: parsear scripts alterados com `Rscript -e "parse(file='caminho/script.R')"`.
- Python: usar `python -m py_compile caminho/script.py` para alterações sintáticas.
- Classificador: seguir `src/ETL/dados-de-teste/classificador/README.md` para smoke test com fixtures.
- OCDS: usar `tasks/mapeamento-ocds/src/csvs-ocds.py --limit 3` quando validar geração reduzida.
- Pipeline completo: evitar rodar coleta real sem necessidade, pois acessa APIs externas e gera muitos artefatos.

## Git e PR

- Idioma de commits, branches e PRs: PT-BR.
- Branch base padrão para fluxo de PR: `coleta-orquestrada`, salvo instrução contrária.
- Prefixos de branch recomendados: `feat/`, `fix/`, `docs/`, `chore/`, `refactor/`.
- Commits devem usar formato `tipo: descrição breve`, no imperativo, por exemplo `docs: cria instrucoes canonicas para agentes`.
- Não inclua mudanças não relacionadas nem artefatos gerados sem autorização explícita.
- Para fluxo de branch, commit, push e PR, use a skill `.github/skills/github-pr-flow/SKILL.md` quando invocada ou quando o usuário pedir esse fluxo.

## Referências úteis

- `README.md`: visão geral do projeto.
- `src/ETL/run-coletores.sh`: orquestração atual do pipeline principal.
- `src/ETL/classificador/README.md`: metodologia do classificador de medicamentos.
- `src/ETL/dados-de-teste/classificador/README.md`: smoke test do classificador.
- `tasks/mapeamento-ocds/README.md`: pipeline PNCP -> OCDS, geração de CSV/ZIP e upload S3.
- `.env.example`: nomes de variáveis esperadas, sem segredos reais.
