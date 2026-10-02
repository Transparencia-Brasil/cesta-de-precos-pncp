# TODO

1. baixar todos os dados com script R em `/src`
2. Refatorar notebook python

Regra geral:

- Hierarquia: Contratações > itens > medicamentos > resultados
- Carregar 1 dataset de contratações, itens, medicamentos e resultados (DE UM MESMO PERÍODO)
- buscar cnpj nas contratações
- Fazer join das contrataçoes dos cnpjs encontrados com seus respectivos itens (atenção com medicamentos, que possuem resultados)
- Fazer join com resultados (de medicamentos)
- salvar resultados em um diretório `tasks/analise-unidades-compradoras/output` com o nome do período (ex: `2023-01-QUINZENA-1`)

Para CNPJ que começa com "18.729.020" -> usar uma regex tipo  `^18729020*` para buscar todos os cnpjs que começam com esse número.
