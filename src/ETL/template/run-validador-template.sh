#!/bin/bash
set -euo pipefail

# Garante que o script sera executado a partir do diretorio root do projeto.
cd "$(dirname "$0")/../../.." || { echo "Erro: Nao foi possivel acessar o diretorio do projeto."; exit 1; }

PYTHON_BIN="${PYTHON_BIN:-./.venv/Scripts/python.exe}"

if [ ! -x "$PYTHON_BIN" ]; then
  echo "Python definido em PYTHON_BIN nao encontrado ou nao executavel: '$PYTHON_BIN'"
  echo "Tentando usar 'python' disponivel no PATH."
  PYTHON_BIN="python"
fi

SCRIPT_TEMPLATE="src/ETL/template/src/python/atualiza-templates.py"

echo -e "---\n# VALIDADOR DE TEMPLATES PNCP\n---"
echo "Script:"
echo " - '$SCRIPT_TEMPLATE'"
echo "Python:"
echo " - '$PYTHON_BIN'"
echo ""

"$PYTHON_BIN" "$SCRIPT_TEMPLATE" "$@"
