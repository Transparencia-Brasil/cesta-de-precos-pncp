#!/bin/bash

# Este script corrige inconsistências no campo `endpoint` do arquivo `itens3.rds`.
# O problema ocorre porque o campo `endpoint` está vazio e seu conteúdo foi armazenado na coluna `status_code`.
#
# - Parte a: Separa endpoints missings e faz a sanitização de dados afetados
# - Parte b: gerar embeddings deses endpoints restaurados (com script python)
# - Parte c: remover linhas inconsistes e incluir sanitizadas no dataset final
#
# Parte b (este script):
# Este script executa o processo de filtragem de medicamentos usando o script Python `05-filtra-medicamentos.py`.
# Ele deve ser executado após o script `07a-bugfix-missing-endpoints-na-coleta3.R`, que corrige os endpoints faltantes, garantindo que os dados estejam completos para a filtragem.
#
# saída: um arquivo CSV contendo os itens classificados como medicamentos,
# junto com o código BR do item do catálogo mais similar e a similaridade entre eles, salvo em "tasks/unifica-dados/output/medicamentos-endpoint-recuperado.csv".

# Caminhos para os arquivos de entrada
ITENS="C:/Users/rdurl/OneDrive/Documentos/cesta-de-precos-pncp/tasks/unifica-dados/output/itens-endpoint-recuperado.csv"
CATALOGO="C:/Users/rdurl/OneDrive/Documentos/cesta-de-precos-pncp/data/catmat/catmat.csv"

# Caminho para o script Python
SCRIPT="C:/Users/rdurl/OneDrive/Documentos/cesta-de-precos-pncp/tasks/unifica-dados/src/05-filtra-medicamentos.py"

# Executa o script Python com os argumentos usando o Python do .venv
"C:/Users/rdurl/OneDrive/Documentos/cesta-de-precos-pncp/.venv/Scripts/python.exe" "$SCRIPT" "$ITENS" "$CATALOGO"

# Exibe uma mensagem ao final
echo "Execução do script concluída."
