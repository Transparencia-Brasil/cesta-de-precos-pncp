#!/bin/bash


# SET DIR ----------------------------------------------------------------------

# Garante que o script será executado a partir do diretório root do projeto
cd "$(dirname "$0")/../../.." || { echo "Erro: Não foi possível acessar o diretório do projeto."; exit 1; }


# PARÂMETROS DO BASH -----------------------------------------------------------

# Verifica se os argumentos foram fornecidos
if [ -z "$1" ]; then
  echo "Erro: O parâmetro ALIAS_COLETA é obrigatório."
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
ALIAS_COLETA=$1

# Datas (usadas apenas para log/nome de screen)
PRIMEIRO_DIA=$2
ULTIMO_DIA=$3

# Para logs legíveis
PRIMEIRO_DIA_LOG=$(echo "$PRIMEIRO_DIA" | sed 's/^[^=]*=//')
ULTIMO_DIA_LOG=$(echo "$ULTIMO_DIA" | sed 's/^[^=]*=//')


# SCRIPTS ----------------------------------------------------------------------

# Script R que faz a recoleta (consulta banco, PNCP e atualiza tabelas)
SCRIPT_R_RECOLETA_RESULTADOS="src/ETL/coletores/recoleta-resultados.R"

echo "Script:"
echo " - '$SCRIPT_R_RECOLETA_RESULTADOS'"
echo ""


# OUTPUT DIR -------------------------------------------------------------------

# Normaliza o alias removendo prefixo
ALIAS_LIMPO=$(echo "$ALIAS_COLETA" | sed 's/^[^=]*=//')

# Diretório padrão para artefatos da recoleta desta janela
PATH_OUTPUT_DIR="coleta/resultados/${ALIAS_LIMPO}/recoleta"

mkdir -p "$PATH_OUTPUT_DIR"

echo "Diretório de saída:"
echo " - '$PATH_OUTPUT_DIR'"
echo ""


# SCREEN -----------------------------------------------------------------------

SCREEN_NAME="recoletor-resultados-${PRIMEIRO_DIA_LOG}-ate-${ULTIMO_DIA_LOG}"

echo "Screen criada para RECOLETA de resultados:"
echo " - '$SCREEN_NAME'"
echo ""


# LOG --------------------------------------------------------------------------

LOG_FILE="${PATH_OUTPUT_DIR}/run-recoletor-resultados-${PRIMEIRO_DIA_LOG}-ate-${ULTIMO_DIA_LOG}.log"

echo "Saída sendo registrada em:"
echo " - '$LOG_FILE'."
echo ""


# RODAR SCRIPT -----------------------------------------------------------------

# Executa o script R dentro de uma screen, passando apenas o diretório de saída
screen -dmS "$SCREEN_NAME" bash -c "Rscript.exe \"$SCRIPT_R_RECOLETA_RESULTADOS\" \"$PATH_OUTPUT_DIR\" > \"$LOG_FILE\" 2>&1"

echo "Recoleta de RESULTADOS em execução..."

echo ""
screen -ls
echo ""
