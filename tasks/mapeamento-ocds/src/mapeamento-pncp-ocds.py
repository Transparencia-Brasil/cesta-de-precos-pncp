"""
Este script transforma contratações públicas em formato compatível com o padrão OCDS (Open Contracting Data Standard).
Ele processa dados de contratações, itens e resultados e gera arquivos JSON e ZIP por estado.
Comentários explicativos estão distribuídos ao longo do código original.
"""

import json
from datetime import datetime, timezone
import pandas as pd
from tqdm import tqdm
import zipfile

contratacoes = pd.read_csv('input/contratacoes.csv')
itens = pd.read_csv('input/itens-medicamentos.csv')
resultados = pd.read_csv('input/resultados.csv')

# TODO Pegar essa informação por variável de ambiente
mes_coleta = 1
ano_coleta = 2025

# Função para converter data para o formato OCDS
# Formato esperado: 'YYYY-MM-DDTHH:MM:SSZ'
def to_ocds_dt(data):
    try:
        dt = datetime.fromisoformat(data).astimezone(timezone.utc)
        ocds_dt = dt.strftime('%Y-%m-%dT%H:%M:%SZ')
        return ocds_dt
    except Exception as e:
        print(f"Erro ao converter data: {e}: {data}: {type(data)}")
        return None

def duracao_em_dias(data_inicio, data_fim):
    try:
        inicio = datetime.fromisoformat(data_inicio)
        fim = datetime.fromisoformat(data_fim)
        duracao = (fim - inicio).days
        return duracao
    except Exception as e:
        print(f"Erro ao calcular duração: {e}")
        return None

# Extrai cnpj, ano e sequencial da coluna numeroControlePNCP
def extrair_parametros(numero_controle):
    cnpj, _, sequencial_ano = numero_controle.partition('-1-')
    sequencial, _, ano = sequencial_ano.partition('/')
    sequencial = str(int(sequencial))  # remove zeros à esquerda
    return pd.Series([cnpj, ano, sequencial])

# Aplica extração
contratacoes[['cnpj', 'ano', 'sequencial']] = contratacoes['data.numeroControlePNCP'].apply(extrair_parametros)

# Função para verificar se o endpoint do item bate com os campos da contratação
def match_endpoint(endpoint, cnpj, ano, sequencial):
    return (
        str(cnpj) in str(endpoint) and
        str(ano) in str(endpoint) and
        f'/{int(sequencial)}/' in str(endpoint)  # evita colisões tipo 81, 181, etc.
    )

# Para cada linha de contratacoes, filtra os itens correspondentes
itens_filtrados_por_contratacao = []
contratacoes_filtradas = []

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

# Vamos organizar as releases como dicionário cujo o Estado será a chave
releases = {}

print("PROCESSANDO CONTRATAÇÕES...")
for _, row in tqdm(contratacoes_filtradas_df.iterrows(), total=len(contratacoes_filtradas_df)):
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
        i = {
            "id": str(item['numeroItem']),
            "description": item['descricao'],
            "quantity": int(item['quantidade']),
            "unit": {
                "name": item['unidadeMedida'],
                "value": {
                    "amount": item['valorUnitarioEstimado'],
                    "currency": "BRL"
                }
            },
            "relatedLot": 'lot-' + str(item['numeroItem'])
        }

        items.append(i)
        items_by_id[str(item['numeroItem'])] = i  # A fim de facilitar a rastreabilidade em awards

        lots.append({
            "id": 'lot-' + str(item['numeroItem']),
            "statusDetailsId": str(item['situacaoCompraItem']),
            "statusDetails": item['situacaoCompraItemNome'] if pd.notna(item['situacaoCompraItemNome']) else None,
            "confidentialBudget": item['orcamentoSigiloso'] if pd.notna(item['orcamentoSigiloso']) else None,
            "asset": item['patrimonio'] if pd.notna(item['patrimonio']) else None,
            "realEstateRegistrationCode": item['codigoRegistroImobiliario'] if pd.notna(item['codigoRegistroImobiliario']) else None,
            "standardPreferenceMarginApplicability": item['aplicabilidadeMargemPreferenciaNormal'] if pd.notna(item['aplicabilidadeMargemPreferenciaNormal']) else None,
            "standardPreferenceMarginPercentage": item['percentualMargemPreferenciaNormal'] if pd.notna(item['percentualMargemPreferenciaNormal']) else None,
            "additionalPreferenceMarginApplicability": item['aplicabilidadeMargemPreferenciaAdicional'] if pd.notna(item['aplicabilidadeMargemPreferenciaAdicional']) else None,
            "additionalPreferenceMarginPercentage": item['percentualMargemPreferenciaAdicional'] if pd.notna(item['percentualMargemPreferenciaAdicional']) else None,
            "benefitType": str(int(item['tipoBeneficio'])) if pd.notna(item['tipoBeneficio']) else None,
            "benefitTypeName": item['tipoBeneficioNome'] if pd.notna(item['tipoBeneficioNome']) else None,
            "ncmNbsCode": item['ncmNbsCodigo'] if pd.notna(item['ncmNbsCodigo']) else None,
            "ncmNbsDescription": item['ncmNbsDescricao'] if pd.notna(item['ncmNbsDescricao']) else None,
            "catalogItemCategoryId": item['categoriaItemCatalogo.id'] if pd.notna(item['categoriaItemCatalogo.id']) else None,
            "catalogItemCategoryName": item['categoriaItemCatalogo.nome'] if pd.notna(item['categoriaItemCatalogo.nome']) else None,
            "catalogItemCategoryDescription": item['categoriaItemCatalogo.descricao'] if pd.notna(item['categoriaItemCatalogo.descricao']) else None,
            "catalogItemCode": item['catalogoCodigoItem'] if pd.notna(item['catalogoCodigoItem']) else None,
            "awardCriteria": award_criteria[str(item['criterioJulgamentoId'])] if pd.notna(item['criterioJulgamentoId']) else None,
            "awardCriteriaDetails": item['criterioJulgamentoNome'] if pd.notna(item['criterioJulgamentoNome']) else None,
            "value": {
                "amount": item['valorTotal'],
                "currency": "BRL",
            },
            "sustainability": {
                "description":
                    'tipoBeneficio: ' + str(int(item['tipoBeneficio']))
                    + '; tipoBeneficioNome: ' + item['tipoBeneficioNome'],
                "goal": item['incentivoProdutivoBasico'],
            }
        })

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
        "ME": "Micro",
        "EPP": "Small",
        "Demais": "Large",
        "Não se aplica": "Self-Employed",
        "Não Informado": None
    }

    lots_awards = []

    for idx, res in res_rel.iterrows():
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
                    "scale": porte_fornecedor[res['porteFornecedorNome']],
                    "classification": [{
                        "scheme": "BRA-TIPO-PESSOA",
                        "id": str(res['tipoPessoa']),
                        "description": tipoPessoa[res['tipoPessoa']] if pd.notna(tipoPessoa[res['tipoPessoa']]) else None,
                    },
                        {
                            "scheme": "BRA-NATUREZA-JURIDICA",
                            "id": str(int(res['naturezaJuridicaId'])) if pd.notna(res['naturezaJuridicaId']) else None,
                            "description": str(res['naturezaJuridicaNome']) if pd.notna(res['naturezaJuridicaNome']) else None,
                        },
                        {
                            "scheme": "ORDEM DE CLASSIFICACAO SRP",
                            "id": str(int(res['ordemClassificacaoSrp'])) if pd.notna(res['ordemClassificacaoSrp']) else None,
                        }]
                }
            })

        awards.append({
            "id": str(idx + 1),  # substituindo res['sequencialResultado'], pois não possui um ID único para cada award
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
            "statusDetails": res['motivoCancelamento'] if pd.notna(res['motivoCancelamento']) else None,
            "quantity": int(res['quantidadeHomologada']),
            "unit": {
                "name": items_by_id[str(res['numeroItem'])]['unit']['name'],
                "value": {
                "amount": res['valorUnitarioHomologado'],
                "currency": "BRL"
                }
            },
            "deliveryLocation": {
                "description": str(res['paisOrigemProdutoServico.nome']) if pd.notna(res['paisOrigemProdutoServico.nome']) else None,
            },
            "relatedLot": 'lot-' + str(res['numeroItem']),
            }],
            "lots": {
            "id": 'lot-' + str(res['numeroItem']),
            "preferenceMarginApplication": str(res['aplicacaoMargemPreferencia']),
            "smallBusinessBenefitApplication": str(res['aplicacaoBeneficioMeEpp']),
            "tiebreakCriterionApplication": str(res['aplicacaoCriterioDesempate']),
            "updateDate": to_ocds_dt(res['dataAtualizacao']),
            "inclusionDate": to_ocds_dt(res['dataInclusao']),
            "foreignCurrencyQuoteTimezone": str(res['timezoneCotacaoMoedaEstrangeira']) if pd.notna(res['timezoneCotacaoMoedaEstrangeira']) else None,
            "foreignCurrencyId": str(res['moedaEstrangeira.id']) if pd.notna(res['moedaEstrangeira.id']) else None,
            "foreignCurrencySymbol": str(res['moedaEstrangeira.simbolo']) if pd.notna(res['moedaEstrangeira.simbolo']) else None,
            "foreignCurrencyName": str(res['moedaEstrangeira.nome']) if pd.notna(res['moedaEstrangeira.nome']) else None,
            "foreignCurrencyNominalValue": str(res['valorNominalMoedaEstrangeira']) if pd.notna(res['valorNominalMoedaEstrangeira']) else None,
            "foreignCurrencyQuoteDate": to_ocds_dt(res['dataCotacaoMoedaEstrangeira']) if pd.notna(res['dataCotacaoMoedaEstrangeira']) else None,
            "preferenceMarginLegalBasisId": str(res['amparoLegalMargemPreferencia.id']) if pd.notna(res['amparoLegalMargemPreferencia.id']) else None,
            "preferenceMarginLegalBasisName": str(res['amparoLegalMargemPreferencia.nome']) if pd.notna(res['amparoLegalMargemPreferencia.nome']) else None,
            "preferenceMarginLegalBasisDescription": str(res['amparoLegalMargemPreferencia.descricao']) if pd.notna(res['amparoLegalMargemPreferencia.descricao']) else None,
            "preferenceMarginLegalBasisActiveStatus": str(res['amparoLegalMargemPreferencia.statusAtivo']) if pd.notna(res['amparoLegalMargemPreferencia.statusAtivo']) else None,
            "tiebreakCriterionLegalBasisId": str(res['amparoLegalCriterioDesempate.id']) if pd.notna(res['amparoLegalCriterioDesempate.id']) else None,
            "tiebreakCriterionLegalBasisName": str(res['amparoLegalCriterioDesempate.nome']) if pd.notna(res['amparoLegalCriterioDesempate.nome']) else None,
            "tiebreakCriterionLegalBasisDescription": str(res['amparoLegalCriterioDesempate.descricao']) if pd.notna(res['amparoLegalCriterioDesempate.descricao']) else None,
            "tiebreakCriterionLegalBasisActiveStatus": str(res['amparoLegalCriterioDesempate.statusAtivo']) if pd.notna(res['amparoLegalCriterioDesempate.statusAtivo']) else None,
            "cancellationDate": to_ocds_dt(res['dataCancelamento']),
        }
        })

    # "traduzindo" os IDs do PNCP
    poder_id = {
    "E": "Executivo",
    "L": "Legislativo",
    "J": "Judiciário",
    "N": "alguma coisa"
    }

    esfera_id = {
    "F": "Federal",
    "E": "Estadual",
    "M": "Municipal",
    "D": "Distrital",
    }

    tipo_instrumento_convocatorio = {
    "1": "open",  # Edital
    "2": "limited",  # Aviso de Contratação Direta
    "3": "direct",  # Ato que autoriza a contratação direta
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
        "roles": ["buyer"],
        "details": {
            "classification": [
                {
                    "scheme": "BRA-PODER",
                    "id": str(row['data.orgaoSubRogado.poderId']) if pd.notna(row['data.orgaoSubRogado.poderId']) else str(row['data.orgaoEntidade.poderId']),
                    "description": poder_id[row['data.orgaoSubRogado.poderId']] if pd.notna(row['data.orgaoSubRogado.poderId']) else poder_id[row['data.orgaoEntidade.poderId']],
                },
                {
                    "scheme": "BRA-ESFERA",
                    "id": str(row['data.orgaoSubRogado.esferaId']) if pd.notna(row['data.orgaoSubRogado.esferaId']) else str(row['data.orgaoEntidade.esferaId']),
                    "description": esfera_id[row['data.orgaoSubRogado.esferaId']] if pd.notna(row['data.orgaoSubRogado.esferaId']) else esfera_id[row['data.orgaoEntidade.esferaId']],
                }
            ]
        },
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
                "classification": [
                    {
                        "scheme": "BRA-PODER",
                        "id": str(row['data.orgaoEntidade.poderId']),
                        "description": poder_id[row['data.orgaoEntidade.poderId']],
                    },
                    {
                        "scheme": "BRA-ESFERA",
                        "id": str(row['data.orgaoEntidade.esferaId']),
                        "description": esfera_id[row['data.orgaoEntidade.esferaId']],
                    }
                ]
            },
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
            "submissionMethod": [modalidade_contratacao[str(row['data.modalidadeId'])]],
            "submissionMethodDetails": str(row['data.modalidadeNome']),
            "tenderPeriod": {
                "startDate": to_ocds_dt(row['data.dataAberturaProposta']),
                "endDate": to_ocds_dt(row['data.dataEncerramentoProposta']),
                "maxExtentDate": to_ocds_dt(row['data.dataEncerramentoProposta']),
                "durationInDays": duracao_em_dias(row['data.dataAberturaProposta'], row['data.dataEncerramentoProposta']),
            },
            "items": items,
            "lots": lots,
        }
    
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

# Criamos o JSON e ZIP de cada estado (contendo todas as suas contratações)
for estado in releases:
    # Montagem do objeto OCDS
    ocds = {
        "uri": "https://exemplo.com",  # link no qual o OCDS poderá ser acessado, alterar após definir a URL correta
        "publishedDate": to_ocds_dt(datetime.now().isoformat()),
        "publisher": {
            "name": "Medicamentos Transparentes",
            "uri": "https://medicamentos.transparencia.org.br/",
        },
        "version": "1.1",
        "releases": releases[estado]
    }

    # Exportar para JSON
    json_file = f'{estado}-{mes_coleta}-{ano_coleta}.json'
    with open(f'output/{json_file}', 'w', encoding='utf-8') as f:
        json.dump(ocds, f, ensure_ascii=False, indent=2)
        
    # Exportar para Zip
    with zipfile.ZipFile(f"output/{estado}-{mes_coleta}-{ano_coleta}-json.zip", "w", zipfile.ZIP_DEFLATED) as zipf:
        zipf.write(f'output/{json_file}', arcname=json_file)