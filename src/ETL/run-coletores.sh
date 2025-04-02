#!/bin/bash

echo "---"
echo "COLETORES"
echo ""


# SET DIR ----------------------------------------------------------------------

# Garante que o script será executado a partir do diretório root do projeto
cd "$(dirname "$0")/../.." || exit 1

echo "Diretório:"
pwd
echo ""

DATA_COLETA="TESTE"
PRIMEIRO_DIA="2025-01-01"
ULTIMO_DIA="2025-01-05"


# SCREENS ----------------------------------------------------------------------

# Nome da screen criada por este script
SCREEN_RUN_COLETORES="COLETA-${DATA_COLETA}"

# Nome da screen criada pelo coletor de contratações
SCREEN_CONTRATACOES="coletor-contratacoes-${PRIMEIRO_DIA}-ate-${ULTIMO_DIA}"

# Nome da screen criada pelo coletor de itens
SCREEN_ITENS="coletor-itens-${PRIMEIRO_DIA}-ate-${ULTIMO_DIA}"

# Nome da screen criada pelo classificador
SCREEN_CLASSIFICDOR="classificador-itens-${PRIMEIRO_DIA}-ate-${ULTIMO_DIA}"


# SCRIPTS ----------------------------------------------------------------------

# Script em bash para coletor de contratações
COLETOR_CONTRATACOES="src/ETL/coletores/coletor-contratacoes.sh"

# Script em bash para coletor de itens
COLETOR_ITENS="src/ETL/coletores/coletor-itens.sh"

# Script em bash para filtragem e classificação de medicamentos
CLASSIFICADOR="src/ETL/classificador/filtra-medicamentos.sh"


# EXECUÇÃO ---------------------------------------------------------------------

echo ""
echo "INICIANDO COLETAS NA SCREEN: '$SCREEN_RUN_COLETORES'"
echo ""
screen -S "${SCREEN_RUN_COLETORES}"

# :: CONTRATAÇÃO

# Executa o coletor de contratações
bash "$COLETOR_CONTRATACOES" DATA_COLETA="$DATA_COLETA" PRIMEIRO_DIA="$PRIMEIRO_DIA" ULTIMO_DIA="$ULTIMO_DIA"

# Aguarda a screen do coletor de contratações encerrar
echo ""
echo "Aguardando a screen '$SCREEN_CONTRATACOES' encerrar..."
while screen -list | grep -q "$SCREEN_CONTRATACOES"; do
  sleep 10  # Aguarda 10 segundos antes de verificar novamente
done
echo "Screen '$SCREEN_CONTRATACOES' encerrada."
echo ""


# :: ITENS

# Executa o coletor de itens somente após o termino da task de contratações
bash "$COLETOR_ITENS" DATA_COLETA="$DATA_COLETA" PRIMEIRO_DIA="$PRIMEIRO_DIA" ULTIMO_DIA="$ULTIMO_DIA"

# Aguarda a screen do coletor de itens encerrar
echo ""
echo "Aguardando a screen '$SCREEN_ITENS' encerrar..."
while screen -list | grep -q "$SCREEN_ITENS"; do
  sleep 10  # Aguarda 10 segundos antes de verificar novamente
done
echo "Screen '$SCREEN_ITENS' encerrada."
echo ""


# :: CLASSIFICADOR - FILTRA MEDICAMENTOS

# Executa o classificador somente após o termino da task de contratações
bash "$CLASSIFICADOR" DATA_COLETA="$DATA_COLETA" PRIMEIRO_DIA="$PRIMEIRO_DIA" ULTIMO_DIA="$ULTIMO_DIA"


# Aguarda a screen do coletor de itens encerrar
echo ""
echo "Aguardando a screen '$SCREEN_CLASSIFICADOR' encerrar..."
while screen -list | grep -q "$SCREEN_CLASSIFICADOR"; do
  sleep 10  # Aguarda 10 segundos antes de verificar novamente
done
echo "Screen '$SCREEN_CLASSIFICADOR' encerrada."
echo ""


# FINALIZA COLETA --------------------------------------------------------------

echo ""
echo "Screen '$SCREEN_RUN_COLETORES' encerrada."
echo ""
screen -S "${SCREEN_RUN_COLETORES}" -X quit