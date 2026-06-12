#!/usr/bin/env bash

# Script interativo para gerar CSVs/ZIPs a partir dos JSONs OCDS.
#
# O que este script faz:
# - Solicita entradas via terminal (ANO e MES)
# - Valida ANO (inteiro >= 2022) e MES (inteiro entre 1 e 12)
# - Executa o script Python csvs-ocds.py com os parâmetros --ano e --mes
# - Registra toda a saída (stdout + stderr) em um arquivo de log
#
# Pré-requisitos:
# - Python com o pacote `flattentool` instalado no .venv
# - JSONs OCDS já gerados pelo mapeamento (mapeamento-pncp-ocds.py)


# : BASH OPTIONS ---------------------------------------------------------------

set -euo pipefail


# : SET DIR --------------------------------------------------------------------

# Garante que o script será executado a partir do diretório root do projeto
cd "$(dirname "$0")/../../.." || { echo "Erro: Não foi possível acessar o diretório do projeto."; exit 1; }
pwd


# : FUNÇÕES --------------------------------------------------------------------

usage() {
  cat <<'EOF'
Uso:
  bash tasks/mapeamento-ocds/src/run-csvs-ocds.sh

Opcoes:
  -h, --help  Mostra esta ajuda.
EOF
}

validate_ano() {
  local ano="${1:-}"
  if [[ -z "$ano" ]]; then
    echo "Erro: ANO não informado." >&2
    return 2
  fi
  if [[ ! "$ano" =~ ^[0-9]+$ ]]; then
    echo "Erro: o ANO deve ser um número inteiro (ex.: 2025)." >&2
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
    echo "Erro: MES não informado." >&2
    return 2
  fi
  if [[ ! "$mes" =~ ^[0-9]+$ ]]; then
    echo "Erro: o MES deve ser um número inteiro entre 1 e 12 (ex.: 12)." >&2
    return 2
  fi
  if (( mes < 1 || mes > 12 )); then
    echo "Erro: o MES deve estar entre 1 e 12 (ex.: 12)." >&2
    return 2
  fi
  return 0
}


while (($#)); do
  case "$1" in
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


# : PARÂMETROS E VALIDAÇÕES ----------------------------------------------------

echo "Geração de CSVs/ZIPs a partir dos JSONs OCDS"

while true; do
  echo "Digite o ANO dos dados que deseja converter para CSV"
  read -r ANO
  if validate_ano "$ANO"; then break; fi
done

while true; do
  echo "Digite o MES dos dados que deseja converter para CSV"
  read -r MES
  if validate_mes "$MES"; then break; fi
done

echo "Gerando CSVs/ZIPs para ANO: $ANO e MES: $MES"


# : PATHS ----------------------------------------------------------------------

OUTPUT_PATH="./tasks/mapeamento-ocds/output"

LOG_DIR="${OUTPUT_PATH}/LOGS"
MES_PAD=$(printf "%02d" "$MES")
LOG_FILE="${LOG_DIR}/csvs-ocds-${ANO}-${MES_PAD}.log"

# Python do ambiente virtual local (.venv) na raiz do repo.
PYTHON_BIN="./.venv/Scripts/python.exe"

# Script Python que gera os CSVs/ZIPs.
PYTHON_SCRIPT="./tasks/mapeamento-ocds/src/csvs-ocds.py"


# : DIRETÓRIOS -----------------------------------------------------------------

mkdir -p "${LOG_DIR}"


# : LOG FILE -------------------------------------------------------------------

echo "Saída sendo registrada em:"
echo " - '$LOG_FILE'."
echo ""


# : PYTHON DO PROJETO (.venv) --------------------------------------------------

echo "Python a ser utilizado:"
echo " - '$PYTHON_BIN'"
echo ""


# : RODAR SCRIPT ---------------------------------------------------------------

echo "Iniciando a geração de CSVs/ZIPs..."

# Se estiver rodando via WSL chamando um Python do Windows, converte o caminho.
PYTHON_SCRIPT_TO_RUN="${PYTHON_SCRIPT}"
if command -v wslpath >/dev/null 2>&1; then
  PYTHON_SCRIPT_TO_RUN="$(wslpath -w "${PYTHON_SCRIPT}")"
fi

"${PYTHON_BIN}" "${PYTHON_SCRIPT_TO_RUN}" --ano "${ANO}" --mes "${MES}" \
  2>&1 | tee -a "${LOG_FILE}"

echo ""
echo "Execução finalizada. Confira o log em: '$LOG_FILE'."
echo ""
echo "CSVs/ZIPs gerados localmente e prontos para inspeção."
echo "Para transferir os ZIPs ao S3, use o orquestrador 'run-dados-abertos-ocds.sh' ou o runner 'run-upload-zips-s3.sh'."
