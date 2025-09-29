#!/bin/bash

# Caminhos para os arquivos de entrada
ITENS="C:/Users/rdurl/OneDrive/Documentos/cesta-de-precos-pncp/tasks/unifica-dados/output/itens-endpoint-recuperado.csv"
CATALOGO="C:/Users/rdurl/OneDrive/Documentos/cesta-de-precos-pncp/data/catmat/catmat.csv"

# Caminho para o script Python
SCRIPT="C:/Users/rdurl/OneDrive/Documentos/cesta-de-precos-pncp/tasks/unifica-dados/src/05-filtra-medicamentos.py"

# Executa o script Python com os argumentos usando o Python do .venv
"C:/Users/rdurl/OneDrive/Documentos/cesta-de-precos-pncp/.venv/Scripts/python.exe" "$SCRIPT" "$ITENS" "$CATALOGO"

# Exibe uma mensagem ao final
echo "Execução do script concluída."
