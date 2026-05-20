#!/bin/bash

# Este script executa o processo de coleta de resultados usando o script R `coleta-resultados.R`.
# Ele deve ser executado após o script `08-resultados-de-itens-a-recoletar.R`, que gera um
# arquivo CSV contendo os endpoints dos itens que precisam ser recoletados.
#
# saída: um arquivo CSV contendo os resultados da coleta dos endpoints listados no arquivo de entrada, salvo em "tasks/unifica-dados/output/itens/medicamentos.csv".

# Caminho para o script R
SCRIPT="C:/Users/rdurl/OneDrive/Documentos/cesta-de-precos-pncp/src/ETL/coletores/coleta-resultados.R"

# Parâmeto para o script R: (obrigatório) o caminho para um arquivo .csv que seja
# um dataframe contendo uma coluna nomeada 'endpoint', indicando os endpoints de
# itens das contratações coletados anteriormente.
PARAMETRO_1="C:/Users/rdurl/OneDrive/Documentos/cesta-de-precos-pncp/coleta/itens/medicamentos.csv"

# Executa o script R com o parâmetro
Rscript "$SCRIPT" "$PARAMETRO_1"
