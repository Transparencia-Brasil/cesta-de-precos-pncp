#!/usr/bin/env bash

# Orquestrador mensal dos dados abertos OCDS.
#
# Executa, para um unico ANO/MES:
# - mapeamento PNCP -> JSON OCDS
# - geracao de CSVs/ZIPs a partir dos JSONs
# - upload dos ZIPs para AWS S3

set -euo pipefail


# : FUNCOES --------------------------------------------------------------------

usage() {
  cat <<'EOF'
Uso:
  bash tasks/mapeamento-ocds/src/run-dados-abertos-ocds.sh [--ano ANO] [--mes MES]

Exemplos:
  bash tasks/mapeamento-ocds/src/run-dados-abertos-ocds.sh
  bash tasks/mapeamento-ocds/src/run-dados-abertos-ocds.sh --ano 2026 --mes 3

Opcoes:
  --ano ANO   Ano dos dados a processar (inteiro >= 2022).
  --mes MES   Mes dos dados a processar (inteiro entre 1 e 12).
  -h, --help  Mostra esta ajuda.
EOF
}

validate_ano() {
  local ano="${1:-}"
  if [[ -z "$ano" ]]; then
    echo "Erro: ANO nao informado." >&2
    return 2
  fi
  if [[ ! "$ano" =~ ^[0-9]+$ ]]; then
    echo "Erro: o ANO deve ser um numero inteiro (ex.: 2026)." >&2
    return 2
  fi
  if (( 10#$ano < 2022 )); then
    echo "Erro: o ANO deve ser maior ou igual a 2022 (ex.: 2026)." >&2
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
    echo "Erro: o MES deve ser um numero inteiro entre 1 e 12 (ex.: 3)." >&2
    return 2
  fi
  if (( 10#$mes < 1 || 10#$mes > 12 )); then
    echo "Erro: o MES deve estar entre 1 e 12 (ex.: 3)." >&2
    return 2
  fi

  return 0
}

require_arg_value() {
  local option="$1"
  local value="${2:-}"
  if [[ -z "$value" || "$value" == --* ]]; then
    echo "Erro: a opcao ${option} exige um valor." >&2
    exit 2
  fi
}

run_logged() {
  local label="$1"
  local log_file="$2"
  shift 2

  echo ""
  echo "==> ${label}"
  echo "Log: '${log_file}'"
  echo ""

  {
    echo "==== Inicio: ${label} $(date -Iseconds) ===="
    "$@"
    echo "==== Fim: ${label} $(date -Iseconds) ===="
    echo
  } 2>&1 | tee -a "${log_file}"
}


# : PARAMETROS -----------------------------------------------------------------

ANO=""
MES=""
ANO_PROVIDED=false
MES_PROVIDED=false

while (($#)); do
  case "$1" in
    --ano)
      require_arg_value "$1" "${2:-}"
      ANO="$2"
      ANO_PROVIDED=true
      shift 2
      ;;
    --ano=*)
      ANO="${1#*=}"
      ANO_PROVIDED=true
      shift
      ;;
    --mes)
      require_arg_value "$1" "${2:-}"
      MES="$2"
      MES_PROVIDED=true
      shift 2
      ;;
    --mes=*)
      MES="${1#*=}"
      MES_PROVIDED=true
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


# : SET DIR --------------------------------------------------------------------

cd "$(dirname "$0")/../../.." || { echo "Erro: Nao foi possivel acessar o diretorio do projeto."; exit 1; }
pwd

echo "Pipeline de dados abertos OCDS"

if [[ "${ANO_PROVIDED}" == true ]]; then
  validate_ano "$ANO" || exit 2
else
  while true; do
    echo "Digite o ANO dos dados que deseja processar"
    read -r ANO
    if validate_ano "$ANO"; then break; fi
  done
fi

if [[ "${MES_PROVIDED}" == true ]]; then
  validate_mes "$MES" || exit 2
else
  while true; do
    echo "Digite o MES dos dados que deseja processar"
    read -r MES
    if validate_mes "$MES"; then break; fi
  done
fi

ANO="$((10#$ANO))"
MES="$((10#$MES))"
MES_PAD="$(printf "%02d" "$MES")"

echo "Processando dados OCDS para ANO: ${ANO} e MES: ${MES}"


# : PATHS ----------------------------------------------------------------------

OUTPUT_PATH="./tasks/mapeamento-ocds/output"
LOG_DIR="${OUTPUT_PATH}/LOGS"

MAPEAMENTO_LOG_FILE="${LOG_DIR}/mapeamento-${ANO}-${MES_PAD}.log"
CSVS_LOG_FILE="${LOG_DIR}/csvs-ocds-${ANO}-${MES_PAD}.log"
UPLOAD_LOG_FILE="${LOG_DIR}/upload-zips-s3-${ANO}-${MES_PAD}.log"

PYTHON_BIN="./.venv/Scripts/python.exe"
MAPEAMENTO_PYTHON_SCRIPT="./tasks/mapeamento-ocds/src/mapeamento-pncp-ocds.py"
CSVS_PYTHON_SCRIPT="./tasks/mapeamento-ocds/src/csvs-ocds.py"
UPLOAD_PYTHON_SCRIPT="./tasks/mapeamento-ocds/src/upload-zips-s3.py"

mkdir -p "${LOG_DIR}"

echo "Python a ser utilizado:"
echo " - '${PYTHON_BIN}'"
echo ""
echo "Logs da execucao:"
echo " - '${MAPEAMENTO_LOG_FILE}'"
echo " - '${CSVS_LOG_FILE}'"
echo " - '${UPLOAD_LOG_FILE}'"


# : COMPATIBILIDADE WSL --------------------------------------------------------

MAPEAMENTO_PYTHON_SCRIPT_TO_RUN="${MAPEAMENTO_PYTHON_SCRIPT}"
CSVS_PYTHON_SCRIPT_TO_RUN="${CSVS_PYTHON_SCRIPT}"
UPLOAD_PYTHON_SCRIPT_TO_RUN="${UPLOAD_PYTHON_SCRIPT}"

if command -v wslpath >/dev/null 2>&1; then
  export WSLENV="${WSLENV:+${WSLENV}:}ANO:MES"
  MAPEAMENTO_PYTHON_SCRIPT_TO_RUN="$(wslpath -w "${MAPEAMENTO_PYTHON_SCRIPT}")"
  CSVS_PYTHON_SCRIPT_TO_RUN="$(wslpath -w "${CSVS_PYTHON_SCRIPT}")"
  UPLOAD_PYTHON_SCRIPT_TO_RUN="$(wslpath -w "${UPLOAD_PYTHON_SCRIPT}")"
fi


# : PIPELINE -------------------------------------------------------------------

run_logged "Mapeamento PNCP -> JSON OCDS" "${MAPEAMENTO_LOG_FILE}" \
  env ANO="${ANO}" MES="${MES}" "${PYTHON_BIN}" "${MAPEAMENTO_PYTHON_SCRIPT_TO_RUN}"

run_logged "Geracao de CSVs/ZIPs OCDS" "${CSVS_LOG_FILE}" \
  "${PYTHON_BIN}" "${CSVS_PYTHON_SCRIPT_TO_RUN}" --ano "${ANO}" --mes "${MES}"

run_logged "Upload dos ZIPs OCDS para S3" "${UPLOAD_LOG_FILE}" \
  "${PYTHON_BIN}" "${UPLOAD_PYTHON_SCRIPT_TO_RUN}" --ano "${ANO}" --mes "${MES}"

echo ""
echo "Pipeline finalizado com sucesso para ANO: ${ANO} e MES: ${MES}."
