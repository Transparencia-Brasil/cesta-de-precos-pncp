import json
from datetime import datetime, timezone
import pandas as pd
from tqdm import tqdm

contratacoes = pd.read_csv('input/contratacoes.csv')
itens = pd.read_csv('input/itens-medicamentos.csv')
resultados = pd.read_csv('input/resultados.csv')

# Função para converter data para o formato OCDS
# Formato esperado: 'YYYY-MM-DDTHH:MM:SSZ'
def to_ocds_dt(data):
    try:
        dt = datetime.fromisoformat(data).astimezone(timezone.utc)
        ocds_dt = dt.strftime('%Y-%m-%dT%H:%M:%SZ')
        return ocds_dt
    except Exception as e:
        print(f"Erro ao converter data: {e}")
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
        break

contratacoes_filtradas_df = pd.DataFrame(contratacoes_filtradas)

# Junta todos os itens encontrados
itens_filtrados = pd.concat(itens_filtrados_por_contratacao, ignore_index=True)

print("PROCESSANDO CONTRATAÇÕES...")
for _, row in tqdm(contratacoes_filtradas_df.iterrows(), total=len(contratacoes_filtradas_df)):
    ocid = str(row['data.orgaoEntidade.cnpj']) + '_' + str(row['data.anoCompra']) + '_' + str(row['data.sequencialCompra'])
    
    # Itens relacionados - filtramos pelo número de controle do PNCP
    itens_rel = itens_filtrados[itens_filtrados['numeroControlePNCP'] == row['data.numeroControlePNCP']]
    items = []
    for _, item in itens_rel.iterrows():
        items.append({
            "id": str(item['numeroItem']),
            "description": item['descricao'],
            "classification": {
                    "scheme": "MaterialOuServico",
                    "id": str(item['materialOuServico']) if pd.notna(item['materialOuServico']) else None,
                    "description": item['materialOuServicoNome'] if pd.notna(item['materialOuServicoNome']) else None,
                },
            "quantity": int(item['quantidade']),
            "unit": {
                "name": item['unidadeMedida'],
                "value": {
                    "amount": item['valorUnitarioEstimado'],
                    "currency": "BRL"
                }
            },
            "additionalClassifications": [
                {
                    "scheme": "orcamentoSigiloso",
                    "description": str(item['orcamentoSigiloso']) if pd.notna(item['orcamentoSigiloso']) else None
                },
                {
                "scheme": "ItemCategoria",
                "id": str(item['itemCategoriaId']),
                "description": item['itemCategoriaNome'],
            },
                {
                    "scheme": "patrimonio",
                    "description": str(item['patrimonio']) if pd.notna(item['patrimonio']) else None,
                },
                {
                    "scheme": "codigoRegistroImobiliario",
                    "description": str(item['codigoRegistroImobiliario']) if pd.notna(item['codigoRegistroImobiliario']) else None,
                },
                {
                    "scheme": "tipoBeneficio",
                    "description": str(int(item['tipoBeneficio'])) if pd.notna(item['tipoBeneficio']) else None,
                },
                {
                    "scheme": "aplicacaoMargemPreferenciaNormal",
                    "description": str(item['aplicabilidadeMargemPreferenciaNormal']) if pd.notna(item['aplicabilidadeMargemPreferenciaNormal']) else None
                },
                {
                    "scheme": "aplicacaoMargemPreferenciaAdicional",
                    "description": str(item['aplicabilidadeMargemPreferenciaAdicional']) if pd.notna(item['aplicabilidadeMargemPreferenciaAdicional']) else None
                },
                {
                    "scheme": "percentualMargemPreferenciaNormal",
                    "description": str(item['percentualMargemPreferenciaNormal']) if pd.notna(item['percentualMargemPreferenciaNormal']) else None
                },
                {
                    "scheme": "percentualMargemPreferenciaAdicional",
                    "description": str(item['percentualMargemPreferenciaAdicional']) if pd.notna(item['percentualMargemPreferenciaAdicional']) else None
                },
                {
                    "scheme": "BR-NCM-NBS",
                    "id": str(item['ncmNbsCodigo']) if pd.notna(item['ncmNbsCodigo']) else None,
                    "description": str(item['ncmNbsDescricao']) if pd.notna(item['ncmNbsDescricao']) else None,
                },
                {
                    "scheme": "BR-CategoriaItemCatalogo",
                    "id": str(item['categoriaItemCatalogo.id']) if pd.notna(item['categoriaItemCatalogo.id']) else None,
                    "description": str(item['categoriaItemCatalogo.nome']) if pd.notna(item['categoriaItemCatalogo.nome']) else None,
                    "details": item['categoriaItemCatalogo.descricao'] if pd.notna(item['categoriaItemCatalogo.descricao']) else None,
                },
                {
                    "scheme": "BR-Catalogo",
                    "id": str(item['catalogoCodigoItem']) if pd.notna(item['catalogoCodigoItem']) else None,
                },
            ],
            "date": to_ocds_dt(item['dataInclusao']),
            "dateModified": to_ocds_dt(item['dataAtualizacao']),
            "relatedDocuments": [{
                "title": item['catalogo.nome'] if pd.notna(item['catalogo.nome']) else None,
                "description": str(item['catalogo.descricao']) if pd.notna(item['catalogo.descricao']) else None,
                "datePublished": to_ocds_dt(item['catalogo.dataInclusao']) if pd.notna(item['catalogo.dataInclusao']) else None,
                "dateModified": to_ocds_dt(item['catalogo.dataAtualizacao']) if pd.notna(item['catalogo.dataAtualizacao']) else None,
                "url": item['catalogo.url'] if pd.notna(item['catalogo.url']) else None,
            }]
        })

    # Resultados relacionados
    res_rel = resultados[resultados['numeroControlePNCPCompra'] == row['data.numeroControlePNCP']]
    awards = []
    for idx, res in res_rel.iterrows():
        awards.append({
            "id": str(idx + 1),  # substituindo res['sequencialResultado'], pois não possui um ID único para cada award
            "date": to_ocds_dt(res['dataInclusao']),
            "dateModified": to_ocds_dt(res['dataAtualizacao']),
            "status": "pending" if str(row['data.situacaoCompraId']) == '1' else "cancelled",
            "statusDetails": res['situacaoCompraItemResultadoNome'],
            "value": {
                "amount": res['valorTotalHomologado'],
                "currency": "BRL"
            },
            "x-foreignValue": {
                "id": str(res['moedaEstrangeira.id']) if pd.notna(res['moedaEstrangeira.id']) else None,
                "currency": res['moedaEstrangeira.simbolo'] if pd.notna(res['moedaEstrangeira.simbolo']) else None,
                "description": str(res['moedaEstrangeira.nome']) if pd.notna(res['moedaEstrangeira.nome']) else None,
                "amount": res['valorNominalMoedaEstrangeira'] if pd.notna(res['valorNominalMoedaEstrangeira']) else None,
                "exchangeDate": to_ocds_dt(res['dataCotacaoMoedaEstrangeira']) if pd.notna(res['dataCotacaoMoedaEstrangeira']) else None,
            },
            "suppliers": [{
                "name": res['nomeRazaoSocialFornecedor'],
                    "scheme": "BR-CNPJ" if len(str(res['niFornecedor'])) == 14 else "BR-CPF",
                    "id": str(res['niFornecedor']),
                "address": {
                    "countryName": res['codigoPais']
                },
                "details": {
                    "classification": {
                        "id": str(res['naturezaJuridicaId']) if pd.notna(res['naturezaJuridicaId']) else None,
                        "description": str(res['naturezaJuridicaNome']) if pd.notna(res['naturezaJuridicaNome']) else None,
                        "scheme": "naturezaJuridicaId",
                    },
                    "additionalClassifications": [
                        {
                            "id": str(res['tipoPessoa']),
                            "scheme": "tipoPessoa",
                        },
                        {
                            "id": str(int(res['ordemClassificacaoSrp'])),
                            "scheme": "ordemClassificacaoSrp",
                        },
                    ],
                },
                "scale": res['porteFornecedorNome'],
            }],
            "items": [{
                "id": str(res['numeroItem']),
                "status": str(res['situacaoCompraItemResultadoId']),
                "classification": {
                    "scheme": "amparoLegalMargemPreferencia",
                    "id": str(res['amparoLegalMargemPreferencia.id']) if pd.notna(res['amparoLegalMargemPreferencia.id']) else None,
                    "description": str(res['amparoLegalMargemPreferencia.nome']) if pd.notna(res['amparoLegalMargemPreferencia.nome']) else None,
                    "details": res['amparoLegalMargemPreferencia.descricao'] if pd.notna(res['amparoLegalMargemPreferencia.descricao']) else None,
                },
                "additionalClassifications": [
                    {"scheme": "aplicacaoMargemPreferencia",
                        "description": str(res['aplicacaoMargemPreferencia']) if pd.notna(res['aplicacaoMargemPreferencia']) else None},
                    {"scheme": "aplicacaoBeneficioMeEpp",
                        "description": str(res['aplicacaoBeneficioMeEpp']) if pd.notna(res['aplicacaoBeneficioMeEpp']) else None},
                    {"scheme": "aplicacaoCriterioDesempate",
                        "description": str(res['aplicacaoCriterioDesempate']) if pd.notna(res['aplicacaoCriterioDesempate']) else None},
                    {
                        "scheme": "amparoLegalCriterioDesempate",
                        "id": str(res['amparoLegalCriterioDesempate.id']) if pd.notna(res['amparoLegalCriterioDesempate.id']) else None,
                        "description": str(res['amparoLegalCriterioDesempate.nome']) if pd.notna(res['amparoLegalCriterioDesempate.nome']) else None,
                        "details": res['amparoLegalCriterioDesempate.descricao'] if pd.notna(res['amparoLegalCriterioDesempate.descricao']) else None,
                    },
                ],
                "deliveryLocation": {
                    "id": str(res['paisOrigemProdutoServico.id']) if pd.notna(res['paisOrigemProdutoServico.id']) else None,
                    "description": str(res['paisOrigemProdutoServico.nome']) if pd.notna(res['paisOrigemProdutoServico.nome']) else None,
                },
                "quantity": res['quantidadeHomologada'],
                "unit": {
                    "value": {
                        "amount": res['valorUnitarioHomologado'],
                        "currency": "BRL"
                    }
                },
                "hasSubcontracting": res['indicadorSubcontratacao'],
            }]
        })
        

    # Montagem do release
    release = {
        "ocid": 'ocds-xyz-' + ocid, # aqui falta definir o prefixo correto, mas vamos usar um exemplo genérico
        "id": ocid,
        "initiationType": "tender", # creio que o ideal seria row['data.tipoInstrumentoConvocatorioNome'], mas este campo só permite o valor "tender"
        "tag": ["tender", "award"],
        "tender": {
            "id": str(row['data.processo']),
            "title": row['data.modalidadeNome'],
            "value": {
                "amount": row['data.valorTotalEstimado'],
                "currency": "BRL"
            },
            "procurementMethodDetails": 'amparoLegal.nome: ' + row['data.amparoLegal.nome'] + '; srp: ' + str(row['data.srp']),
            "procurementMethodRationale": 'amparoLegal.descricao: ' + str(row['data.amparoLegal.descricao']) + '; justificativaPresencial: ' + str(row['data.justificativaPresencial']),
            "tenderPeriod": {
                "startDate": to_ocds_dt(row['data.dataAberturaProposta']),
                "endDate": to_ocds_dt(row['data.dataEncerramentoProposta'])
            },
            "items": items,
            "description": str(row['data.objetoCompra']),
            "documents": [{
                "id": "linkSistemaOrigem",
                "uri": row['data.linkSistemaOrigem'] if pd.notna(row['data.linkSistemaOrigem']) else None,
            }]
        },
        "awards": awards,
        "date": to_ocds_dt(row['data.dataPublicacaoPncp']),
        "buyer": {
            "id": str(row['data.orgaoEntidade.cnpj']),
            "name": row['data.orgaoEntidade.razaoSocial'],
            "address": {
                "region": row['data.unidadeOrgao.ufNome'],
                "locality": row['data.unidadeOrgao.municipioNome']
            },
            "details": {
                "classification": {
                    "scheme": "poderId",
                    "id": str(row['data.orgaoEntidade.poderId']),
                }
            }
        },
        "parties": [{
            "contactPoint": {
                "name": row['data.usuarioNome']
            },
            "id": str(row['data.orgaoEntidade.cnpj']),
            "name": row['data.orgaoEntidade.razaoSocial'],
            "additionalIdentifiers": [
                {
                    "scheme": "unidadeSubRogada",
                    "id": str(row['data.unidadeSubRogada.codigoUnidade']) if pd.notna(row['data.unidadeSubRogada.codigoUnidade']) else None,
                    "legalName": row['data.unidadeSubRogada.nomeUnidade'] if pd.notna(row['data.unidadeSubRogada.nomeUnidade']) else None,
                    "address": {
                        "region": row['data.unidadeSubRogada.ufSigla'] if pd.notna(row['data.unidadeSubRogada.ufSigla']) else None,
                        "locality": row['data.unidadeSubRogada.municipioNome'] if pd.notna(row['data.unidadeSubRogada.municipioNome']) else None,
                    },
                },
                {
                    "scheme": "orgaoSubRogado",
                    "id": str(row['data.orgaoSubRogado.cnpj']) if pd.notna(row['data.orgaoSubRogado.cnpj']) else None,
                    "legalName": row['data.orgaoSubRogado.razaoSocial'] if pd.notna(row['data.orgaoSubRogado.razaoSocial']) else None,
                    "details": {
                        "classification": {
                            "scheme": "poderId",
                            "id": str(row['data.orgaoSubRogado.poderId']) if pd.notna(row['data.orgaoSubRogado.poderId']) else None,
                        }
                    },
                },
                {
                    "scheme": "unidadeOrgao",
                    "id": str(row['data.unidadeOrgao.codigoUnidade']) if pd.notna(row['data.unidadeOrgao.codigoUnidade']) else None,
                    "legalName": row['data.unidadeOrgao.nomeUnidade'] if pd.notna(row['data.unidadeOrgao.nomeUnidade']) else None,
                    "address": {
                        "region": row['data.unidadeOrgao.ufSigla'] if pd.notna(row['data.unidadeOrgao.ufSigla']) else None,
                        "locality": row['data.unidadeOrgao.municipioNome'] if pd.notna(row['data.unidadeOrgao.municipioNome']) else None,
                    },
                },
            ],
        }]
    }
    
    # Montagem do objeto OCDS
    ocds = {
        "uri": "https://exemplo.com", # link no qual o OCDS poderá ser acessado, alterar após definir a URL correta
        "publishedDate": to_ocds_dt(datetime.now().isoformat()),
        "publisher":{
            "name": "Medicamentos Transparentes",
            "uri": "https://medicamentos.transparencia.org.br/",
        },
        "version": "1.1",
        "releases": [
            release
        ]
    }


    # Exportar para JSON
    with open(f'output/{ocid}.json', 'w', encoding='utf-8') as f:
        json.dump(ocds, f, ensure_ascii=False, indent=2)