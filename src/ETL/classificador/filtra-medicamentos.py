"""
Este script identifica quais itens são medicamentos dentre uma lista de itens passada como argumento.

Parâmetros:
1. itens (obrigatório) - Caminho para um arquivo .csv contendo os itens a serem identificados. A descricao do item
deve estar em uma coluna chamada 'descricao'.

2. Catálogo (obrigatório) - Caminho para um arquivo .csv contendo o catálogo de medicamentos que será utilizado
como referência para identificar os medicamentos dentre os itens.

Método:
1 - Primeiro os itens são varridos para verificar se sua descrição contém algum nome PDM do catálogo.
Isso agiliza identificar potenciais candidatos a medicamentos.
2 - Um modelo LLM transforma as descrições dos itens candidatos a medicamentos em embeddings e faz o mesmo
com as descrições dos medicamentos no catálogo.
3 - Os embeddings dos itens candidatos são comparados com os embeddings dos medicamentos do catálogo que possuem o mesmo PDM.
A similaridade do coseno é a métrica de comparação e então o medicamento do catálogo com maior similaridade é escolhido como
párea do item candidato.
4 - Os itens cujos páreas possuírem similaridade igual ou superior a 0.5 serão classificados como medicamento.
O valor 0.5 foi definido experimentalmente como sendo o limite que rende os melhores resultados de acurácia.

Por fim, os medicamentos idntificados são salvos em um arquivo chamado 'medicamentos.csv', junto com o código BR do item
mais similar do catálogo. Os embeddings do catálogo são salvos em um arquivo (catalogo-vetorizado.csv) para evitar calculá-los a
cada execução do script.
"""

import argparse  # Conversor para opções de linha de comando
import json  # Codificador e decodificador JSON
import os  # Sistema operacional
import unicodedata  # Unicode Database

import nltk  # Natural Language ToolKit
import numpy as np  # Computação científica
import pandas as pd  # Análise de dados
from nltk.corpus import stopwords
from sentence_transformers import SentenceTransformer

# Baixa stopwords caso ainda não tenha
nltk.download('stopwords')

### PARÂMETROS DO SCRIPT #################################################################

print('\rValidando os argumentos.', end="", flush=True)

# Define os parâmetros 'itens'e 'catalogo'
parser = argparse.ArgumentParser()
# arquivos são csvs
parser.add_argument("itens", help="Caminho para o arquivo .csv de itens de contratações.")
parser.add_argument("catalogo", help="Caminho para o arquivo .csv de catálogo de medicamentos.")

args = parser.parse_args()

# Valida as extensões dos arquivos
if os.path.splitext(args.itens)[1].lower() != ".csv":
    raise ValueError("A extensão do arquivo de itens (primeiro argumento) deve ser .csv")

if os.path.splitext(args.catalogo)[1].lower() != ".csv":
    raise ValueError("A extensão do arquivo de catálogo (segundo argumento) deve ser .csv")

# Diretórios dos arquivos de entrada (onde serão salvos os arquivos gerados)
dir_itens = os.path.dirname(args.itens)
dir_catalogo = os.path.dirname(args.catalogo)

# Carrega os dados
catmat_df = pd.read_csv(args.catalogo)  # CATMAT
itens_df = pd.read_csv(args.itens, on_bad_lines='warn', encoding='utf-8', engine='python')      # Itens PNCP


### DETECÇÃO DE PDMS ######################################################################

print('\rDetectando nomes PDM nos itens.', end="", flush=True)

def limpa_texto(texto):
    """
    Limpa o texto fornecido realizando uma série de transformações:

    1. Converte o texto para minúsculas.
    2. Remove stopwords em português.
    3. Remove acentos.
    4. Remove espaços em branco adicionais.

    Parâmetros:
    -----------
    texto : str
        O texto que será processado e limpo.

    Retorno:
    --------
    str
        O texto limpo após todas as transformações.

    Exemplo:
    --------
    >>> limpa_texto("Aminofilina 24mg/mL - Solução injetável - Ampola com 10mLBR0292402")
    'aminofilina 24mg/ml - solucao injetavel - ampola 10mlbr0292402'
    """
    # Deixa o texto em minúsculo
    texto = texto.lower()

    # Lista de stopwords em português
    stop_words = set(stopwords.words('portuguese'))

    # Remove stop words
    palavras = texto.split()
    palavras_filtradas = [palavra for palavra in palavras if palavra.lower() not in stop_words]
    texto = " ".join(palavras_filtradas)

    # remove acentos
    texto = ''.join(c for c in unicodedata.normalize('NFKD', texto) if not unicodedata.combining(c))

    # Remove espaços em branco adicionais
    texto = ' '.join(texto.split())

    return(texto)

# Limpa os nomes pdms do CATMAT e a descrição dos itens do PNCP
catmat_df['nome_pdm_limpo'] = catmat_df['nome_pdm'].fillna('').apply(str).apply(limpa_texto)
itens_df['descricao_limpa'] = itens_df['descricao'].fillna('').apply(str).apply(limpa_texto)

# Cria um dicionário de consulta aos pdms do CATMAT
# Cada chave do dicionário é uma palavra e o valor é um conjunto de PDMs que contém aquela palavra
# Por exemplo dic_consulta_pdm['acido'] retorna  {361, 1730, 1731, 1733, 1744, 1747, 1751, 1767, 1782, ...}
dic_consulta_pdm = {}

for linha in catmat_df[['codigo_pdm', 'nome_pdm_limpo']].itertuples(index=False):  # a cada nome pdm
    palavras = linha.nome_pdm_limpo.split(' ')   # separa as palavras do nome pdm
    pdm = int(linha.codigo_pdm)
    for palavra in palavras:                     # para cada palavra adiciona o codigo pdm ao conjunto
        if palavra in dic_consulta_pdm:
            dic_consulta_pdm[palavra].add(pdm)
        else:
            dic_consulta_pdm[palavra] = set([pdm])


def detecta_pdm(descricao):
    """
    Identifica o código PDM (Padrão Descritivo de Material) associado a uma descrição textual.

    A função verifica quais palavras da descrição estão no dicionário `dic_consulta_pdm`,
    que mapeia palavras a conjuntos de códigos PDM. Se uma palavra estiver no dicionário,
    a função refina os possíveis códigos PDM por interseção até restar apenas um.

    Parâmetros:
    -----------
    descricao : str
        Texto contendo a descrição do item.

    Retorno:
    --------
    str ou None
        O código PDM identificado, caso seja possível determinar um único código, ou `None` caso não haja correspondência.

    Exemplo:
    --------
    >>> dic_consulta_pdm = {
    ...     "acido": {"353", "354"},
    ...     "acetilsalicilico": {"353"},
    ...     "folico": {"354"}
    ... }
    >>> detecta_pdm("acido 50mg acetilsalicilico")
    '353'

    >>> detecta_pdm("acido xarope")
    None
    """
    palavras = descricao.split(' ')
    pdms = set()
    for palavra in palavras:
        if palavra in dic_consulta_pdm:
            if len(pdms) == 0:
                pdms = dic_consulta_pdm[palavra]
            else:
                pdms = pdms.intersection(dic_consulta_pdm[palavra])
            if len(pdms) == 1:
                break

    return list(pdms)[0] if len(pdms) == 1 else None

# Identifica, quando possível, um potencial código PDM (de medicamento) para um item do PNCP
itens_df['codigo_pdm'] = itens_df['descricao_limpa'].apply(detecta_pdm)

# Filtra só os itens detectados como medicamentos
medicamentos_df = itens_df[itens_df['codigo_pdm'].notna()]


### MODELO (TRANSFORMER) #################################################################

print('\rCarregando o modelo.', end="", flush=True)

# Carrega o modelo
# Mais informações em: https://huggingface.co/Snowflake/snowflake-arctic-embed-l-v2.0
model_name = 'Snowflake/snowflake-arctic-embed-l-v2.0'
model = SentenceTransformer(model_name)


### VETORIZAÇÃO DO CATÁLOGO ###############################################################

NOME_CATALOGO_VETORIZADO = dir_catalogo + "/catalogo-vetorizado.csv"

# Verifica se já existe um arquivo vetorizado do catálogo.
# Se não existir um catalogo vetorizado, cria-se um.
if not os.path.exists(NOME_CATALOGO_VETORIZADO):
    # Computa os vetores (embeddings)
    print('\rCalculando os vetores do catálogo.', end="", flush=True)
    documentos = catmat_df['nome_item']
    embeddings = model.encode(documentos)

    # Adiciona os embeddings como uma coluna no dataframe
    catmat_df['embedding'] = list(embeddings)

    # Coverte os embeddings para json antes de salvar para manter o formato
    catmat_df['embedding'] = catmat_df['embedding'].apply(lambda x: json.dumps(x.tolist()))

    # Salvando o catalogo vetorizado no formato CSV
    print(f'\rVetorização do catálogo completa. Resultados salvos em {NOME_CATALOGO_VETORIZADO}', end="")
    catmat_df.to_csv(NOME_CATALOGO_VETORIZADO, index=False)
else:
    catmat_df = pd.read_csv(NOME_CATALOGO_VETORIZADO)

    # Converte a coluna de embeddings para um array numpy
    catmat_df['embedding'] = catmat_df['embedding'].apply(lambda x: np.array(json.loads(x)))

# Define o código PDM como índice
catmat_df.set_index('codigo_pdm', inplace=True)


### VETORIZAÇÃO DOS ITENS PNCP ###############################################################

print('\rCalculando os vetores das descrições dos itens do PNCP.', end="", flush=True)

# Computa os vetores (embeddings) das descrições dos itens
consultas = medicamentos_df['descricao']
embeddings = model.encode(consultas, prompt_name="query")

# Adiciona os embeddings como uma coluna no dataframe
medicamentos_df['embedding'] = list(embeddings)


### CLASSIFICAÇÃO DE MEDICAMENTOS ###############################################################

print('\rIdentificando os medicamentos', end="", flush=True)

# Limite definido experimentalmente para classificar um item como medicamento ou não
THRESHOLD = 0.5

# Caminho do arquivo de saída ondes serão salvos os medicamentos
NOME_ARQUIVO_MEDICAMENTOS = dir_itens + "/medicamentos.csv"

def mais_similar(medicamento):
    """
    Retorna o medicamento do CATMAT cujo embedding da descrição é o mais similar ao embedding
    da descrição do medicamento passado como argumento para a função.

    Parâmetros:
    ----------
    medicamento : object <class 'pandas.core.series.Series'>
        Uma série pandas (possivelmente uma linha de um dataframe) que deve conter as dimensões
        'embedding' (vetor de números) e 'codigo_pdm'.

    Retorna:
    -------
    str, float
        Uma tupla com o código BR do item do CATMAT mais similar à consulta e a similaridade (do cosseno)
    """

    # embedding da descrição do item no PNCP
    consulta = medicamento['embedding'].astype(np.float32)

    # Código PDM do item no PNCP.
    codigoPDM = medicamento['codigo_pdm']

    # Seleciona os itens do CATMAT que possuem o mesmo PDM do item do PNCP
    itens_pdm = catmat_df.loc[[codigoPDM]] # Use double brackets para forçar o resultado a ser um dataframe

    # Converte os embeddings para np.array e garante dtype float32
    embeddings_array = np.vstack(itens_pdm['embedding'].apply(lambda x: np.array(x, dtype=np.float32)))


    # Computa a similaridade entre os embeddings da descrição do CATMAT e o embedding do item do PNCP
    similaridades = model.similarity(consulta, embeddings_array)
    itens_pdm['similaridade'] = similaridades.numpy()[0]

    # Define o índice como o codigo_br para agilizar a próxima operação
    itens_pdm.set_index('codigo_br', inplace=True)

    # Identifica o código BR do item do CATMAT com maior similaridade
    medicamento_mais_similar = itens_pdm.loc[itens_pdm['similaridade'].idxmax()].name
    similaridade = itens_pdm.loc[medicamento_mais_similar].similaridade

    return medicamento_mais_similar, similaridade


# Encontra o codigo br do medicamento do CATMAT mais similar a cada item do PNCP
medicamentos_df[['codigo_br', 'similaridade']] = medicamentos_df.apply(mais_similar, axis=1, result_type='expand')

# Itens acima do limite são rotulados como medicamentos
medicamentos_df['medicamento'] = medicamentos_df['similaridade'] >= THRESHOLD

# Filtra somente os itens que são medicamentos
medicamentos_df = medicamentos_df[medicamentos_df['medicamento']]

# Remove colunas criadas desnecessárias
medicamentos_df.drop(['descricao_limpa'], axis=1, inplace=True)

# Converte o codigo_br em inteiro
medicamentos_df['codigo_br'] = medicamentos_df['codigo_br'].astype(int)

# Salva o arquivo de medicamentos em formato CSV
medicamentos_df.to_csv(NOME_ARQUIVO_MEDICAMENTOS, index=False)

print(f'\rFim da execução. Medicamentos salvos em {NOME_ARQUIVO_MEDICAMENTOS}', end="")
