# Classificador de Medicamentos

## Visão geral

O script `filtra-medicamentos.py` identifica automaticamente quais itens de contratações públicas do [PNCP](https://pncp.gov.br/) são medicamentos. Para isso, compara as descrições textuais dos itens licitados com um catálogo de referência de medicamentos (CATMAT) utilizando **embeddings** gerados por um modelo de linguagem.

A saída é um arquivo `medicamentos.csv` contendo apenas os itens classificados como medicamentos, cada um associado ao código BR do item mais similar no catálogo.

## Conceitos-chave

### O que são embeddings?

Embeddings são representações numéricas (vetores) de textos geradas por modelos de linguagem. Textos com significados semelhantes produzem vetores próximos entre si no espaço vetorial. Isso permite comparar descrições textuais de forma quantitativa, mesmo quando a redação é diferente.

Por exemplo, as descrições _"Dipirona sódica 500mg comprimido"_ e _"Dipirona 500 mg comp."_ terão embeddings próximos, apesar das diferenças na grafia.

### Similaridade do cosseno

A métrica usada para comparar dois embeddings é a **similaridade do cosseno**, que mede o ângulo entre dois vetores. Quanto mais próximos os vetores, maior a similaridade (máximo = 1.0). Um limite (_threshold_) de **0,5** foi definido experimentalmente como o ponto que maximiza a acurácia da classificação.

## Tecnologias utilizadas

| Tecnologia | Papel |
|---|---|
| [Snowflake Arctic Embed L v2.0](https://huggingface.co/Snowflake/snowflake-arctic-embed-l-v2.0) | Modelo de linguagem que gera os embeddings das descrições textuais |
| [sentence-transformers](https://www.sbert.net/) | Biblioteca Python que carrega e executa o modelo de embedding |
| [NLTK](https://www.nltk.org/) | Remoção de stopwords em português durante o pré-processamento |
| [pandas](https://pandas.pydata.org/) / [NumPy](https://numpy.org/) | Manipulação de dados tabulares e computação vetorial |

### Por que Snowflake Arctic Embed?

O modelo `Snowflake/snowflake-arctic-embed-l-v2.0` foi escolhido por ser um modelo de embedding de alta qualidade, com suporte multilíngue (incluindo português), otimizado para tarefas de recuperação semântica. Ele diferencia entre embeddings de _consulta_ (query) e de _documento_, o que melhora a precisão da busca — no nosso caso, as descrições dos itens do PNCP são tratadas como consultas e as descrições do CATMAT como documentos.

> **Nota:** o modelo não é "treinado" pela Transparência Brasil. Utilizamos o modelo pré-treinado disponibilizado pela Snowflake no Hugging Face, aplicando-o diretamente (_zero-shot_) sobre os dados em português de contratações públicas.

## Metodologia

O processo de classificação segue quatro etapas:

### 1. Detecção de PDM (pré-filtragem textual)

Cada item do PNCP tem sua descrição normalizada (remoção de acentos, stopwords e conversão para minúsculas). Em seguida, verifica-se se a descrição contém palavras que correspondam a um **PDM** (Padrão Descritivo de Material) do catálogo CATMAT. Essa etapa funciona como filtro rápido: apenas itens cujo texto permite identificar um PDM específico seguem para a etapa de embeddings. Isso reduz drasticamente o volume de itens a serem vetorizados.

### 2. Vetorização (geração de embeddings)

As descrições dos itens candidatos e dos medicamentos do catálogo são transformadas em vetores numéricos pelo modelo de linguagem. Os embeddings do catálogo são calculados uma única vez e armazenados em cache (`catalogo-vetorizado.csv`), evitando reprocessamento nas execuções seguintes.

### 3. Comparação por similaridade

Para cada item candidato, seus embeddings são comparados **apenas** com os embeddings dos medicamentos do catálogo que possuem o mesmo PDM. A similaridade do cosseno é calculada, e o medicamento do catálogo com maior similaridade é selecionado como correspondência.

### 4. Classificação final

Itens cuja correspondência mais similar tenha similaridade **≥ 0,5** são classificados como medicamentos. Os demais são descartados.

```
Itens PNCP ──► Pré-filtragem por PDM ──► Vetorização ──► Similaridade do cosseno ──► medicamentos.csv
                    (textual)              (modelo LLM)       (threshold ≥ 0.5)
```

## Viabilidade técnica: métricas do experimento

A metodologia foi validada com um experimento sobre **1.000 itens rotulados manualmente** (642 medicamentos, 175 não-medicamentos, 183 incertos descartados), totalizando 817 itens processados.

| Métrica | Resultado |
|---|---|
| **Acurácia na detecção de medicamentos** (item é ou não medicamento) | **98%** |
| **Acurácia na identificação do código BR** (item correto do catálogo) | **86%** |

O threshold de 0,5 foi determinado por análise experimental como o valor que maximiza a acurácia. Detalhes completos estão nos notebooks em [`tasks/experimento-LLM/src/`](../../../tasks/experimento-LLM/src/).

## Riscos técnicos e mitigações

| Risco | Descrição | Mitigação |
|---|---|---|
| **Qualidade das descrições** | Descrições mal redigidas ou abreviadas nos itens do PNCP podem reduzir a similaridade com o catálogo | A pré-filtragem por PDM limita o espaço de busca, e o threshold de 0,5 foi calibrado para tolerar variações razoáveis |
| **Cobertura do catálogo CATMAT** | Medicamentos ausentes do catálogo não serão identificados | Atualizar periodicamente o catálogo de referência conforme novas versões do CATMAT |
| **Evolução do modelo de embedding** | Modelos podem ser descontinuados ou superados por versões melhores | O script aceita parametrização via variável de ambiente `EMBEDDING_MODEL`, permitindo trocar o modelo sem alterar código. O cache é regenerado automaticamente quando o modelo muda |
| **Custo computacional** | A vetorização de grandes volumes de itens pode ser lenta | O cache de embeddings do catálogo evita recálculos. Apenas itens pré-filtrados por PDM são vetorizados |

## Dependências e manutenção

- **Dependências Python:** listadas em [`requirements.txt`](../../../requirements.txt) (`sentence-transformers`, `nltk`, `pandas`, `numpy`).
- **Modelo de embedding:** baixado automaticamente do Hugging Face na primeira execução. Requer conexão com a internet apenas nesse momento.
- **Cache:** o arquivo `catalogo-vetorizado.csv` armazena os embeddings do catálogo. É regenerado automaticamente se o modelo mudar ou se o cache for incompatível.
- **Parametrização opcional:**
  - `EMBEDDING_MODEL` — troca o modelo de embeddings (padrão: `Snowflake/snowflake-arctic-embed-l-v2.0`).
  - `CATALOGO_VETORIZADO_PATH` — define um caminho alternativo para o cache de embeddings.
