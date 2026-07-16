# Enriquecimento dos dados atuais com dados legados

Este documento descreve as alterações realizadas no notebook
[`analisa-colunas-para-ETL.ipynb`](analisa-colunas-para-ETL.ipynb) para adicionar
informações dos dados legados aos datasets atuais de itens homologados e de
contratações.

## Objetivo

O objetivo é enriquecer os registros atuais com colunas vindas dos datasets
legados, sem criar nem remover linhas dos datasets principais.

As junções seguem estas regras:

- os datasets atuais definem quais linhas estarão no resultado;
- os dados legados são adicionados somente quando as chaves correspondem;
- linhas atuais sem correspondência são preservadas, com `NaN` nas colunas do
  legado;
- registros existentes apenas no legado não são adicionados ao resultado;
- valores legados divergentes para uma mesma chave são preservados em listas;
- a cardinalidade é validada durante a junção e novamente com uma asserção.

## Padronização das chaves

Os arquivos legados usam nomes de colunas diferentes dos datasets atuais. Antes
das junções, as colunas são renomeadas:

| Dataset legado | Nome original | Nome padronizado |
|---|---|---|
| Itens homologados | `data.numeroControlePNCP` | `numero_controle_pncp` |
| Itens homologados | `numeroItem` | `numero_item` |
| Contratações | `data.numeroControlePNCP` | `numero_controle_pncp` |

## Itens homologados

### Datasets

- Principal: `DF_ITEM_HOMOLOGADO_COLUNAS`
- Legado: `DF_LEGADOS_ITEM_HOMOLOGADO`
- Resultado: `DF_ITEM_HOMOLOGADO_COM_LEGADOS`

### Chave da junção

A correspondência ocorre no nível do item, usando a chave composta:

```python
["numero_controle_pncp", "numero_item"]
```

Isso evita associar, por exemplo, os dados legados do item 1 aos demais itens da
mesma contratação.

### Tratamento de repetições

O legado pode conter várias linhas para a mesma chave composta. As repetições
são agrupadas antes da junção:

- se uma coluna possui somente um valor não nulo, o valor permanece escalar;
- se existem valores diferentes, todos são mantidos em uma lista;
- se não existe valor não nulo, o resultado é `pd.NA`.

Esse tratamento impede que uma junção de um registro atual com várias linhas do
legado multiplique as linhas do resultado.

A junção é feita com `how="left"` e validada como `many_to_one`, pois várias
linhas do dataset principal podem apontar para uma chave única já consolidada
do legado.

### Resultado validado

| Medida | Quantidade |
|---|---:|
| Linhas no dataset principal | 200.205 |
| Linhas no resultado | 200.205 |
| Linhas com correspondência no legado | 138.921 |
| Linhas sem correspondência no legado | 61.284 |
| Diferença de cardinalidade | 0 |

Também foi verificado o registro de exemplo com
`numero_controle_pncp = "98671597000109-1-000672/2024"` e `numero_item = 9`.
Ele foi encontrado nos dois datasets e recebeu as informações legadas.

## Contratações

### Datasets

- Principal: `DF_CONTRATACOES_COLUNAS`
- Legado: `DF_LEGADOS_CONTRATACOES`
- Resultado: `DF_CONTRATACOES_COM_LEGADOS`

### Chave da junção

As contratações são relacionadas por:

```python
["numero_controle_pncp"]
```

Essa chave é única nas 101.387 linhas do dataset principal analisado.

### Tratamento de repetições

As repetições do legado são consolidadas com a mesma função usada para os itens
homologados. Foram identificadas 224 contratações com valores legados
divergentes de `data.srp`; esses valores foram preservados em listas.

A junção usa `how="left"` e é validada como `one_to_one`, pois tanto o dataset
principal quanto o legado consolidado possuem uma linha por chave.

### Resultado validado

| Medida | Quantidade |
|---|---:|
| Linhas no dataset principal | 101.387 |
| Linhas no resultado | 101.387 |
| Linhas com correspondência no legado | 62.258 |
| Linhas sem correspondência no legado | 39.129 |
| Contratações com valores conflitantes em listas | 224 |
| Diferença de cardinalidade | 0 |

## Garantias de cardinalidade

As duas junções possuem validação explícita do pandas e uma asserção que compara
as quantidades de linhas antes e depois do enriquecimento. Exemplo:

```python
assert len(DATASET_RESULTANTE) == len(DATASET_PRINCIPAL), (
    "A junção alterou a quantidade de linhas do dataset principal"
)
```

Se uma mudança futura voltar a multiplicar ou remover registros, a execução será
interrompida em vez de produzir silenciosamente um dataset com cardinalidade
incorreta.

## Colunas necessárias para alteração do ETL

### Itens homologados (medicamentos)

| Coluna de origem | Situação no banco |
|---|---|
| `tipoBeneficioNome` | **Já existe no banco** |
| `aplicabilidadeMargemPreferenciaNormal` | Deve ser adicionada |
| `percentualMargemPreferenciaNormal` | Deve ser adicionada |
| `aplicabilidadeMargemPreferenciaAdicional` | Deve ser adicionada |
| `percentualMargemPreferenciaAdicional` | Deve ser adicionada |
| `tipoMargemPreferencia.codigo` | Deve ser adicionada |
| `criterioJulgamentoNome` | **Já existe no banco** |
| `tipoMargemPreferencia.nome` | Deve ser adicionada |
| `tipoMargemPreferencia` | Deve ser adicionada |
| `exigenciaConteudoNacional` | Deve ser adicionada |

### Contratações 

| Coluna de origem | Situação no banco|
|---|---|
| `srp` | **Já existe no banco** na tabela `contratacao`; 

- Não foi observada nenhum coluna referente à descontos que fosse necessário adicionar na tabela do Banco.
