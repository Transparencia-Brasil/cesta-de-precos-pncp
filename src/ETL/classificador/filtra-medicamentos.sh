#!/bin/bash

echo "---"
echo "FILTRO E CLASSIFICADOR DE MEDICAMENTOS"
echo ""


# SCRIPT -----------------------------------------------------------------------

# Garante que o script será executado a partir do diretório root do projeto
cd "$(dirname "$0")/../../.." || exit 1

echo "Diretório:"
pwd
echo ""


# SCRIPTS ----------------------------------------------------------------------

# Nome do script R
SCRIPT_PY_FILTRA_MEDICAMENTOS="src/ETL/classificador/filtra-medicamentos.py"

# Mensagem de confirmação
echo "Script:"
echo " - '$SCRIPT_PY_FILTRA_MEDICAMENTOS'"
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
echo "- '$CLASSIFICADOR'"
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

# saída
echo "Diretório de saída: ´$PATH_OUTPUT_DIR´"
echo ""


# SET INFUPT FILES -------------------------------------------------------------

# Caminhos para os arquivos de entrada
ITENS="coleta/itens/${DATA_COLETA}/dados.csv"
CATALOGO="data/catmat/catmat.csv"

# parâmetros do script em python
echo "Parâmetros de entrada no script em Python:"
echo "´$ITENS"
echo "´$CATALOGO"
echo ""


# RODAR SCRIPT -----------------------------------------------------------------

# Caminho para o arquivo de log
PRIMEIRO_DIA_LOG=$(echo "$PRIMEIRO_DIA" | sed 's/^[^=]*=//')
ULTIMO_DIA_LOG=$(echo "$ULTIMO_DIA" | sed 's/^[^=]*=//')

# - SCREEN
# Nome da screen (concatena o nome do script com PRIMEIRO_DIA e ULTIMO_DIA)
SCREEN_NAME="classificador-${PRIMEIRO_DIA_LOG}-ate-${ULTIMO_DIA_LOG}"

# Mensagem de confirmação
echo "Screen '$SCREEN_NAME' criada para filtrar e classificar medicamentos."
echo ""

# - LOG FILE
# Nome do arquivo onde ficarão salvas as logs do script
LOG_FILE="${PATH_OUTPUT_DIR}/run-classificador-${PRIMEIRO_DIA_LOG}-ate-${ULTIMO_DIA_LOG}.log"

# Mensagem de confirmação
echo "Saída sendo registrada em '$LOG_FILE'."
echo ""

# - RUN SCRIPT
# Cria screen e roda o script de coletas
screen -dmS "$SCREEN_NAME" bash -c "python3 \"$SCRIPT_PY_FILTRA_MEDICAMENTOS\" \"$ITENS\" \"$CATALOGO\" > \"$LOG_FILE\" 2>&1"

# Mensagem de confirmação
echo "Filtragem e classificação de MEDICAMENTOS em execução"
echo ""

screen -ls

echo ""
echo "---"
echo ""

# Exibe uma mensagem ao final
echo "Execução do classificador concluída."
