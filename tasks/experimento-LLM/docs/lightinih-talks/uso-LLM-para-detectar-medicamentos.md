# Resumo da fala

- Contextualização do desafio do PNCP: diferenciar itens de medicamento em grandes volumes de compras públicas.
- Uso de embeddings com um modelo LLM para comparar descrições do PNCP com o catálogo CATMAT.
- Automação do pipeline de detecção, do pré-processamento ao salvamento dos rótulos em `medicamentos.csv`.
- Impactos para dados abertos: priorização de casos relevantes para análise jornalística e auditorias.

## Uso de LLM para detectar medicamentos nas compras do PNCP

Bom dia! Hoje vou mostrar como aplicamos modelos de linguagem para identificar, dentro das compras do PNCP, quais itens são de fato medicamentos. Esse problema parece trivial, mas o volume de dados e a forma heterogênea das descrições tornam tudo mais complexo: variações de escrita, siglas e abreviações atrapalham filtros manuais ou regras fixas.

O pipeline que construímos começa com a seleção dos itens do PNCP e a leitura do catálogo oficial de medicamentos (CATMAT). A primeira triagem é léxica: limpamos acentos, padronizamos caixa, removemos stopwords em português e buscamos palavras que indiquem um possível Padrão Descritivo de Material (PDM). Isso reduz o universo a itens candidatas.

Com essa amostra em mãos, entra o modelo de linguagem. Usamos o `Snowflake/snowflake-arctic-embed-l-v2.0`, acessado via Sentence Transformers, para transformar as descrições dos itens e do catálogo em embeddings. Guardamos o vetor do catálogo em cache (`catalogo-vetorizado.csv`) e reprocessamos apenas quando o modelo muda ou o cache fica incompatível.

Para cada item candidato, calculamos a similaridade de cosseno com os medicamentos do catálogo que compartilham o mesmo PDM. O par com maior similaridade define o código BR sugerido. Se a pontuação ultrapassa 0,5 — limiar definido nos experimentos — rotulamos o item como medicamento. No final, gravamos `medicamentos.csv` junto aos demais resultados do ciclo de coleta.

Do ponto de vista técnico, vale destacar três utilidades: (1) conectamos Python e R no pipeline geral via bash, reaproveitando diretórios e logs existentes; (2) parametrizamos o modelo por variável de ambiente para facilitar futuros testes; (3) tratamos dados problemáticos com warnings controlados para não interromper a execução.

E o que isso significa para quem analisa gastos públicos? Para jornalistas de dados, conseguimos priorizar contratos sensíveis, cruzar com variações de preço e contar histórias baseadas em evidências. Para desenvolvedores, criamos um componente reaproveitável que pode ser orquestrado em lotes quinzenais e adaptado a outros catálogos.

Encerrando: LLMs não substituem o trabalho investigativo, mas funcionam como radar. Eles reduzem o ruído e liberam tempo para investigar os casos que realmente importam. Com esse pipeline, novas descobertas sobre compras de medicamentos no Brasil ficam mais acessíveis.

## Descrição da atividade

Apresentei, em fala de dez minutos, como um pipeline baseado em embeddings e LLM classifica itens do PNCP como medicamentos para acelerar análises técnicas e jornalísticas.
 