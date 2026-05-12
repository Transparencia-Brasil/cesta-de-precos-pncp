# ETL

Pipeline principal de coleta, classificação, empacotamento e carga dos dados do PNCP usados pelo Medicamentos Transparentes.

O orquestrador atual é [`run-coletores.sh`](run-coletores.sh). Ele executa, nesta ordem:

1. coleta de contratações;
2. coleta de itens;
3. classificação de itens de medicamentos;
4. coleta de resultados;
5. empacotamento dos CSVs e logs em `coleta/data-package/`;
6. carga opcional no banco;
7. recoleta opcional de resultados.

Use o alias de coleta no formato `AAAA-MM/QUINZENA-1` ou `AAAA-MM/QUINZENA-2`, por exemplo:

```bash
bash src/ETL/run-coletores.sh 2025-08/QUINZENA-1 2025-08-01 2025-08-15
```

## Detalhes por etapa

- [Coletores](coletores/README.md): contratações, itens, resultados e recoleta.
- [Classificador](classificador/README.md): identificação de medicamentos com CATMAT e embeddings.
- [Loaders](loaders/README.md): carga dos dados tratados no PostgreSQL.
- [Banco de dados](BD/README.md): schema e estrutura das tabelas.
- [Dados de teste](dados-de-teste/classificador/README.md): smoke test do classificador.

## Mapeamento OCDS

O último passo do ETL é o mapeamento PNCP -> OCDS, mantido hoje em [`tasks/mapeamento-ocds/`](../../tasks/mapeamento-ocds/) e documentado em [`tasks/mapeamento-ocds/README.md`](../../tasks/mapeamento-ocds/README.md).

Esse passo ainda não está integrado ao `run-coletores.sh`; a integração ao fluxo principal do ETL está prevista como evolução futura.
