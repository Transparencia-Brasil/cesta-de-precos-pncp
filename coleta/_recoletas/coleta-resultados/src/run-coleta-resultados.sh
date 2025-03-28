#!/bin/bash

# Nome do script R
SCRIPT_R="coleta-resultados.R"

# Atribui os argumentos

# Caminho para endpoints de entrada
PATH_ITENS="endpoints.csv"

# Caminho para o diretório de saída
PATH_OUTPUT_DIR="resultados"

# Nome da screen (concatena o nome do script com PRIMEIRO_DIA)
SCREEN_NAME="run-coleta-resultados"

# Caminho para o arquivo de log
LOG_FILE="run-coleta-resultados.log"

# Cria uma nova screen e executa o script R dentro dela
screen -dmS "$SCREEN_NAME" bash -c "Rscript \"$SCRIPT_R\" \"$PATH_ITENS\" \"$PATH_OUTPUT_DIR\" > \"$LOG_FILE\" 2>&1"

# Mensagem de confirmação
echo "Screen '$SCREEN_NAME' criada e script em execução. Saída sendo registrada em '$LOG_FILE'."
