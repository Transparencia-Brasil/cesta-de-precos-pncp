#!/bin/bash

echo -e "---\n# COLETORES\n---"


# SET DIR ----------------------------------------------------------------------

# Garante que o script será executado a partir do diretório root do projeto
cd "$(dirname "$0")/../.." || exit 1

echo -e "\nDiretório:"
pwd
echo ""

DATA_COLETA="TESTE"
PRIMEIRO_DIA="2025-01-01"
ULTIMO_DIA="2025-01-2"

# Mensagens de confirmação
echo "PARÂMETROS: "
echo " - '$PRIMEIRO_DIA'"
echo " - '$ULTIMO_DIA'"
echo " - '$DATA_COLETA'"
echo ""

# SCREENS ----------------------------------------------------------------------

# Nome da screen criada pelo coletor de contratações
SCREEN_CONTRATACOES="coletor-contratacoes-${PRIMEIRO_DIA}-ate-${ULTIMO_DIA}"

# Nome da screen criada pelo coletor de itens
SCREEN_ITENS="coletor-itens-${PRIMEIRO_DIA}-ate-${ULTIMO_DIA}"

# Nome da screen criada pelo classificador
SCREEN_CLASSIFICADOR="classificador-itens-${PRIMEIRO_DIA}-ate-${ULTIMO_DIA}"

echo "SCREENS:"
echo " - '$SCREEN_CONTRATACOES': executa o coletor de contratações"
echo " - '$SCREEN_ITENS': executa o coletor de itens"
echo " - '$SCREEN_CLASSIFICADOR': executa a filtragem e classificação de itens"
echo ""

# SCRIPTS ----------------------------------------------------------------------

# Script em bash para coletor de contratações
COLETOR_CONTRATACOES="src/ETL/coletores/coletor-contratacoes.sh"

# Script em bash para coletor de itens
COLETOR_ITENS="src/ETL/coletores/coletor-itens.sh"

# Script em bash para filtragem e classificação de medicamentos
CLASSIFICADOR="src/ETL/classificador/filtra-medicamentos.sh"

echo "SCRIPTS:"
echo " - '$COLETOR_CONTRATACOES': executa o coletor de contratações"
echo " - '$COLETOR_ITENS': executa o coletor de itens"
echo " - '$CLASSIFICADOR': executa a filtragem e classificação de itens"
echo ""

# EXECUÇÃO ---------------------------------------------------------------------

# :: CONTRATAÇÃO\n
echo -e "## CONTRATAÇÃO\n"

# Executa o coletor de contratações
bash "$COLETOR_CONTRATACOES" DATA_COLETA="$DATA_COLETA" PRIMEIRO_DIA="$PRIMEIRO_DIA" ULTIMO_DIA="$ULTIMO_DIA"

# Aguarda a screen do coletor de contratações encerrar
echo -e "\nAguardando a screen '$SCREEN_CONTRATACOES' encerrar..."
while screen -list | grep -q "$SCREEN_CONTRATACOES"; do
  sleep 10  # Aguarda 10 segundos antes de verificar novamente
done
echo -e "Screen '$SCREEN_CONTRATACOES' encerrada.\n"


# :: ITENS
echo -e "## ITENS\n"

# Executa o coletor de itens somente após o termino da task de contratações
bash "$COLETOR_ITENS" DATA_COLETA="$DATA_COLETA" PRIMEIRO_DIA="$PRIMEIRO_DIA" ULTIMO_DIA="$ULTIMO_DIA"

# Aguarda a screen do coletor de itens encerrar
echo -e "\nAguardando a screen '$SCREEN_ITENS' encerrar..."
while screen -list | grep -q "$SCREEN_ITENS"; do
  sleep 10  # Aguarda 10 segundos antes de verificar novamente
done
echo -e "Screen '$SCREEN_ITENS' encerrada.\n"


# :: CLASSIFICADOR - FILTRA MEDICAMENTOS
echo -e "## CLASSIFICADOR - FILTRA MEDICAMENTOS\n"

# Executa o classificador somente após o termino da task de contratações
bash "$CLASSIFICADOR" DATA_COLETA="$DATA_COLETA" PRIMEIRO_DIA="$PRIMEIRO_DIA" ULTIMO_DIA="$ULTIMO_DIA"


# Aguarda a screen do coletor de itens encerrar
echo -e "\nAguardando a screen '$SCREEN_CLASSIFICADOR' encerrar...\n"
while screen -list | grep -q "$SCREEN_CLASSIFICADOR"; do
  sleep 10  # Aguarda 10 segundos antes de verificar novamente
done
echo -e "\nScreen '$SCREEN_CLASSIFICADOR' encerrada.\n"


# FINALIZA COLETA --------------------------------------------------------------

AGORA=$(date +"%d-%m-%Y %H:%M:%S")
echo -e "\nCOLETA ENCERRADA ÀS '$AGORA'!"
