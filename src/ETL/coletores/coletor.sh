#!/bin/bash

# SCRIPTS ----------------------------------------------------------------------

# Garante que o script será executado a partir do diretório root do projeto
cd "$(dirname "$0")/../../.." || exit 1
pwd

# Nome do script R
SCRIPT_R_COLETA_CONTRATACOES="src/ETL/coletores/coleta-contratacoes.R"
SCRIPT_R_COLETA_ITENS="src/ETL/coletores/coleta-itens.R"
SCRIPT_R_COLETA_RESULTADOS="src/ETL/coletores/coleta-resultados.R"

# Mensagem de confirmação
echo "Scripts:"
echo " - '$SCRIPT_R_COLETA_CONTRATACOES'"
echo " - '$SCRIPT_R_COLETA_ITENS'"
echo " - '$SCRIPT_R_COLETA_RESULTADOS'"
echo ""

# PARÂEMETROS ------------------------------------------------------------------

# :: CONTRATACOES

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
echo "Iniciando coleta com: '$SCRIPT_R_COLETA_CONTRATACOES'"
echo "Parâmetros: "
echo " - ´$PRIMEIRO_DIA´"
echo " - ´$ULTIMO_DIA´"
echo " - ´$DATA_COLETA´"
echo ""

# Aponta para o dirtório com a nova DATA_COLETA
# Remove o prefixo "DATA_COLETA=" e mantém só a data YYYY-MM-DD
DATA_COLETA=$(echo "$DATA_COLETA" | sed 's/^[^=]*=//')
PATH_OUTPUT_DIR="coleta/contratacoes/${DATA_COLETA}"

# saída
echo "Diretório de saída: ´$PATH_OUTPUT_DIR´"
echo ""

# Cria o diretório de saída, se não existir
mkdir -p "$PATH_OUTPUT_DIR"

# SCREEN -----------------------------------------------------------------------

# Nome da screen (concatena o nome do script com PRIMEIRO_DIA e ULTIMO_DIA)
SCREEN_NAME="coletor-contratacoes-${PRIMEIRO_DIA}-ate-${ULTIMO_DIA}"

# Cria uma nova screen
screen -dmS "$SCREEN_NAME"

# Mensagem de confirmação
echo "Screen '$SCREEN_NAME' criada ."
echo ""

# LOG --------------------------------------------------------------------------

# Caminho para o arquivo de log
PRIMEIRO_DIA_LOG=$(echo "$PRIMEIRO_DIA" | sed 's/^[^=]*=//')
ULTIMO_DIA_LOG=$(echo "$ULTIMO_DIA" | sed 's/^[^=]*=//')
LOG_FILE="${PATH_OUTPUT_DIR}/run-coletor-${PRIMEIRO_DIA_LOG}-ate-${ULTIMO_DIA_LOG}.log"

# Mensagem de confirmação
echo "Saída sendo registrada em '$LOG_FILE'."
echo ""

# RODAR SCRIPTS ----------------------------------------------------------------

Rscript --version

# Roda o script de coletas
bash -c "Rscript \"$SCRIPT_R_COLETA_CONTRATACOES\" \"$PATH_OUTPUT_DIR\" \"$PRIMEIRO_DIA\" \"$ULTIMO_DIA\" > \"$LOG_FILE\" 2>&1"
