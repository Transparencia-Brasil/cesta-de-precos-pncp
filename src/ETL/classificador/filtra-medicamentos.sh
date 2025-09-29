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
SCRIPT_PY_FILTRA_MEDICAMENTOS="src/ETL/classificador/filtra-medicamentos.py"

# Mensagem de confirmação
echo "Script:"
echo " - '$SCRIPT_PY_FILTRA_MEDICAMENTOS'"
echo ""


# SET OUTPUT DIR ---------------------------------------------------------------

# Aponta para o dirtório com a nova ALIAS_COLETA
# Remove o prefixo "ALIAS_COLETA=" e mantém só a data YYYY-MM-DD
ALIAS_COLETA=$(echo "$ALIAS_COLETA" | sed 's/^[^=]*=//')
PATH_OUTPUT_DIR="coleta/itens/${ALIAS_COLETA}"

# saída
echo "Diretório de saída:"
echo " - '$PATH_OUTPUT_DIR'"
echo ""


# SCREEN -----------------------------------------------------------------------

# Nome da screen (concatena o nome do script com PRIMEIRO_DIA e ULTIMO_DIA)
SCREEN_NAME="classificador-${PRIMEIRO_DIA_LOG}-ate-${ULTIMO_DIA_LOG}"

# Mensagem de confirmação
echo "Screen criada para coletar contratações:"
echo " - '$SCREEN_NAME'"
echo ""


# LOG --------------------------------------------------------------------------

# Nome do arquivo onde ficarão salvas as logs do script
LOG_FILE="${PATH_OUTPUT_DIR}/run-classificador-${PRIMEIRO_DIA_LOG}-ate-${ULTIMO_DIA_LOG}.log"

# Mensagem de confirmação
echo "Saída sendo registrada em:"
echo " - '$LOG_FILE'."
echo ""


# PARÂMETROS DO COLETOR --------------------------------------------------------

# Caminhos para os arquivos de entrada
ITENS="coleta/itens/${ALIAS_COLETA}/dados.csv"
CATALOGO="data/catmat/catmat.csv"

# parâmetros do script em python
echo "Parâmetros do classificador:"
echo "ITENS='$ITENS'"
echo "CATALOGO='$CATALOGO'"
echo ""


# PYTHON DO PROJETO (.venv) ----------------------------------------------------

# Usa sempre o Python do ambiente virtual local (.venv)
PYTHON_BIN="/mnt/c/Users/rdurl/OneDrive/Documentos/cesta-de-precos-pncp/.venv/Scripts/python.exe"

# Mensagem de confirmação
echo "Python a ser utilizado:"
echo " - '$PYTHON_BIN'"
echo ""


# RODAR SCRIPT -----------------------------------------------------------------

# - RUN SCRIPT
# Cria screen e roda o classificador em Python.
# Propaga variáveis de ambiente opcionais (EMBEDDING_MODEL e CATALOGO_VETORIZADO_PATH) apenas se definidas.

# Monta prefixo de variáveis de ambiente apenas quando não vazias
ENV_PREFIX=""
if [ -n "$EMBEDDING_MODEL" ]; then
  ENV_PREFIX="EMBEDDING_MODEL=\"$EMBEDDING_MODEL\" $ENV_PREFIX"
fi
if [ -n "$CATALOGO_VETORIZADO_PATH" ]; then
  ENV_PREFIX="CATALOGO_VETORIZADO_PATH=\"$CATALOGO_VETORIZADO_PATH\" $ENV_PREFIX"
fi

# Registra no log os valores efetivos e executa o script Python do .venv
screen -dmS "$SCREEN_NAME" bash -c "{ echo \"EMBEDDING_MODEL=${EMBEDDING_MODEL:-<não definido>}\"; echo \"CATALOGO_VETORIZADO_PATH=${CATALOGO_VETORIZADO_PATH:-<padrão>}\"; echo \"PYTHON_BIN=$PYTHON_BIN\"; } > \"$LOG_FILE\"; ${ENV_PREFIX}$PYTHON_BIN \"$SCRIPT_PY_FILTRA_MEDICAMENTOS\" \"$ITENS\" \"$CATALOGO\" >> \"$LOG_FILE\" 2>&1"

# Mensagem de confirmação
echo "Filtragem e classificação de MEDICAMENTOS em execução..."

echo ""
screen -ls
echo ""
