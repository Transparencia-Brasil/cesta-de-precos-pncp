#' Recoleta resultados de itens ainda não homologados
#' 
#' Descrição - Nem sempre a homologação (resultado) do item estará disponível ao
#' coletar os dados do item contratado. Estes itens ainda não homologados são salvos
#' no banco de dados e a cada coleta esta lista de itens é revisitada para identificar
#' quais já possuem resultado (homologação) que pode ser coletado.
#' 
#' Entrada:  
#'  * Lista de identificadores de itens (medicamentos) que ainda não foram homologados.
#'    (essa lista vem do banco de dados. Ela não é passada como parâmetro do script)
#'  * Tem o parâmetro opcional que é o diretório onde os resultados da coleta serão salvos.
#'    (similar aos outros arquivos da coleta)
#' 
#' Saída:
#'  * Arquivo com os resultados dos itens das contratações
#'  * Arquivo de log de monitoramento da coleta
#'  * Arquivo com erros de coleta
#' 
#' Resultado:
#'   * Os dados coletados deverão ser inseridos no banco no formato correspondente.
#'   * Os itens homologados devem ser removidos da lista de itens ainda não homologados.
#'   



# PARÂMETROS DE ENTRADAS --------------------------------------------------

# Se o usuário tiver passado o parâmetro opcional de entrada, salve-o em uma variável
# Se não tiver passado, defina o valor padrão similar aos demais arquivos da coleta


# CONECTA-SE AO BANCO -----------------------------------------------------

#' Você vai precisar rodar uma cópia do banco localmente para testar o script.
#' Eu deixei um dump do banco no slack.


# EXTRAI LISTA DE ITENS AINDA NÃO HOMOLOGADOS -----------------------------

#' Faz a consulta no banco para retornar esta lista. É só pegar a coluna urlAPI
#' da tabela item_licitado
#' SELECT urlAPI FROM item_licitado
#' Depois, você vai gerar os endpoints dos resultados a partir dos endpoints dos itens.


# RECOLETA OS RESULTADOS --------------------------------------------------

#' Agora é só chamar a função de coleta (funcoes.R) passando a lista de endpoints a coletar.
#' Os resultados serão salvos no diretório passado como parâmetro (ou o valor padrão definido)


# INSERE RESULTADOS NO BANCO ----------------------------------------------

#' Para os itens que tiveram resultados coletados:
#' Agora você vai formatar os dados para inserí-los na tabela item_homologado.
#' Só precisa basicamente adicionar as colunas referentes aos resultados.
#' Salve os ids dos itens em algum lugar pois será preciso remover estes itens da tabela item_licitado.


# REMOVE ITENS HOMOLOGADOS DA TABELA ITEM_LICITADO ------------------------

#' Agora, para os itens que foram homologados, remova-os da tabela item_licitado 
#' pela chave (numero_controle_pncp, numero_item)
#' feche a conexão com o banco e FIM.


