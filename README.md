# Cesta de Preços - PNCP

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.8%2B-blue.svg)](https://www.python.org/downloads/release/python-380/)
[![R](https://img.shields.io/badge/R-4.0%2B-blue.svg)](https://cran.r-project.org/bin/windows/base/old/4.0.0/)

## Objetivo

Este repositório comporta processamento dos dados de contratações do PNCP para uso em uma aplicação de cesta de preços.

## Replicação

### Coletores (`/src/ETL`)

#### Coleta, filtragem e classificação de contratações de medicamentos no PNCP

* O script `run-coletores.sh` gerencia a execução dos scripts de coleta e classificação de dados das APIs do PNCP, localizados em `src/ETL/coletores` e `src/ETL/classificador`. Recebe como parâmetros a data de início, fim e um *alias* para o subdiretório de saída. As etapas são:

  1. **Coleta de contratações**: Realizada pelo script `src/ETL/coletores/coleta-contratacoes.R`, gerenciado por `coletor-contratacoes.sh`, que recebe como parâmetros a data de início, fim e um *alias* para o subdiretório de saída.

  2. **Coleta de itens contratados**: Realizada pelo script `src/ETL/coletores/coleta-itens-contratacoes.R`, gerenciado por `coletor-itens-contratacoes.sh`, com os mesmos parâmetros de data e *alias*.

  3. **Filtragem e classificação de medicamentos**: Realizada pelo script `src/ETL/classificador/classifica-medicamentos.R`, gerenciado por `classificador.sh`, também utilizando os parâmetros de data e *alias*. Os resultados das filtragens de medicamentos são salvos junto com seus embeddings no mesmo diretório de itens em um arquivo CSV chamado `medicamentos.csv`.

  4. **Resultado das contratações de medicamentos**: Realizada pelo script `src/ETL/coletores/coleta-resultados.R`, gerenciado por `rsc/ETL/coletor-resultados.sh`, com os mesmos parâmetros de data e *alias*.

##### Exemplo de execução

```bash
cd src/ETL
./run-coletores.sh "2025-01-Q1" "2025-01-01" "2025-01-15" | tee run-coletores-2025-01-Q1.log
```

* PARÂMETROS:
  * `2025-01-Q1`: *Alias* para o subdiretório onde os dados e o arquivo de log serão salvos.
  * `2025-01-01`: Data de início da coleta.
  * `2025-01-15`: Data de fim da coleta.
  * `run-coletores-2025-01-Q1.log`: Arquivo de log que armazenará todas as mensagens de saída e erros gerados durante a execução do script.

***

### TASKS (`/tasks`)

#### dados-de-teste

* Gere amostras aleatórias de medicamentos para rotulagem manual utilizando o script `seleciona-dados-para-rotulacao-manual.R`.

#### experimento-LLM

* Realize análises de similaridade e embeddings utilizando os notebooks disponíveis na pasta `src`. O notebook `analise-de-similaridade-com-embeddings.ipynb` é um exemplo de como utilizar o modelo LLM para gerar embeddings e calcular similaridade entre os itens.

#### filtros-dinamicos

* Execute a análise de quantidade de filtros com o arquivo `analise-da-quantidade-de-filtros.qmd`. Os filtros são utilizados no front end do painel de cestas de preços.

#### preprocessamento

* Utilize os scripts disponíveis na pasta `src` para realizar o pré-processamento dos dados.

#### unifica-dados

* Unifique e trate os dados de contratações utilizando os scripts disponíveis na pasta `src`. Dadso unificados são salvos na pasta `data` e foram utilizados para a primeira ingestão dos dados no banco de dados Postgres.

## Responsáveis

* [Luiz Fonseca](https://github.com/fonluiz)
* [Raul Durlo](https://github.com/rdurl0)
* [Talita Lôbo](https://github.com/talitalobo)
