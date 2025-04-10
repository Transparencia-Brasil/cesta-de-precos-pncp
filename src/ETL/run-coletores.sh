#!/bin/bash

echo -e "---\n# COLETORES\n---"

AGORA=$(date +"%d-%b-%Y %H:%M:%S")
echo -e "\nINÍCIO DA COLETA ÀS '$AGORA'"

# SET DIR ----------------------------------------------------------------------

# Garante que o script será executado a partir do diretório root do projeto
cd "$(dirname "$0")/../../.." || { echo "Erro: Não foi possível acessar o diretório do projeto."; exit 1; }

echo -e "\nDiretório:"
pwd
echo ""

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

# SCRIPTS ----------------------------------------------------------------------
# cada etapa possui um script coletor/classificador

COLETOR_CONTRATACOES="src/ETL/coletores/coletor-contratacoes.sh"
COLETOR_ITENS="src/ETL/coletores/coletor-itens.sh"
CLASSIFICADOR="src/ETL/classificador/filtra-medicamentos.sh"
COLETOR_RESULTADOS="src/ETL/coletores/coletor-resultados.sh"

# FILEPATHS --------------------------------------------------------------------
# os itens de saída são utilizados para checar o término da execução

CONTRATACOES_PATH="coleta/contratacoes/$ALIAS_COLETA/dados.csv"
ITENS_PATH="coleta/itens/$ALIAS_COLETA/dados.csv"
MEDICAMENTOS_PATH="coleta/itens/${ALIAS_COLETA}/medicamentos.csv"

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
  if [ -f "$DADOS_COLETADOS" ] && [[ "$RODAR_COLETOR" =~ coletor-resultados.sh ]]; then
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
    echo -e "Screen '$SCREEN_NAME' encerrada"
  fi
}

# EXECUÇÃO ---------------------------------------------------------------------

BASH_COLETA_CONTRATACOES="bash \"$COLETOR_CONTRATACOES\" ALIAS_COLETA=\"$ALIAS_COLETA\" PRIMEIRO_DIA=\"$PRIMEIRO_DIA\" ULTIMO_DIA=\"$ULTIMO_DIA\""
BASH_COLETA_ITENS="bash \"$COLETOR_ITENS\" ALIAS_COLETA=\"$ALIAS_COLETA\" PRIMEIRO_DIA=\"$PRIMEIRO_DIA\" ULTIMO_DIA=\"$ULTIMO_DIA\""
BASH_CLASSIFICADOR="bash \"$CLASSIFICADOR\" ALIAS_COLETA=\"$ALIAS_COLETA\" PRIMEIRO_DIA=\"$PRIMEIRO_DIA\" ULTIMO_DIA=\"$ULTIMO_DIA\""
BASH_RESULTADOS="bash \"$COLETOR_RESULTADOS\" ALIAS_COLETA=\"$ALIAS_COLETA\" PRIMEIRO_DIA=\"$PRIMEIRO_DIA\" ULTIMO_DIA=\"$ULTIMO_DIA\""

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
echo -e "Arquivo '$MEDICAMENTOS_PATH' criado.\nClassificação e filtragem de MEDICAMENTOS de ITENS concluída!\n"

echo -e "---\n## RESULTADOS\n"
executar_coletor "$MEDICAMENTOS_PATH" "$BASH_RESULTADOS" "$SCREEN_RESULTADOS"
echo -e "\nColeta de RESULTADOS de MEDICAMENTOS concluída!\n"

# FINALIZA COLETA --------------------------------------------------------------

AGORA=$(date +"%d-%b-%Y %H:%M:%S")
echo -e "\nCOLETA ENCERRADA ÀS '$AGORA'!"
