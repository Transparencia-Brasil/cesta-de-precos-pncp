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

# Data inicial
PRIMEIRO_DIA=$2

# Data inicial
ULTIMO_DIA=$3

# Caminho para o arquivo de log
PRIMEIRO_DIA_LOG=$(echo "$PRIMEIRO_DIA" | sed 's/^[^=]*=//')
ULTIMO_DIA_LOG=$(echo "$ULTIMO_DIA" | sed 's/^[^=]*=//')


# SCRIPTS ----------------------------------------------------------------------

# Nome do script R
SCRIPT_R_COLETA_CONTRATACOES="src/ETL/coletores/coleta-contratacoes.R"

# Mensagem de confirmação
echo "Script:"
echo " - '$SCRIPT_R_COLETA_CONTRATACOES'"
echo ""


# SET OUTPUT DIR ---------------------------------------------------------------

# Aponta para o dirtório com a nova ALIAS_COLETA
# Remove o prefixo "ALIAS_COLETA=" e mantém só a data YYYY-MM-DD
ALIAS_COLETA=$(echo "$ALIAS_COLETA" | sed 's/^[^=]*=//')
PATH_OUTPUT_DIR="coleta/contratacoes/${ALIAS_COLETA}"

# Cria o diretório de saída, se não existir
mkdir -p "$PATH_OUTPUT_DIR"

# saída
echo "Diretório de saída:"
echo " - '$PATH_OUTPUT_DIR'"
echo ""


# SCREEN -----------------------------------------------------------------------

# Nome da screen (concatena o nome do script com PRIMEIRO_DIA e ULTIMO_DIA)
SCREEN_NAME="coletor-contratacoes-${PRIMEIRO_DIA_LOG}-ate-${ULTIMO_DIA_LOG}"

# Mensagem de confirmação
echo "Screen criada para coletar contratações:"
echo " - '$SCREEN_NAME'"
echo ""


# LOG --------------------------------------------------------------------------

# Nome do arquivo onde ficarão salvas as logs do script
LOG_FILE="${PATH_OUTPUT_DIR}/run-coletor-contratacoes-${PRIMEIRO_DIA_LOG}-ate-${ULTIMO_DIA_LOG}.log"

# Mensagem de confirmação
echo "Saída sendo registrada em:"
echo " - '$LOG_FILE'."
echo ""


# PARÂMETROS DO COLETOR --------------------------------------------------------

# Mensagens de confirmação
echo "Parâmetros do coletor: "
echo " - PATH_OUTPUT_DIR=\"$PATH_OUTPUT_DIR\""
echo " - PRIMEIRO_DIA=\"$PRIMEIRO_DIA_LOG\""
echo " - ULTIMO_DIA=\"$ULTIMO_DIA_LOG\""
echo ""


# RODAR SCRIPT -----------------------------------------------------------------

# - RUN SCRIPT
# Cria screen e roda o script de coletas
# screen -dmS "$SCREEN_NAME" bash -c "Rscript \"$SCRIPT_R_COLETA_CONTRATACOES\" PATH_OUTPUT_DIR=\"$PATH_OUTPUT_DIR\" \"$PRIMEIRO_DIA\" \"$ULTIMO_DIA\" > \"$LOG_FILE\" 2>&1"

screen -dmS "$SCREEN_NAME" bash -c "/mnt/c/Program\ Files/R/R-4.4.2/bin/Rscript.exe \"$SCRIPT_R_COLETA_CONTRATACOES\" PATH_OUTPUT_DIR=\"$PATH_OUTPUT_DIR\" \"$PRIMEIRO_DIA\" \"$ULTIMO_DIA\" > \"$LOG_FILE\" 2>&1"

# Mensagem de confirmação
echo "Coleta de CONTRATAÇÕES em execução..."

echo ""
screen -ls
echo ""
