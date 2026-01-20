#!/usr/bin/env bash

# Script interativo para coletar ANO e MES e preparar o mapeamento PNCP -> OCDS.
#
# O que este script faz:
# - Solicita entradas via terminal (ANO e MES)
# - Valida ANO (inteiro >= 2022) e MES (inteiro entre 1 e 12), repetindo até o usuário informar valores válidos
# - Imprime uma confirmação do período selecionado (ANO/MES)
# - Cria (se necessário) o diretório de saída do mapeamento em: tasks/mapeamento-ocds/output/${ANO}/${MES}
#
# Observação: por enquanto, este script prepara/valida o período e a estrutura de saída;
# a execução do processo de mapeamento (ETL/transformações) pode ser adicionada depois.


# : BASH OPTIONS ---------------------------------------------------------------

# Falha imediata em erros, variáveis não definidas e erros em pipes.
set -euo pipefail


# : SET DIR --------------------------------------------------------------------

# Garante que o script será executado a partir do diretório root do projeto
cd "$(dirname "$0")/../../.." || { echo "Erro: Não foi possível acessar o diretório do projeto."; exit 1; }
pwd


# : FUNÇÕES --------------------------------------------------------------------

# Valida o ANO informado pelo usuário.
# Retorna 0 se válido; retorna 2 e imprime mensagem em stderr se inválido.
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

# Valida o MES informado pelo usuário.
# Retorna 0 se válido; retorna 2 e imprime mensagem em stderr se inválido.
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



# : PARÂMETROS E VALIDAÇÕES ----------------------------------------------------

# Mensagem inicial do fluxo (ponto de entrada do script).
echo "Iniciando mapeamento OCDS"

# Loop de leitura do ANO:
# - lê do stdin
# - guarda na variável ANO
# - repete até passar na validação
while true; do
  echo "Digite o ANO dos dados que deseja mapear"
  read -r ANO
  if validate_ano "$ANO"; then break; fi
done

# Loop de leitura do MES:
# - lê do stdin
# - guarda na variável MES
# - repete até passar na validação
while true; do
  echo "Digite o MES dos dados que deseja mapear"
  read -r MES
  if validate_mes "$MES"; then break; fi
done

# Confirmação final do período selecionado (para logs e rastreabilidade).
echo "Mapeando dados do PNCP para OCDS no período: ANO: $ANO e MES: $MES"


# : PATHS ----------------------------------------------------------------------

# Diretório onde os artefatos/logs do mapeamento serão gravados, organizados por ANO/MES.
OUTPUT_PATH="./tasks/mapeamento-ocds/output"

# Mantém compatibilidade com variáveis usadas em outras seções.
OUTPUT_DATA_PATH="${OUTPUT_PATH}/${ANO}/${MES}"

# Nome do arquivo onde ficarão salvas as logs do script
LOG_DIR="${OUTPUT_PATH}/LOGS"
LOG_FILE="${LOG_DIR}/mapeamento-${ANO}-${MES}.log"

# Usa sempre o Python do ambiente virtual local (.venv) na raiz do repo.
PYTHON_BIN="./.venv/Scripts/python.exe"

# Script Python que realiza o mapeamento PNCP -> OCDS.
PYTHON_SCRIPT="./tasks/mapeamento-ocds/src/mapeamento-pncp-ocds.py"

# Screem name
SCREEN_NAME="mapeamento-ocds-${ANO}-${MES}"


# : DIRETÓRIOS -----------------------------------------------------------------

# Cria diretórios esperados (saída e logs).
mkdir -p "${LOG_DIR}"

# : LOG FILE -------------------------------------------------------------------

# Mensagem de confirmação
echo "Saída sendo registrada em:"
echo " - '$LOG_FILE'."
echo ""


# : PYTHON DO PROJETO (.venv) --------------------------------------------------

# Mensagem de confirmação
echo "Python a ser utilizado:"
echo " - '$PYTHON_BIN'"
echo ""

# : RODAR SCRIPT ---------------------------------------------------------------

# Roda o script Python de mapeamento PNCP -> OCDS.
# - Passa ANO e MES como variáveis de ambiente (ANO=..., MES=...)
# - E também como argumentos posicionais (para cobrir scripts que esperam argv)
# - Redireciona stdout e stderr para o arquivo de log.
echo "Iniciando o mapeamento PNCP -> OCDS..."

# Se estiver rodando via WSL chamando um Python do Windows, é comum precisar:
# - Exportar WSLENV para repassar variáveis (ANO/MES) para processos Windows.
# - Converter o caminho do script .py para formato Windows (wslpath -w).
PYTHON_SCRIPT_TO_RUN="${PYTHON_SCRIPT}"
if command -v wslpath >/dev/null 2>&1; then
  export WSLENV="${WSLENV:+${WSLENV}:}ANO:MES"
  PYTHON_SCRIPT_TO_RUN="$(wslpath -w "${PYTHON_SCRIPT}")"
fi

ANO="${ANO}" MES="${MES}" \
  "${PYTHON_BIN}" "${PYTHON_SCRIPT_TO_RUN}" >> "${LOG_FILE}" 2>&1


echo "Execução finalizada. Confira o log em: '$LOG_FILE'."
