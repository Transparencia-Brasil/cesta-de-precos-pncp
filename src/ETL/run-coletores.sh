#!/bin/bash

echo -e "---\n# COLETORES\n---"

AGORA=$(date +"%d-%b-%Y %H:%M:%S")
echo -e "\nINÍCIO DA COLETA ÀS '$AGORA'"


# SET DIR ----------------------------------------------------------------------

echo -e "\nDiretório: ENTRADA"
pwd
echo ""

# Garante que o script será executado a partir do diretório root do projeto
cd "$(dirname "$0")/../.." || { echo "Erro: Não foi possível acessar o diretório do projeto."; exit 1; }

echo -e "\nDiretório:"
pwd
echo ""


# PARÂMETROS DO BASH -----------------------------------------------------------

# Verifica se os argumentos foram fornecidos
if [ -z "$1" ]; then
  echo "Erro: O parâmetro 'ALIAS_COLETA' é obrigatório."
  exit 1
fi

if [ -z "$2" ]; then
  echo "Erro: O parâmetro 'PRIMEIRO_DIA' é obrigatório."
  exit 1
fi

if [ -z "$3" ]; then
  echo "Erro: O parâmetro 'ULTIMO_DIA' é obrigatório."
  exit 1
fi

# Recebe parâmetros
ALIAS_COLETA=$1
PRIMEIRO_DIA=$2
ULTIMO_DIA=$3

# Mensagens de confirmação
echo "PARÂMETROS: "
echo " - PRIMEIRO_DIA='$PRIMEIRO_DIA' - é a data de início da coleta"
echo " - ULTIMO_DIA='$ULTIMO_DIA' - é a data final da coleta"
echo " - ALIAS_COLETA='$ALIAS_COLETA' - é um alias para identificar a coleta e apontar um destino no diretório de /coletas"
echo ""


# SCREENS ----------------------------------------------------------------------
# cada etapa deve gerar uma screen

SCREEN_CONTRATACOES="coletor-contratacoes-${PRIMEIRO_DIA}-ate-${ULTIMO_DIA}"
SCREEN_ITENS="coletor-itens-${PRIMEIRO_DIA}-ate-${ULTIMO_DIA}"
SCREEN_CLASSIFICADOR="classificador-itens-${PRIMEIRO_DIA}-ate-${ULTIMO_DIA}"
SCREEN_RESULTADOS="coletor-resultados-${PRIMEIRO_DIA}-ate-${ULTIMO_DIA}"
SCREEN_RECOLETA_RESULTADOS="recoletor-resultados-${PRIMEIRO_DIA}-ate-${ULTIMO_DIA}"


# SCRIPTS ----------------------------------------------------------------------
# cada etapa possui um script coletor/classificador

COLETOR_CONTRATACOES="src/ETL/coletores/coletor-contratacoes.sh"
COLETOR_ITENS="src/ETL/coletores/coletor-itens.sh"
CLASSIFICADOR="src/ETL/classificador/filtra-medicamentos.sh"
COLETOR_RESULTADOS="src/ETL/coletores/coletor-resultados.sh"
RECOLETOR_RESULTADOS="src/ETL/coletores/recoletor-resultados.sh"


# FILEPATHS --------------------------------------------------------------------
# os itens de saída são utilizados para checar o término da execução

CONTRATACOES_PATH="coleta/contratacoes/${ALIAS_COLETA}/dados.csv"
ITENS_PATH="coleta/itens/${ALIAS_COLETA}/dados.csv"
MEDICAMENTOS_PATH="coleta/itens/${ALIAS_COLETA}/medicamentos.csv"
RESULTADOS_RECOLETA_DIR="coleta/resultados/${ALIAS_COLETA}/recoleta"


# FUNÇÃO -----------------------------------------------------------------------

# Função: executar_coletor
# Descrição:
#   Esta função gerencia a execução de um coletor de dados. Ela verifica se o arquivo de dados coletados já existe
#   e solicita ao usuário confirmação para sobrescrevê-lo. Caso o arquivo não exista ou o usuário opte por sobrescrever,
#   o coletor é executado. Além disso, se um nome de screen for fornecido, a função aguarda a finalização da screen
#   antes de concluir.
#
# Parâmetros:
#   1. DADOS_COLETADOS (string): Caminho para o arquivo de dados coletados.
#   2. RODAR_COLETOR (string): Comando para executar o coletor.
#   3. SCREEN_NAME (string): Nome da screen associada ao coletor (opcional).
#
# Comportamento:
#   - Se o arquivo especificado em DADOS_COLETADOS já existir, o usuário será solicitado a confirmar se deseja
#     sobrescrevê-lo. Caso a resposta seja negativa, a execução do coletor será ignorada.
#   - Se o arquivo não existir ou o usuário optar por sobrescrevê-lo, o coletor será executado.
#   - Se um SCREEN_NAME for fornecido, a função aguardará até que a screen correspondente seja encerrada antes
#     de concluir a execução.
#
# Dependências:
#   - O comando `screen` deve estar disponível no sistema para gerenciar e verificar a existência de screens.
#
# Exemplo de uso:
#   executar_coletor "/caminho/para/dados.csv" "comando_para_executar_coletor" "nome_da_screen"
executar_coletor() {
  local DADOS_COLETADOS=$1
  local RODAR_COLETOR=$2
  local SCREEN_NAME=$3

  # Se DADOS_COLETADOS existe e RODAR_COLETOR for o de resultados das contratações, rodar coletor.
  if [ -f "$DADOS_COLETADOS" ] && ([[ "$RODAR_COLETOR" =~ coletor-resultados.sh ]] || [[ "$RODAR_COLETOR" =~ recoletor-resultados.sh ]]); then
    eval "$RODAR_COLETOR"
    echo "coletando resultados das contratações de medicamentos"
  else
    # para os demais coletores, verifica:
    #  se DADOS_COLETADOS já existe, perguntar se deseja sobreescrever
    if [ -f "$DADOS_COLETADOS" ]; then
      echo "O arquivo '$DADOS_COLETADOS' já existe. Deseja executar o coletor/classificador novamente? (s/n): "
      read resposta
      echo -e "Resposta: $resposta\n"

      # se deseja sobrescrever, remove o arquivo existente inicia nova coleta
      if [[ "$resposta" =~ ^[Ss]$ ]]; then
        rm -f "$(dirname "$DADOS_COLETADOS")"/*.csv
        echo "Arquivo '$DADOS_COLETADOS' removido."
        eval "$RODAR_COLETOR"
      else
        # se não deseja sobreescrever, ignora a execução do coletor
        echo "Execução do coletor ignorada."
        return
      fi
    #  se DADOS_COLETADOS não existe, o coletor é executado normalmente
    else
        eval "$RODAR_COLETOR"
    fi
  fi

  # Aguarda a screen encerrar, se aplicável
  if [ -n "$SCREEN_NAME" ]; then
    echo -e "\nAguardando a screen '$SCREEN_NAME' encerrar..."
    while screen -list | grep -q "$SCREEN_NAME"; do
      sleep 10
    done
    sleep 20
    echo -e "Screen $SCREEN_NAME encerrada"
  fi
}


# EXECUÇÃO ---------------------------------------------------------------------

BASH_COLETA_CONTRATACOES="bash $COLETOR_CONTRATACOES ALIAS_COLETA=$ALIAS_COLETA PRIMEIRO_DIA=$PRIMEIRO_DIA ULTIMO_DIA=$ULTIMO_DIA"
BASH_COLETA_ITENS="bash $COLETOR_ITENS ALIAS_COLETA=$ALIAS_COLETA PRIMEIRO_DIA=$PRIMEIRO_DIA ULTIMO_DIA=$ULTIMO_DIA"
BASH_CLASSIFICADOR="bash $CLASSIFICADOR ALIAS_COLETA=$ALIAS_COLETA PRIMEIRO_DIA=$PRIMEIRO_DIA ULTIMO_DIA=$ULTIMO_DIA"
BASH_RESULTADOS="bash $COLETOR_RESULTADOS ALIAS_COLETA=$ALIAS_COLETA PRIMEIRO_DIA=$PRIMEIRO_DIA ULTIMO_DIA=$ULTIMO_DIA"
BASH_RECOLETA_RESULTADOS="bash $RECOLETOR_RESULTADOS ALIAS_COLETA=$ALIAS_COLETA PRIMEIRO_DIA=$PRIMEIRO_DIA ULTIMO_DIA=$ULTIMO_DIA"


# :: CONTRATAÇÃO

echo -e "---\n## CONTRATAÇÃO\n"
executar_coletor "$CONTRATACOES_PATH" "$BASH_COLETA_CONTRATACOES" "$SCREEN_CONTRATACOES"
echo -e "\nColeta de CONTRATAÇÕES concluída!\n"


# :: ITENS

echo -e "---\n## ITENS\n"
executar_coletor "$ITENS_PATH" "$BASH_COLETA_ITENS" "$SCREEN_ITENS"
echo -e "\nColeta de ITENS concluída!\n"


# :: CLASSIFICADOR - FILTRA MEDICAMENTOS

echo -e "---\n## CLASSIFICADOR - FILTRA MEDICAMENTOS\n"
executar_coletor "$MEDICAMENTOS_PATH" "$BASH_CLASSIFICADOR"


# :: RESULTADOS

# Aguarda o arquivo 'medicamentos.csv' ser criado
echo -e "\nAguardando o arquivo '$MEDICAMENTOS_PATH' ser criado...\n"
while [ ! -f "$MEDICAMENTOS_PATH" ]; do
  sleep 10
done
echo -e "Arquivo $MEDICAMENTOS_PATH criado.\nClassificação e filtragem de MEDICAMENTOS de ITENS concluída!\n"

echo -e "---\n## RESULTADOS\n"
executar_coletor "$MEDICAMENTOS_PATH" "$BASH_RESULTADOS" "$SCREEN_RESULTADOS"
echo -e "\nColeta de RESULTADOS de MEDICAMENTOS concluída!\n"


# :: RECOLETA DE RESULTADOS (obrigatória)

echo -e "---\n## RECOLETA DE RESULTADOS\n"
executar_coletor "$RESULTADOS_RECOLETA_DIR/dados.csv" "$BASH_RECOLETA_RESULTADOS" "$SCREEN_RECOLETA_RESULTADOS"
echo -e "\nRecoleta de RESULTADOS concluída!\n"


# FINALIZA COLETA --------------------------------------------------------------

AGORA=$(date +"%d-%b-%Y %H:%M:%S")
echo -e "\nCOLETA ENCERRADA ÀS '$AGORA'!"

# EMPACOTADOR ------------------------------------------------------------------

echo -e "---\n## PACOTE DE DADOS\n"

# coleta os resultados e copia para uma estrutura de diretórios mais coerente
# para exportação no banco de dados:

# Extrair ano, mês e dia do PRIMEIRO_DIA
ANO_COLETA=${PRIMEIRO_DIA:0:4}
MES_COLETA=${PRIMEIRO_DIA:5:2}
DIA_COLETA=${PRIMEIRO_DIA:8:2}

# Determinar qual quinzena
if [ "$DIA_COLETA" = "01" ]; then
  QUINZENA="QUINZENA-1"
else
  QUINZENA="QUINZENA-2"
fi

# Converter mês numérico para abreviação
case $MES_COLETA in
  "01") MES_COLETA="1 - Janeiro" ;;
  "02") MES_COLETA="2 - Fevereiro" ;;
  "03") MES_COLETA="3 - Março" ;;
  "04") MES_COLETA="4 - Abril" ;;
  "05") MES_COLETA="5 - Maio" ;;
  "06") MES_COLETA="6 - Junho" ;;
  "07") MES_COLETA="7 - Julho" ;;
  "08") MES_COLETA="8 - Agosto" ;;
  "09") MES_COLETA="9 - Setembro" ;;
  "10") MES_COLETA="10 - Outubro" ;;
  "11") MES_COLETA="11 - Novembro" ;;
  "12") MES_COLETA="12 - Dezembro" ;;
  *) echo "Mês inválido: $MES_COLETA"; exit 1 ;;
esac

# Criar diretório para o pacote de dados
PACOTE_PATH="coleta/data-package/$ANO_COLETA/$MES_COLETA/$QUINZENA"

# Criar subdiretórios DADOS e LOG
PACOTE_PATH_DADOS="$PACOTE_PATH/DATA"
PACOTE_PATH_LOG="$PACOTE_PATH/LOG"

if [ ! -d "$PACOTE_PATH_DADOS" ]; then
  mkdir -p "$PACOTE_PATH_DADOS"
  echo "Diretório '$PACOTE_PATH_DADOS' criado."
fi

if [ ! -d "$PACOTE_PATH_LOG" ]; then
  mkdir -p "$PACOTE_PATH_LOG"
  echo "Diretório '$PACOTE_PATH_LOG' criado."
fi

# Copiar arquivos de contratações
CONTRATACOES_PATH="coleta/contratacoes/${ALIAS_COLETA}"
ITENS_PATH="coleta/itens/${ALIAS_COLETA}"
RESULTADOS_PATH="coleta/resultados/${ALIAS_COLETA}"
RESULTADOS_RECOLETA_PATH="${RESULTADOS_PATH}/recoleta"

# Copiar arquivos de contratações
cp "${CONTRATACOES_PATH}/dados.csv" "${PACOTE_PATH_DADOS}/contratacoes.csv"
cp "${CONTRATACOES_PATH}/erros.csv" "${PACOTE_PATH_DADOS}/contratacoes-erros.csv"
cp "${CONTRATACOES_PATH}/monitoramento.csv" "${PACOTE_PATH_DADOS}/contratacoes-monitoramento.csv"

# Copiar arquivos de itens
cp "${ITENS_PATH}/dados.csv" "${PACOTE_PATH_DADOS}/itens.csv"
cp "${ITENS_PATH}/erros.csv" "${PACOTE_PATH_DADOS}/itens-erros.csv"
cp "${ITENS_PATH}/monitoramento.csv" "${PACOTE_PATH_DADOS}/itens-monitoramento.csv"
cp "${ITENS_PATH}/medicamentos.csv" "${PACOTE_PATH_DADOS}/itens-medicamentos.csv"

# Copiar arquivos de resultados
cp "${RESULTADOS_PATH}/dados.csv" "${PACOTE_PATH_DADOS}/itens-medicamentos-resultados.csv"
cp "${RESULTADOS_PATH}/erros.csv" "${PACOTE_PATH_DADOS}/itens-medicamentos-resultados-erros.csv"
cp "${RESULTADOS_PATH}/monitoramento.csv" "${PACOTE_PATH_DADOS}/itens-medicamentos-resultados-monitoramento.csv"

# Copiar arquivos de recoleta (se existirem)
if [ -d "$RESULTADOS_RECOLETA_PATH" ]; then
  cp "${RESULTADOS_RECOLETA_PATH}/dados.csv" "${PACOTE_PATH_DADOS}/itens-medicamentos-resultados-recoleta.csv" 2>/dev/null || true
  cp "${RESULTADOS_RECOLETA_PATH}/erros.csv" "${PACOTE_PATH_DADOS}/itens-medicamentos-resultados-recoleta-erros.csv" 2>/dev/null || true
  cp "${RESULTADOS_RECOLETA_PATH}/monitoramento.csv" "${PACOTE_PATH_DADOS}/itens-medicamentos-resultados-recoleta-monitoramento.csv" 2>/dev/null || true
fi

# Confirmar cópia dos csv's
echo -e "\nArquivos csv copiados para ${PACOTE_PATH_DADOS}"

# Copiar todos os arquivos de log
cp "${CONTRATACOES_PATH}"/*.log "${PACOTE_PATH_LOG}/" 2>/dev/null || true
cp "${ITENS_PATH}"/*.log "${PACOTE_PATH_LOG}/" 2>/dev/null || true
cp "${RESULTADOS_PATH}"/*.log "${PACOTE_PATH_LOG}/" 2>/dev/null || true
if [ -d "$RESULTADOS_RECOLETA_PATH" ]; then
  cp "${RESULTADOS_RECOLETA_PATH}"/*.log "${PACOTE_PATH_LOG}/" 2>/dev/null || true
fi

# Exibe a árvore de diretórios do pacote
echo -e "\nEstrutura do pacote de dados:\n"
if command -v tree &> /dev/null; then
  tree -h -- "${PACOTE_PATH}"
else
    echo "Comando 'tree' não encontrado. Instalando..."
    sudo apt-get update && sudo apt-get install tree -y
    tree -h -- "${PACOTE_PATH}"
fi

# Encontra o arquivo de log mais recente em src/ETL e seus subdiretórios
LATEST_LOG=$(find src/ETL -type f -name "*.log" -printf '%T@ %p\n' | sort -n | tail -1 | cut -f2- -d" ")

if [ -n "$LATEST_LOG" ]; then
  cp "$LATEST_LOG" "${PACOTE_PATH_LOG}/"
fi

# Confirmar cópia dos logs
echo -e "\nArquivos de log copiados para ${PACOTE_PATH_LOG}"
echo -e "\nFim! =)"
