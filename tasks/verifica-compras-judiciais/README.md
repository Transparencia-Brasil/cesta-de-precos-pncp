# Verificação de compras judiciais

Esta task analisa descrições de compras públicas para localizar registros com possíveis indícios de atendimento a demandas judiciais.

O trabalho é exploratório e parte de uma regra textual simples, transparente e auditável. Uma compra é marcada quando o conteúdo da coluna `objeto_compra` contém uma palavra iniciada por `judic`, reconhecendo palavras como `judicial` e `judiciais`.

## Estrutura

```text
tasks/verifica-compras-judiciais/
├── docs/
│   └── contagem-compras-judiciais.ipynb
├── inputs/
│   └── objeto-compra.csv
├── outputs/
|   └── compras-somente-judiciais.csv
└── README.md
```

## Regra de identificação

A expressão usada no notebook é:

```python
REGEX_TERMO_JUDICIAL = r"judic"
```

O padrão `judic\w*` contempla palavras iniciadas por `judic`, incluindo `judicial` e `judiciais`.

A função `possui_indicativo_judicial`:

1. retorna `False` para descrições ausentes;
2. converte a descrição para texto em letras minúsculas;
3. procura o trecho definido em `REGEX_TERMO_JUDICIAL`;
4. retorna `True` quando encontra uma correspondência.

Exemplo de descrição identificada:

```text
AQUISIÇÃO DE MEDICAMENTOS PARA ATENDIMENTO DE DEMANDAS JUDICIAIS COM DISPENSA DE LICITAÇÃO EMERGENCIAL SEM DISPUTA.
```

A função é aplicada à coluna `objeto_compra` para criar a coluna booleana `compra_judicial`. Em seguida, os registros positivos são reunidos no DataFrame `apenas_compras_judiciais_df`.

Com a regra atual, foram identificados 15.770 registros no arquivo analisado.

## Como executar

Abra e execute:

```text
docs/contagem-compras-judiciais.ipynb
```

O notebook utiliza:

- Python;
- pandas;
- módulo `re(regular expressions)` da biblioteca padrão.

O caminho `base_dir` está definido diretamente no notebook e deve apontar para a raiz local do repositório.

## Validação dos dados

Foi realizada uma validação por amostragem dos registros do início, do meio e do fim do dataset resultante, com o objetivo de verificar a aderência à regra de identificação e a ausência de falsos positivos nas amostras analisadas.
