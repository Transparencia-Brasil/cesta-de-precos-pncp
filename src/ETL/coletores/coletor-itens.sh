#!/bin/bash

echo "---"
echo "ITENS"
echo ""


# SCRIPT -----------------------------------------------------------------------

# Garante que o script será executado a partir do diretório root do projeto
cd "$(dirname "$0")/../../.." || exit 1

echo "Diretório:"
pwd
echo ""


# SCRIPTS ----------------------------------------------------------------------

# Nome do script R
SCRIPT_R_COLETA_ITENS="src/ETL/coletores/coleta-itens.R"

# Mensagem de confirmação
echo "Script:"
echo " - '$SCRIPT_R_COLETA_ITENS'"
echo ""


# PARAMETROS -------------------------------------------------------------------

# Verifica se os argumentos foram fornecidos
if [ -z "$1" ]; then
  echo "Erro: O parâmetro DATA_COLETA é obrigatório."
  exit 1
fi

if [ -z "$2" ]; then
  echo "Erro: O parâmetro PRIMEIRO_DIA é obrigatório."
  exit 1
fi

if [ -z "$3" ]; then
  echo "Erro: O parâmetro ULTIMO_DIA é obrigatório."
  exit 1
fi

# Caminho para o diretório de saída
DATA_COLETA=$1

# Data inicial
PRIMEIRO_DIA=$2

# Data inicial
ULTIMO_DIA=$3

# Mensagens de confirmação
echo "Iniciando coleta com:"
echo "- '$SCRIPT_R_COLETA_ITENS'"
echo ""
echo "Parâmetros: "
echo " - ´$PRIMEIRO_DIA´"
echo " - ´$ULTIMO_DIA´"
echo " - ´$DATA_COLETA´"
echo ""


# SET OUTPUT DIR ---------------------------------------------------------------

# Aponta para o dirtório com a nova DATA_COLETA
# Remove o prefixo "DATA_COLETA=" e mantém só a data YYYY-MM-DD
DATA_COLETA=$(echo "$DATA_COLETA" | sed 's/^[^=]*=//')
PATH_OUTPUT_DIR="coleta/itens/${DATA_COLETA}"

# Cria o diretório de saída, se não existir
mkdir -p "$PATH_OUTPUT_DIR"

# saída
echo "Diretório de saída: ´$PATH_OUTPUT_DIR´"
echo ""


# SET INFUPT FILE --------------------------------------------------------------

INPUT_FILE="coleta/contratacoes/${DATA_COLETA}/dados.csv"

# saída
echo "Parâmetro de entrada no script em R: ´$INPUT_FILE"
echo ""


# RODAR SCRIPT -----------------------------------------------------------------

# Caminho para o arquivo de log
PRIMEIRO_DIA_LOG=$(echo "$PRIMEIRO_DIA" | sed 's/^[^=]*=//')
ULTIMO_DIA_LOG=$(echo "$ULTIMO_DIA" | sed 's/^[^=]*=//')

# - SCREEN
# Nome da screen (concatena o nome do script com PRIMEIRO_DIA e ULTIMO_DIA)
SCREEN_NAME="coletor-itens-${PRIMEIRO_DIA_LOG}-ate-${ULTIMO_DIA_LOG}"

# Mensagem de confirmação
echo "Screen '$SCREEN_NAME' criada para coletar contratações."
echo ""

# - LOG FILE
# Nome do arquivo onde ficarão salvas as logs do script
LOG_FILE="${PATH_OUTPUT_DIR}/run-coletor-itens-${PRIMEIRO_DIA_LOG}-ate-${ULTIMO_DIA_LOG}.log"

# Mensagem de confirmação
echo "Saída sendo registrada em '$LOG_FILE'."
echo ""

# - RUN SCRIPT
# Cria screen e roda o script de coletas
screen -dmS "$SCREEN_NAME" bash -c "Rscript \"$SCRIPT_R_COLETA_ITENS\" \"$INPUT_FILE\" \"$PATH_OUTPUT_DIR\" > \"$LOG_FILE\" 2>&1"

# Mensagem de confirmação
echo "Coleta de ITENS em execução"
echo ""

screen -ls

echo ""
echo "---"
echo ""

# Exibe uma mensagem ao final
echo "Execução da coleta de ITENS concluída."