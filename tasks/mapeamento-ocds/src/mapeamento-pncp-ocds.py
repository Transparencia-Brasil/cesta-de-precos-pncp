"""
Este script transforma contratações públicas em formato compatível com o padrão OCDS (Open Contracting Data Standard).
Ele processa dados de contratações, itens e resultados e gera arquivos JSON e ZIP por estado.
Comentários explicativos estão distribuídos ao longo do código original.
"""

import json
import locale
import os
import sys
import zipfile
from datetime import datetime, timezone

import pandas as pd
from tqdm import tqdm

# : PARÂMETROS -----------------------------------------------------------------

# Pega os parâmetros MES e ANO de coleta
# Essa informação será usada para:
# - gerar o nome do arquivo de entrada
# - gerar o nome do arquivo de saída
if "ANO" in os.environ:
    ano_coleta = int(os.environ["ANO"])
else:
    sys.stderr.write("Invalid arguments, missing parameter: 'ANO'.\n")
    os._exit(1)

if "MES" in os.environ:
    mes_coleta = int(os.environ["MES"])
else:
    sys.stderr.write("Invalid arguments, missing parameter: 'MES'.\n")
    os._exit(1)


# FILEPATHS --------------------------------------------------------------------

# Aqui o usuário deverá setar para seu próprio diretório
base_dir = "C:/Users/rdurl/OneDrive/Documentos/cesta-de-precos-pncp"

def get_filepaths(base_dir, ano_coleta, mes_coleta):
    """
    Retorna os caminhos dos arquivos CSV de contratações, itens e resultados
    para as duas quinzenas do mês especificado.

    Parâmetros:
        base_dir (str): Diretório base dos dados.
        ano_coleta (int): Ano da coleta.
        mes_coleta (int): Mês da coleta (1 a 12).

    Retorna:
        FilePaths: namedtuple com os caminhos dos arquivos.
    """
    # arquivos da quinzena 1 (q1) e 2 (q2)
    FilePaths = namedtuple('FilePaths', [
        'contratacoes_q1',
        'contratacoes_q2',
        'itens_q1',
        'itens_q2',
        'resultados_q1',
        'resultados_q2'
    ])

    # Transforma meses em pt-br
    MESES_PTBR = {
        1: "Janeiro", 2: "Fevereiro", 3: "Março", 4: "Abril",
        5: "Maio", 6: "Junho", 7: "Julho", 8: "Agosto",
        9: "Setembro", 10: "Outubro", 11: "Novembro", 12: "Dezembro"
    }

    # define diretório de coleta/data-package
    ano_dir = str(ano_coleta)
    mes_dir = f"{mes_coleta} - {MESES_PTBR[mes_coleta]}"
    coleta_dir = os.path.join(base_dir, "coleta", "data-package", ano_dir, mes_dir)

    # define path dos arquivos
    def path(quinzena, filename):
        return os.path.join(coleta_dir, f"QUINZENA-{quinzena}", "DATA", filename)

    return FilePaths(
        contratacoes_q1=path(1, "contratacoes.csv"),
        contratacoes_q2=path(2, "contratacoes.csv"),
        itens_q1=path(1, "itens-medicamentos.csv"),
        itens_q2=path(2, "itens-medicamentos.csv"),
        resultados_q1=path(1, "itens-medicamentos-resultados.csv"),
        resultados_q2=path(2, "itens-medicamentos-resultados.csv")
    )

# chamando a função
paths = get_filepaths(base_dir, ano_coleta, mes_coleta)


# : CARREGA DADOS --------------------------------------------------------------

def carregar_e_concatenar(path1, path2):
    return pd.concat([
        pd.read_csv(path1, low_memory=False),
        pd.read_csv(path2, low_memory=False)
    ], ignore_index=True)

contratacoes = carregar_e_concatenar(paths.contratacoes_q1, paths.contratacoes_q2)
itens = carregar_e_concatenar(paths.itens_q1, paths.itens_q2)
resultados = carregar_e_concatenar(paths.resultados_q1, paths.resultados_q2)


# : REMOVE COLUNAS DESNECESSÁRIAS ----------------------------------------------

# colunas de metadados da API
colunas_desnecessaria = [
    'totalRegistros',
    'totalPaginas',
    'numeroPagina',
    'paginasRestantes',
    'empty',
    'endpoint'
]

# drop colunas de metadados da API
contratacoes = contratacoes.drop(columns= colunas_desnecessaria, errors='ignore')


# : REMOVE DUPLICATAS ----------------------------------------------------------

contratacoes = contratacoes.drop_duplicates()
itens = itens.drop_duplicates()
resultados = resultados.drop_duplicates()


# : FUNÇÕES AUXILIARES ---------------------------------------------------------

# Função para converter data para o formato OCDS
# Formato esperado: 'YYYY-MM-DDTHH:MM:SSZ'
def to_ocds_dt(data):
    try:
        dt = datetime.fromisoformat(data).astimezone(timezone.utc)
        ocds_dt = dt.strftime('%Y-%m-%dT%H:%M:%SZ')
        return ocds_dt
    except Exception as e:
        print(f"Erro ao converter data: {e} ->> {data}: {type(data)}")
        return None

# Função para calcular a duração em dias entre duas datas no formato ISO
def duracao_em_dias(data_inicio, data_fim):
  try:
    inicio = datetime.fromisoformat(data_inicio)
    fim = datetime.fromisoformat(data_fim)
    duracao = (fim - inicio).days
    return duracao
  except Exception as e:
    print(f"Erro ao calcular duração: {e} ->> {data_inicio}: {type(data_inicio)} || ->> {data_fim}: {type(data_fim)}")
    return None

# Extrai cnpj, ano e sequencial da coluna numeroControlePNCP
def extrair_parametros(numero_controle):
    cnpj, _, sequencial_ano = numero_controle.partition('-1-')
    sequencial, _, ano = sequencial_ano.partition('/')
    sequencial = str(int(sequencial))  # remove zeros à esquerda
    return pd.Series([cnpj, ano, sequencial])

# Função para verificar se o endpoint do item bate com os campos da contratação
def match_endpoint(endpoint, cnpj, ano, sequencial):
    return (
        str(cnpj) in str(endpoint) and
        str(ano) in str(endpoint) and
        f'/{int(sequencial)}/' in str(endpoint)  # evita colisões tipo 81, 181, etc.
    )


# : REMOVE DATAS DE PUBLICAÇÃO INVÁLIDA ----------------------------------------

def remove_e_separa_contratacoes_por_data_publicacao(df):
    """
    Aplica a função to_ocds_dt() no campo dataPublicacaoPncp e separa o DataFrame em dois:
    - contratacoes_sem_data: linhas onde a data convertida é NA
    - contratacoes_com_data: linhas onde a data convertida não é NA
    Retorna (contratacoes_sem_data, contratacoes_com_data)
    """
    df = df.copy()
    df['data.dataPublicacaoPncp_ocds'] = df['data.dataPublicacaoPncp'].apply(to_ocds_dt)
    contratacoes_sem_data = df[df['data.dataPublicacaoPncp_ocds'].isna()].copy()
    contratacoes_com_data = df[df['data.dataPublicacaoPncp_ocds'].notna()].copy()

    # quantos erros tiveram?
    total_erros = len(contratacoes_sem_data)

    # total_erros > 0? Salva as contratações sem data em um arquivo CSV para análise posterior
    if total_erros > 0:
        errors_dir = os.path.join(base_dir, "tasks", "mapeamento-ocds", "output", "errors")
        os.makedirs(errors_dir, exist_ok=True)
        error_file = os.path.join(errors_dir, f"errors-{mes_coleta}-{ano_coleta}.csv")
        contratacoes_sem_data.to_csv(error_file, index=False, encoding="utf-8")
        print(f"{total_erros} foram encontrados e salvos em {error_file}")
    else:
        print("Nenhuma contratação sem data encontrada.")

    return contratacoes_com_data

contratacoes = remove_e_separa_contratacoes_por_data_publicacao(contratacoes)


# : FILTRO DE ITENS POR CONTRATAÇÃO --------------------------------------------

# Para cada linha de contratacoes, filtra os itens correspondentes
itens_filtrados_por_contratacao = []
contratacoes_filtradas = []

# Filtro para realizar testes
# contratacoes = contratacoes[contratacoes['data.unidadeOrgao.ufNome'].isin(['Santa Catarina'])]

print("FILTRANDO ITENS POR CONTRATAÇÃO...")

# A lista de itens não possui o campo 'numeroControlePNCP', então precisamos filtrar os itens
# com base nos campos cnpj, ano e sequencial da contratação, presente no endpoint do item.
for idx, row in tqdm(contratacoes.iterrows(), total=len(contratacoes)):
    itens_match = itens[
        itens['endpoint'].apply(lambda ep: match_endpoint(ep, row['cnpj'], row['ano'], row['sequencial']))
    ].copy()

    if not itens_match.empty:
        # Adiciona número de controle (pode ajudar na rastreabilidade depois)
        itens_match['numeroControlePNCP'] = row['data.numeroControlePNCP']

        itens_filtrados_por_contratacao.append(itens_match)

        # Filtra a lista de contratações para manter apenas as que têm itens correspondentes
        # Assim, criamos o json apenas para as contratações que relativas aos itens filtrados (medicamentos)
        contratacoes_filtradas.append(row)

contratacoes_filtradas_df = pd.DataFrame(contratacoes_filtradas)

# Junta todos os itens encontrados
itens_filtrados = pd.concat(itens_filtrados_por_contratacao, ignore_index=True)


# : CRIANDO ESTRUTURA OCDS -----------------------------------------------------

# Vamos organizar as releases como dicionário cujo o Estado será a chave
releases = {}

print("PROCESSANDO CONTRATAÇÕES...")
for _, row in tqdm(contratacoes_filtradas_df.iterrows(), total=len(contratacoes_filtradas_df)):
    # Cria ocid concatenando campos
    ocid = str(row['data.orgaoEntidade.cnpj']) + '_' + str(row['data.anoCompra']) + '_' + str(row['data.sequencialCompra'])

    # Itens relacionados - filtramos pelo número de controle do PNCP
    itens_rel = itens_filtrados[itens_filtrados['numeroControlePNCP'] == row['data.numeroControlePNCP']]
    items = []
    items_by_id = {}
    lots = []
    award_criteria = {
        "1": "priceOnly",  # Menor preço
        "2": "priceOnly",  # Maior desconto
        "3": "qualityOnly",  # Melhor técnica ou conteúdo artístico
        "4": "ratedCriteria",  # Técnica e preço
        "5": "priceOnly",  # Maior lance
        "6": "costOnly",  # Maior retorno econômico
        "7": None,  # Não se aplica
        "8": "qualityOnly"  # Melhor técnica
    }

    for _, item in itens_rel.iterrows():
        unit = {
            "value": {
                "amount": item['valorUnitarioEstimado'],
                "currency": "BRL"
            }
        }

        # Só adiciona "name" se unidadeMedida não for nula
        if pd.notna(item['unidadeMedida']):
            unit["name"] = item['unidadeMedida']

        i = {
            "id": str(item['numeroItem']),
            "description": item['descricao'],
            "quantity": int(item['quantidade']),
            "unit": unit,
            "relatedLot": 'lot-' + str(item['numeroItem'])
        }


        items.append(i)
        items_by_id[str(item['numeroItem'])] = i  # A fim de facilitar a rastreabilidade em awards

        lots.append({
            "id": 'lot-' + str(item['numeroItem']),
            **({"statusDetailsId": str(item['situacaoCompraItem'])} if item['situacaoCompraItem'] else {}),
            **({"statusDetails": item['situacaoCompraItemNome']} if pd.notna(item['situacaoCompraItemNome']) else {}),
            "value": {
                "amount": item['valorTotal'],
                "currency": "BRL",
            },
            "lotsDetails": {
                **({"confidentialBudget": item['orcamentoSigiloso']} if pd.notna(item['orcamentoSigiloso']) and item['orcamentoSigiloso'] != False else {}),
                **({"asset": item['patrimonio']} if pd.notna(item['patrimonio']) else {}),
                **({"realEstateRegistrationCode": item['codigoRegistroImobiliario']} if pd.notna(item['codigoRegistroImobiliario']) else {}),
                **({"standardPreferenceMarginApplicability": item['aplicabilidadeMargemPreferenciaNormal']} if pd.notna(item['aplicabilidadeMargemPreferenciaNormal']) and item['aplicabilidadeMargemPreferenciaNormal'] != False else {}),
                **({"standardPreferenceMarginPercentage": item['percentualMargemPreferenciaNormal']} if pd.notna(item['percentualMargemPreferenciaNormal']) else {}),
                **({"additionalPreferenceMarginApplicability": item['aplicabilidadeMargemPreferenciaAdicional']} if pd.notna(item['aplicabilidadeMargemPreferenciaAdicional']) and item['aplicabilidadeMargemPreferenciaAdicional'] != False else {}),
                **({"additionalPreferenceMarginPercentage": item['percentualMargemPreferenciaAdicional']} if pd.notna(item['percentualMargemPreferenciaAdicional']) else {}),
                **({
                    **({"benefitType": str(int(item['tipoBeneficio']))} if pd.notna(item['tipoBeneficio']) else {}),
                    **({"benefitTypeName": item['tipoBeneficioNome']} if pd.notna(item['tipoBeneficioNome']) else {})
                } if item['tipoBeneficioNome'] not in ["Sem benefício", "Não se aplica"] else {}),
                **({"ncmNbsCode": item['ncmNbsCodigo']} if pd.notna(item['ncmNbsCodigo']) else {}),
                **({"ncmNbsDescription": item['ncmNbsDescricao']} if pd.notna(item['ncmNbsDescricao']) else {}),
                **({"catalogItemCategoryId": item['categoriaItemCatalogo.id']} if pd.notna(item['categoriaItemCatalogo.id']) else {}),
                **({"catalogItemCategoryName": item['categoriaItemCatalogo.nome']} if pd.notna(item['categoriaItemCatalogo.nome']) else {}),
                **({"catalogItemCategoryDescription": item['categoriaItemCatalogo.descricao']} if pd.notna(item['categoriaItemCatalogo.descricao']) else {}),
                **({"catalogItemCode": item['catalogoCodigoItem']} if pd.notna(item['catalogoCodigoItem']) else {}),
                **({"awardCriteria": award_criteria[str(item['criterioJulgamentoId'])]} if pd.notna(award_criteria[str(item['criterioJulgamentoId'])]) else {}),
                **({"awardCriteriaDetails": item['criterioJulgamentoNome']} if pd.notna(item['criterioJulgamentoNome']) else {}),
            },
        })

        if item['tipoBeneficioNome'] not in ["Sem benefício", "Não se aplica"]:
            if item['tipoBeneficioNome'] == "Participação exclusiva para ME/EPP":
                lots[-1]["sustainability"] = [{
                        "goal": "social.smeInclusion",
                        # "goal": item['incentivoProdutivoBasico'],
                        "strategies": [
                            "reservedParticipation"
                        ]
                    }
                ]

                lots[-1]["otherRequirements"] = {
                    "reservedParticipation": [
                        "sme"
                    ]
                }

            elif item['tipoBeneficioNome'] == "Subcontratação para ME/EPP":
                lots[-1]["sustainability"] = [{
                        "goal": "social.smeInclusion",
                        # "goal": item['incentivoProdutivoBasico'],
                        "strategies": [
                            "subcontracting"
                        ]

                    }
                ]

                lots[-1]["subcontractingTerms"] = {
                    "description": "Subcontratação para ME/EPP"
                }

            elif item['tipoBeneficioNome'] == "Cota reservada para ME/EPP":
                lots[-1]["sustainability"] = [{
                        "goal": "social.smeInclusion",
                        # "goal": item['incentivoProdutivoBasico'],
                        "strategies": [
                            "reservedParticipationQuota"
                        ]

                    }
                ]





    # Resultados relacionados
    res_rel = resultados[resultados['numeroControlePNCPCompra'] == row['data.numeroControlePNCP']]
    awards = []
    lista_niFornecedor = []
    suppliers = []

    tipoPessoa = {
        "PF": "Pessoa Física",
        "PJ": "Pessoa Jurídica",
        "PE": "Pessoa Estrangeira",
    }

    porte_fornecedor = {
        "ME": "micro",
        "EPP": "small",
        "Demais": "large",
        "Não se aplica": "self-employed",
        "Não Informado": None
    }

    lots_awards = []

    idx = 1
    for _, res in res_rel.iterrows():
        # Listando fornecedores únicos para o campo "parties"
        if str(res['niFornecedor']) not in lista_niFornecedor:
            lista_niFornecedor.append(str(res['niFornecedor']))
            suppliers.append({
                "id": "BR-CNPJ-" + str(res['niFornecedor']),
                "name": res['nomeRazaoSocialFornecedor'],
                "identifier": {
                    "scheme": "BR-CNPJ",
                    "id": str(res['niFornecedor']),
                    "legalName": res['nomeRazaoSocialFornecedor'],
                },
                "address": {
                    "countryName": res['codigoPais']
                },
                "roles": ["supplier"],
                "details": {
                    **({"scale": porte_fornecedor[res['porteFornecedorNome']]} if pd.notna(porte_fornecedor[res['porteFornecedorNome']]) else {}),
                    "classifications": [
                        {
                            "scheme": "BRA-TIPO-PESSOA",
                            "id": str(res['tipoPessoa']),
                            "description": tipoPessoa[res['tipoPessoa']],
                        },
                        {
                            "scheme": "ORDEM DE CLASSIFICACAO SRP",
                            **({"id": str(int(res['ordemClassificacaoSrp']))} if pd.notna(res['ordemClassificacaoSrp']) else {}),
                        }]
                }
            })

            if pd.notna(res['naturezaJuridicaId']):
                suppliers[-1]['details']['classifications'].append({
                    "scheme": "BRA-NATUREZA-JURIDICA",
                    "id": str(int(res['naturezaJuridicaId'])),
                    "description": str(res['naturezaJuridicaNome']),
                })

        awards.append({
            "id": str(idx),  # substituindo res['sequencialResultado'], pois não possui um ID único para cada award
            "title": row['data.tipoInstrumentoConvocatorioNome'] + ' - ' + str(row['data.processo']),
            "description": row['data.objetoCompra'],
            "date": to_ocds_dt(res['dataResultado']),
            "hasSubcontracting": res['indicadorSubcontratacao'],
            "value": {
            "amount": res['valorTotalHomologado'],
            "currency": "BRL"
            },
            "suppliers": [{
            "id": "BR-CNPJ-" + str(res['niFornecedor']),
            "name": res['nomeRazaoSocialFornecedor'],
            }],
            "items": [{
            "id": str(res['numeroItem']),
            "description": items_by_id[str(res['numeroItem'])]['description'],
            "status": res['situacaoCompraItemResultadoNome'],
            **({"statusDetails": res['motivoCancelamento']} if pd.notna(res['motivoCancelamento']) else {}),
            "quantity": int(res['quantidadeHomologada']),
            "unit": {
                "name": items_by_id[str(res['numeroItem'])]['unit']['name'],
                "value": {
                "amount": res['valorUnitarioHomologado'],
                "currency": "BRL"
                }
            },
            **({"deliveryLocations": [{
                "description": str(res['paisOrigemProdutoServico.nome'])}]} if pd.notna(res['paisOrigemProdutoServico.nome']) else {}),
            "relatedLot": 'lot-' + str(res['numeroItem']),
            }],
            # "lots": {
            #     **({"id": 'lot-' + str(res['numeroItem'])} if pd.notna(res['numeroItem']) else {}),
            #     "lotsDetails": {
            #         **({"preferenceMarginApplication": str(res['aplicacaoMargemPreferencia'])} if pd.notna(res['aplicacaoMargemPreferencia']) else {}),
            #         **({"smallBusinessBenefitApplication": str(res['aplicacaoBeneficioMeEpp'])} if pd.notna(res['aplicacaoBeneficioMeEpp']) else {}),
            #         **({"tiebreakCriterionApplication": str(res['aplicacaoCriterioDesempate'])} if pd.notna(res['aplicacaoCriterioDesempate']) else {}),
            #         **({"updateDate": to_ocds_dt(res['dataAtualizacao'])} if pd.notna(res['dataAtualizacao']) else {}),
            #         **({"inclusionDate": to_ocds_dt(res['dataInclusao'])} if pd.notna(res['dataInclusao']) else {}),
            #         **({"foreignCurrencyQuoteTimezone": str(res['timezoneCotacaoMoedaEstrangeira'])} if pd.notna(res['timezoneCotacaoMoedaEstrangeira']) else {}),
            #         **({"foreignCurrencyId": str(res['moedaEstrangeira.id'])} if pd.notna(res['moedaEstrangeira.id']) else {}),
            #         **({"foreignCurrencySymbol": str(res['moedaEstrangeira.simbolo'])} if pd.notna(res['moedaEstrangeira.simbolo']) else {}),
            #         **({"foreignCurrencyName": str(res['moedaEstrangeira.nome'])} if pd.notna(res['moedaEstrangeira.nome']) else {}),
            #         **({"foreignCurrencyNominalValue": str(res['valorNominalMoedaEstrangeira'])} if pd.notna(res['valorNominalMoedaEstrangeira']) else {}),
            #         **({"foreignCurrencyQuoteDate": to_ocds_dt(res['dataCotacaoMoedaEstrangeira'])} if pd.notna(res['dataCotacaoMoedaEstrangeira']) else {}),
            #         **({"preferenceMarginLegalBasisId": str(res['amparoLegalMargemPreferencia.id'])} if pd.notna(res['amparoLegalMargemPreferencia.id']) else {}),
            #         **({"preferenceMarginLegalBasisName": str(res['amparoLegalMargemPreferencia.nome'])} if pd.notna(res['amparoLegalMargemPreferencia.nome']) else {}),
            #         **({"preferenceMarginLegalBasisDescription": str(res['amparoLegalMargemPreferencia.descricao'])} if pd.notna(res['amparoLegalMargemPreferencia.descricao']) else {}),
            #         **({"preferenceMarginLegalBasisActiveStatus": str(res['amparoLegalMargemPreferencia.statusAtivo'])} if pd.notna(res['amparoLegalMargemPreferencia.statusAtivo']) else {}),
            #         **({"tiebreakCriterionLegalBasisId": str(res['amparoLegalCriterioDesempate.id'])} if pd.notna(res['amparoLegalCriterioDesempate.id']) else {}),
            #         **({"tiebreakCriterionLegalBasisName": str(res['amparoLegalCriterioDesempate.nome'])} if pd.notna(res['amparoLegalCriterioDesempate.nome']) else {}),
            #         **({"tiebreakCriterionLegalBasisDescription": str(res['amparoLegalCriterioDesempate.descricao'])} if pd.notna(res['amparoLegalCriterioDesempate.descricao']) else {}),
            #         **({"tiebreakCriterionLegalBasisActiveStatus": str(res['amparoLegalCriterioDesempate.statusAtivo'])} if pd.notna(res['amparoLegalCriterioDesempate.statusAtivo']) else {}),
            #         **({"cancellationDate": to_ocds_dt(res['dataCancelamento'])} if pd.notna(res['dataCancelamento']) else {}),
            #     }
            # }
        })

        idx += 1

    # "traduzindo" os IDs do PNCP
    poder_id = {
    "E": "Executivo",
    "L": "Legislativo",
    "J": "Judiciário",
    "N": "Não se aplica"
    }

    esfera_id = {
    "F": "Federal",
    "E": "Estadual",
    "M": "Municipal",
    "D": "Distrital",
    "N": "Não se aplica"
    }

    tipo_instrumento_convocatorio = {
    "1": "open",  # Edital
    "2": "limited",  # Aviso de Contratação Direta
    "3": "direct",  # Ato que autoriza a contratação direta
    "4": "selective", # Edital de Chamamento Público
    }

    modalidade_contratacao = {
    "1": "electronicAuction",  # Leilão - Eletrônico
    "2": None,  # Diálogo Competitivo
    "3": None,  # Concurso
    "4": "electronicSubmission",  # Concorrência - Eletrônica
    "5": "written",  # Concorrência - Presencial
    "6": "electronicSubmission",  # Pregão - Eletrônico
    "7": "written",  # Pregão - Presencial
    "8": None,  # Dispensa
    "9": None,  # Inexigibilidade
    "10": None,  # Manifestação de Interesse
    "11": None,  # Pré-qualificação
    "12": None,  # Credenciamento
    "13": "written",  # Leilão - Presencial
    "14": None,  # Inaplicabilidade da Licitação
    }

    # Montagem do release
    release = {
        "ocid": 'ocds-ye9ov3-' + ocid,
        "id": row['data.numeroControlePNCP'],
        "date": to_ocds_dt(row['data.dataPublicacaoPncp']),
        "tag": ["tender", "award"],
        "initiationType": "tender",
        "buyer": {
            "id": "BR-CNPJ-" + str(row['data.orgaoSubRogado.cnpj']) if pd.notna(row['data.orgaoSubRogado.cnpj']) else "BR-CNPJ-" + str(row['data.orgaoEntidade.cnpj']),
            "name": row['data.orgaoSubRogado.razaoSocial'] if pd.notna(row['data.orgaoSubRogado.razaoSocial']) else row['data.orgaoEntidade.razaoSocial'],
        },
        "language": "pt",
    }

    release['parties'] = []

    # O órgão subrogado, quando existente, ocupa a função de buyer
    # E o órgão é adicionado como originalBuyer
    # Quando não, o próprio órgão é o buyer e originalBuyer não existe
    release['parties'].append({
        # BUYER
        "id": "BR-CNPJ-" + str(row['data.orgaoSubRogado.cnpj']) if pd.notna(row['data.orgaoSubRogado.cnpj']) else "BR-CNPJ-" + str(row['data.orgaoEntidade.cnpj']),
        "name": row['data.orgaoSubRogado.razaoSocial'] if pd.notna(row['data.orgaoSubRogado.razaoSocial']) else row['data.orgaoEntidade.razaoSocial'],
        "identifier": {
            "scheme": "BR-CNPJ",
            "id": str(row['data.orgaoSubRogado.cnpj']) if pd.notna(row['data.orgaoSubRogado.cnpj']) else str(row['data.orgaoEntidade.cnpj']),
            "legalName": row['data.orgaoSubRogado.razaoSocial'] if pd.notna(row['data.orgaoSubRogado.razaoSocial']) else row['data.orgaoEntidade.razaoSocial'],
        },
        "additionalIdentifiers": [
            {
                "id": str(row['data.unidadeSubRogada.codigoUnidade']) if pd.notna(row['data.unidadeSubRogada.codigoUnidade']) else str(row['data.unidadeOrgao.codigoUnidade']),
                "legalName": row['data.unidadeSubRogada.nomeUnidade'] if pd.notna(row['data.unidadeSubRogada.nomeUnidade']) else row['data.unidadeOrgao.nomeUnidade'],
            }
        ],
        "address": {
            "region": row['data.unidadeSubRogada.ufNome'] if pd.notna(row['data.unidadeSubRogada.ufNome']) else row['data.unidadeOrgao.ufNome'],
            "locality": row['data.unidadeSubRogada.municipioNome'] if pd.notna(row['data.unidadeSubRogada.municipioNome']) else row['data.unidadeOrgao.municipioNome'],
        },
        "roles": ["buyer", "procuringEntity"],
        "details": {
            "classifications": [
                {
                    "scheme": "BRA-ESFERA",
                    "id": "BRA-ESFERA-" + str(row['data.orgaoSubRogado.esferaId']) if pd.notna(row['data.orgaoSubRogado.esferaId']) else "BRA-ESFERA-" + str(row['data.orgaoEntidade.esferaId']),
                    "description": esfera_id[row['data.orgaoSubRogado.esferaId']] if pd.notna(row['data.orgaoSubRogado.esferaId']) else esfera_id[row['data.orgaoEntidade.esferaId']],
                }
            ]
        },
    })

    bra_poder_id = "BRA-PODER-" + str(row['data.orgaoSubRogado.poderId']) if pd.notna(row['data.orgaoSubRogado.poderId']) else "BRA-PODER-" + str(row['data.orgaoEntidade.poderId'])

    if bra_poder_id != "N":
        release["parties"][0]["details"]["classifications"].append({
            "scheme": "BRA-PODER",
            "id": "BRA-PODER-" + str(row['data.orgaoSubRogado.poderId']) if pd.notna(row['data.orgaoSubRogado.poderId']) else "BRA-PODER-" + str(row['data.orgaoEntidade.poderId']),
            "description": poder_id[row['data.orgaoSubRogado.poderId']] if pd.notna(row['data.orgaoSubRogado.poderId']) else poder_id[row['data.orgaoEntidade.poderId']],
        })

    # Se o órgão subrogado não existir, significa que o próprio órgão já foi referenciado
    if pd.notna(row['data.orgaoSubRogado.cnpj']):
        release['parties'].append({
            # ORIGINAL BUYER
            "id": "BR-CNPJ-" + str(row['data.orgaoEntidade.cnpj']),
            "name": row['data.orgaoEntidade.razaoSocial'],
            "identifier": {
                "scheme": "BR-CNPJ",
                "id": str(row['data.orgaoEntidade.cnpj']),
                "legalName": row['data.orgaoEntidade.razaoSocial'],
            },
            "additionalIdentifiers": [
                {
                    "id": str(row['data.unidadeOrgao.codigoUnidade']),
                    "legalName": row['data.unidadeOrgao.nomeUnidade'],
                }
            ],
            "address": {
                "region": row['data.unidadeOrgao.ufNome'],
                "locality": row['data.unidadeOrgao.municipioNome'],
            },
            "roles": ["originalBuyer"],
            "details": {
                "classifications": [
                    {
                        "scheme": "BRA-ESFERA",
                        "id": "BRA-ESFERA-" + str(row['data.orgaoEntidade.esferaId']),
                        "description": esfera_id[row['data.orgaoEntidade.esferaId']],
                    }
                ]
            },
        })

        if str(row['data.orgaoEntidade.poderId']) != "N":
            release["parties"][-1]["details"]["classifications"].append({
                "scheme": "BRA-PODER",
                "id": "BRA-PODER-" + str(row['data.orgaoEntidade.poderId']),
                "description": poder_id[row['data.orgaoEntidade.poderId']],
            })

    # Adicionando os suppliers
    release['parties'] = release['parties'] + [supplier for supplier in suppliers]

    release['tender'] = {
            "id": str(row['data.processo']),
            "title": row['data.tipoInstrumentoConvocatorioNome'] + ' - ' + str(row['data.processo']),
            "description": str(row['data.objetoCompra']),
            "procuringEntity": {
                "name": row['data.orgaoEntidade.razaoSocial'],
                "id": "BR-CNPJ-" + str(row['data.orgaoEntidade.cnpj']),
            },
            "value": {
                "amount": row['data.valorTotalEstimado'],
                "currency": "BRL"
            },
            "procurementMethod": tipo_instrumento_convocatorio[str(row['data.tipoInstrumentoConvocatorioCodigo'])],
            "procurementMethodDetails": (
                'tipoInstrumentoConvocatorioCodigo: ' + str(row['data.tipoInstrumentoConvocatorioCodigo'])
                + '; tipoInstrumentoConvocatorioNome: ' + row['data.tipoInstrumentoConvocatorioNome']
                + '; modalidadeId: ' + str(row['data.modalidadeId'])
                + '; modalidadeNome: ' + row['data.modalidadeNome']
                + '; modoDisputaId: ' + str(row['data.modoDisputaId'])
                + '; modoDisputaNome: ' + row['data.modoDisputaNome']
                + '; srp: ' + str(row['data.srp'])
            ),
            "procurementMethodRationale": (
                'amparoLegalCodigo: ' + str(row['data.amparoLegal.codigo'])
                + '; amparoLegalNome: ' + str(row['data.amparoLegal.nome'])
                + '; amparoLegalDescricao: ' + str(row['data.amparoLegal.descricao'])
            ),
            "mainProcurementCategory": "goods",
            **({"submissionMethod": [modalidade_contratacao[str(row['data.modalidadeId'])]]} if pd.notna(modalidade_contratacao[str(row['data.modalidadeId'])]) else {}),
            "submissionMethodDetails": str(row['data.modalidadeNome']),
            **({"tenderPeriod": {
                **({"startDate": to_ocds_dt(row['data.dataAberturaProposta'])} if pd.notna(row['data.dataAberturaProposta']) else {}),
                **({"endDate": to_ocds_dt(row['data.dataEncerramentoProposta'])} if pd.notna(row['data.dataEncerramentoProposta']) else {}),
                **({"maxExtentDate": to_ocds_dt(row['data.dataEncerramentoProposta'])} if pd.notna(row['data.dataEncerramentoProposta']) else {}),
                **({"durationInDays": duracao_em_dias(row['data.dataAberturaProposta'], row['data.dataEncerramentoProposta'])} if pd.notna(row['data.dataAberturaProposta']) and pd.notna(row['data.dataEncerramentoProposta']) else {}),
            }} if pd.notna(row['data.dataAberturaProposta']) or pd.notna(row['data.dataEncerramentoProposta']) else {}),
            "items": items,
            "lots": lots,
        }

    if awards != []:
        release['awards'] = awards

    estados = {
        "Acre": "ac",
        "Alagoas": "al",
        "Amapá": "ap",
        "Amazonas": "am",
        "Bahia": "ba",
        "Ceará": "ce",
        "Distrito Federal": "df",
        "Espírito Santo": "es",
        "Goiás": "go",
        "Maranhão": "ma",
        "Mato Grosso": "mt",
        "Mato Grosso do Sul": "ms",
        "Minas Gerais": "mg",
        "Pará": "pa",
        "Paraíba": "pb",
        "Paraná": "pr",
        "Pernambuco": "pe",
        "Piauí": "pi",
        "Rio de Janeiro": "rj",
        "Rio Grande do Norte": "rn",
        "Rio Grande do Sul": "rs",
        "Rondônia": "ro",
        "Roraima": "rr",
        "Santa Catarina": "sc",
        "São Paulo": "sp",
        "Sergipe": "se",
        "Tocantins": "to"
    }

    # Caso a chave não exista, criamos
    if estados[row['data.unidadeOrgao.ufNome']] not in releases:
        releases[estados[row['data.unidadeOrgao.ufNome']]] = []

    # Adicionamos a release recém-criada ao seu respectivo estado
    releases[estados[row['data.unidadeOrgao.ufNome']]].append(release)


# : CRIA JSON E ZIP ------------------------------------------------------------

# Criamos o JSON e ZIP de cada estado (contendo todas as suas contratações)
for estado in releases:
    lista = releases[estado]
    json_files = []
    total_lotes = (len(lista) + 499) // 500 # Calcula o total de lotes necessários, considerando 500 releases por lote
    lote_tamanho = 500  # Define o tamanho do lote para dividir as releases

    for i in range(0, len(lista), lote_tamanho):
        lote = lista[i:i+lote_tamanho]

        id = f'{estado}-{mes_coleta}-{ano_coleta}'

        # Montagem do objeto OCDS
        ocds = {
            "uri": f"https://medicamentos-transparentes-dados-abertos.s3.sa-east-1.amazonaws.com/{id}-json.zip",  # link no qual o OCDS poderá ser acessado, alterar após definir a URL correta
            "publishedDate": to_ocds_dt(datetime.now().isoformat()),
            "publisher": {
                "name": "Medicamentos Transparentes",
                "uri": "https://medicamentos.transparencia.org.br/",
            },
            "version": "1.1",
            "extensions": [
                "https://raw.githubusercontent.com/open-contracting-extensions/ocds_partyDetails_scale_extension/master/extension.json",
                "https://raw.githubusercontent.com/open-contracting-extensions/ocds_lots_extension/v1.1.5/extension.json",
                "https://raw.githubusercontent.com/open-contracting-extensions/ocds_subcontracting_extension/master/extension.json",
                "https://raw.githubusercontent.com/open-contracting-extensions/ocds_location_extension/master/extension.json",
                "https://raw.githubusercontent.com/open-contracting-extensions/ocds_organizationClassification_extension/master/extension.json",
                "https://raw.githubusercontent.com/open-contracting-extensions/ocds_sustainability_extension/master/extension.json",
                "https://gitlab.com/dncp-opendata/ocds_statusdetails_extension/-/raw/master/extension.json",
            ],
            "releases": lote
        }

        # Exportar para JSON
        json_file = f'{id}-{i // lote_tamanho + 1}.json' if total_lotes > 1 else f'{id}.json'
        with open(os.path.join(base_dir, 'tasks', 'mapeamento-ocds', 'output', json_file), 'w', encoding='utf-8') as f:
            json.dump(ocds, f, ensure_ascii=False, indent=2)

        json_files.append(json_file)

    # Exportar para Zip
    zip_file = f"{id}-json.zip"
    zip_file = os.path.join(base_dir, 'tasks', 'mapeamento-ocds', 'output', zip_file)
    with zipfile.ZipFile(zip_file, "w", zipfile.ZIP_DEFLATED) as zipf:
        for json_file in json_files:
            json_path = os.path.join(base_dir, 'tasks', 'mapeamento-ocds', 'output', json_file)
            zipf.write(json_path, arcname=json_file)
