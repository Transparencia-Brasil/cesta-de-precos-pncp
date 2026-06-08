#!/usr/bin/env bash

# Script interativo para transferir ZIPs OCDS locais para AWS S3.
#
# O que este script faz:
# - Solicita entradas via terminal (ANO e MES)
# - Valida ANO (inteiro >= 2022) e MES (inteiro entre 1 e 12)
# - Carrega variaveis de ambiente de .env, se o arquivo existir
# - Executa upload-zips-s3.py para validar e enviar ZIPs CSV/JSON
# - Registra toda a saida (stdout + stderr) em um arquivo de log


# : BASH OPTIONS ---------------------------------------------------------------

set -euo pipefail


# : SET DIR --------------------------------------------------------------------

# Garante que o script sera executado a partir do diretorio root do projeto
cd "$(dirname "$0")/../../.." || { echo "Erro: Nao foi possivel acessar o diretorio do projeto."; exit 1; }
pwd


# : FUNCOES --------------------------------------------------------------------

usage() {
  cat <<'EOF'
Uso:
  bash tasks/mapeamento-ocds/src/run-upload-zips-s3.sh [--overwrite]

Opcoes:
  --overwrite  Sobrescreve objetos existentes no S3 durante o upload.
  -h, --help   Mostra esta ajuda.
EOF
}

validate_ano() {
  local ano="${1:-}"
  if [[ -z "$ano" ]]; then
    echo "Erro: ANO nao informado." >&2
    return 2
  fi
  if [[ ! "$ano" =~ ^[0-9]+$ ]]; then
    echo "Erro: o ANO deve ser um numero inteiro (ex.: 2025)." >&2
    return 2
  fi
  if (( ano < 2022 )); then
    echo "Erro: o ANO deve ser maior ou igual a 2022 (ex.: 2025)." >&2
    return 2
  fi
  return 0
}

validate_mes() {
  local mes="${1:-}"
  if [[ -z "$mes" ]]; then
    echo "Erro: MES nao informado." >&2
    return 2
  fi
  if [[ ! "$mes" =~ ^[0-9]+$ ]]; then
    echo "Erro: o MES deve ser um numero inteiro entre 1 e 12 (ex.: 12)." >&2
    return 2
  fi
  if (( mes < 1 || mes > 12 )); then
    echo "Erro: o MES deve estar entre 1 e 12 (ex.: 12)." >&2
    return 2
  fi
  return 0
}


# : PARAMETROS CLI -------------------------------------------------------------

OVERWRITE=false

while (($#)); do
  case "$1" in
    --overwrite)
      OVERWRITE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Erro: opcao desconhecida: $1" >&2
      echo "" >&2
      usage >&2
      exit 2
      ;;
  esac
done


# : PARAMETROS E VALIDACOES ----------------------------------------------------

echo "Transferencia de ZIPs OCDS para AWS S3"

while true; do
  echo "Digite o ANO dos ZIPs que deseja transferir"
  read -r ANO
  if validate_ano "$ANO"; then break; fi
done

while true; do
  echo "Digite o MES dos ZIPs que deseja transferir"
  read -r MES
  if validate_mes "$MES"; then break; fi
done

echo "Transferindo ZIPs para ANO: $ANO e MES: $MES"
echo "Overwrite remoto no S3: $OVERWRITE"


# : PATHS ----------------------------------------------------------------------

OUTPUT_PATH="./tasks/mapeamento-ocds/output"

LOG_DIR="${OUTPUT_PATH}/LOGS"
MES_PAD=$(printf "%02d" "$MES")
LOG_FILE="${LOG_DIR}/upload-zips-s3-${ANO}-${MES_PAD}.log"

PYTHON_BIN="./.venv/Scripts/python.exe"
PYTHON_SCRIPT="./tasks/mapeamento-ocds/src/upload-zips-s3.py"


# : DIRETORIOS -----------------------------------------------------------------

mkdir -p "${LOG_DIR}"


# : LOG FILE -------------------------------------------------------------------

echo "Saida sendo registrada em:"
echo " - '$LOG_FILE'."
echo ""


# : PYTHON DO PROJETO (.venv) --------------------------------------------------

echo "Python a ser utilizado:"
echo " - '$PYTHON_BIN'"
echo ""


# : RODAR SCRIPT ---------------------------------------------------------------

echo "Iniciando transferencia de ZIPs para S3..."

PYTHON_SCRIPT_TO_RUN="${PYTHON_SCRIPT}"
if command -v wslpath >/dev/null 2>&1; then
  PYTHON_SCRIPT_TO_RUN="$(wslpath -w "${PYTHON_SCRIPT}")"
fi

UPLOAD_ARGS=(--ano "${ANO}" --mes "${MES}")
if [[ "${OVERWRITE}" == true ]]; then
  UPLOAD_ARGS+=(--overwrite)
fi

"${PYTHON_BIN}" "${PYTHON_SCRIPT_TO_RUN}" "${UPLOAD_ARGS[@]}" \
  2>&1 | tee -a "${LOG_FILE}"

echo ""
echo "Execucao finalizada. Confira o log em: '$LOG_FILE'."
