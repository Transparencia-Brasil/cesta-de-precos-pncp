# Templates PNCP

Este diretorio mantem os templates versionados usados pelos coletores do PNCP. Antes da coleta, o validador consulta a documentacao OpenAPI oficial, atualiza os CSVs de template e preserva campos legados para manter compatibilidade com os CSVs historicos e os loaders.

## Metadados dos endpoints

| Alias | Modulo | URL Swagger | OpenAPI | Metodo e path | operationId | Parametros |
|---|---|---|---|---|---|---|
| contratacoes | API PNCP Consulta | https://pncp.gov.br/api/consulta/swagger-ui/index.html | https://pncp.gov.br/pncp-consulta/v3/api-docs | GET /v1/contratacoes/atualizacao | consultarContratacaoPorDataUltimaAtualizacao | dataInicial (query, obrigatorio, usado); dataFinal (query, obrigatorio, usado); codigoModalidadeContratacao (query, obrigatorio, usado); codigoModoDisputa (query, opcional, nao usado); uf (query, opcional, nao usado); codigoMunicipioIbge (query, opcional, nao usado); cnpj (query, opcional, nao usado); codigoUnidadeAdministrativa (query, opcional, nao usado); idUsuario (query, opcional, nao usado); pagina (query, obrigatorio, usado); tamanhoPagina (query, opcional, usado) |
| itens | API PNCP | https://pncp.gov.br/api/pncp/swagger-ui/index.html | https://pncp.gov.br/pncp-api/v3/api-docs | GET /v1/orgaos/{cnpj}/compras/{ano}/{sequencial}/itens | pesquisarCompraItem | cnpj (path, obrigatorio, usado); ano (path, obrigatorio, usado); sequencial (path, obrigatorio, usado); pagina (query, opcional, nao usado); tamanhoPagina (query, opcional, nao usado) |
| resultados_itens | API PNCP | https://pncp.gov.br/api/pncp/swagger-ui/index.html | https://pncp.gov.br/pncp-api/v3/api-docs | GET /v1/orgaos/{cnpj}/compras/{ano}/{sequencial}/itens/{numeroItem}/resultados | recuperarResultados | cnpj (path, obrigatorio, usado); ano (path, obrigatorio, usado); sequencial (path, obrigatorio, usado); numeroItem (path, obrigatorio, usado) |

## Dicionario de dados

### contratacoes

| Nome do campo | Data de inicio da coleta | Status | Descricao curta |
|---|---|---|---|
| data.srp | 2026-05-20 | ativo | Indica se a contratação está enquadrada como Sistema de Registro de Preços (SRP); verdadeiro quando a contratação utiliza esse regime de aquisição |
| data.orgaoEntidade | 2026-05-20 | ativo | Objeto que reúne os dados do órgão ou entidade responsável pela contratação |
| data.orgaoEntidade.cnpj | 2026-05-20 | ativo | CNPJ do órgão ou entidade responsável pela contratação |
| data.orgaoEntidade.razaoSocial | 2026-05-20 | ativo | Razão social do órgão ou entidade que realiza a contratação |
| data.orgaoEntidade.poderId | 2026-05-20 | ativo | Código do poder a que pertence o órgão (L – Legislativo, E – Executivo, J – Judiciário) |
| data.orgaoEntidade.esferaId | 2026-05-20 | ativo | Código da esfera administrativa do órgão (F – Federal, E – Estadual, M – Municipal, D – Distrital) |
| data.anoCompra | 2026-05-20 | ativo | Ano em que a contratação foi realizada |
| data.sequencialCompra | 2026-05-20 | ativo | Número sequencial gerado pelo PNCP quando a contratação foi inserida no sistema |
| data.dataInclusao | 2026-05-20 | ativo | Data em que o registro da contratação foi incluído no PNCP |
| data.dataPublicacaoPncp | 2026-05-20 | ativo | Data em que a contratação foi publicada no PNCP |
| data.dataAtualizacao | 2026-05-20 | ativo | Data da última atualização do registro da contratação no PNCP |
| data.numeroCompra | 2026-05-20 | ativo | Número da contratação no sistema de origem (por exemplo, o número do processo no órgão) |
| data.unidadeOrgao | 2026-05-20 | ativo | Objeto com os dados da unidade administrativa do órgão responsável pela contratação |
| data.unidadeOrgao.ufNome | 2026-05-20 | ativo | Nome da unidade federativa (estado) da unidade administrativa do órgão |
| data.unidadeOrgao.codigoIbge | 2026-05-20 | ativo | Código IBGE do município da unidade administrativa do órgão |
| data.unidadeOrgao.codigoUnidade | 2026-05-20 | ativo | Código da unidade administrativa pertencente ao órgão |
| data.unidadeOrgao.nomeUnidade | 2026-05-20 | ativo | Nome da unidade administrativa pertencente ao órgão |
| data.unidadeOrgao.ufSigla | 2026-05-20 | ativo | Sigla da unidade federativa (UF) da unidade administrativa do órgão |
| data.unidadeOrgao.municipioNome | 2026-05-20 | ativo | Nome do município da unidade administrativa do órgão |
| data.amparoLegal | 2026-05-20 | ativo | Objeto com os dados do amparo legal que fundamenta a contratação |
| data.amparoLegal.descricao | 2026-05-20 | ativo | Descrição do amparo legal aplicável à contratação |
| data.amparoLegal.nome | 2026-05-20 | ativo | Nome do amparo legal aplicável à contratação |
| data.amparoLegal.codigo | 2026-05-20 | ativo | Código do amparo legal aplicável à contratação |
| data.dataAberturaProposta | 2026-05-20 | ativo | Data e hora de abertura do período de recebimento de propostas (horário de Brasília) |
| data.dataEncerramentoProposta | 2026-05-20 | ativo | Data e hora de encerramento do período de recebimento de propostas (horário de Brasília) |
| data.informacaoComplementar | 2026-05-20 | ativo | Informações complementares sobre o objeto ou condições da contratação |
| data.processo | 2026-05-20 | ativo | Número do processo de contratação no sistema de origem |
| data.objetoCompra | 2026-05-20 | ativo | Descrição do objeto da contratação |
| data.linkSistemaOrigem | 2026-05-20 | ativo | URL do portal ou sistema de origem para acompanhamento do processo da contratação |
| data.justificativaPresencial | 2026-05-20 | ativo | Justificativa para escolha da modalidade presencial (quando aplicável) |
| data.unidadeSubRogada | 2026-05-20 | ativo | Objeto com os dados da unidade administrativa do órgão subrogado (quando a contratação é realizada por outro órgão) |
| data.unidadeSubRogada.ufNome | 2026-05-20 | ativo | Nome da unidade federativa da unidade administrativa subrogada |
| data.unidadeSubRogada.codigoIbge | 2026-05-20 | ativo | Código IBGE do município da unidade administrativa subrogada |
| data.unidadeSubRogada.codigoUnidade | 2026-05-20 | ativo | Código da unidade administrativa subrogada |
| data.unidadeSubRogada.nomeUnidade | 2026-05-20 | ativo | Nome da unidade administrativa subrogada |
| data.unidadeSubRogada.ufSigla | 2026-05-20 | ativo | Sigla da unidade federativa da unidade administrativa subrogada |
| data.unidadeSubRogada.municipioNome | 2026-05-20 | ativo | Nome do município da unidade administrativa subrogada |
| data.orgaoSubRogado | 2026-05-20 | ativo | Objeto com os dados do órgão ou entidade subrogado (contratação compartilhada) |
| data.orgaoSubRogado.cnpj | 2026-05-20 | ativo | CNPJ do órgão ou entidade subrogado |
| data.orgaoSubRogado.razaoSocial | 2026-05-20 | ativo | Razão social do órgão ou entidade subrogado |
| data.orgaoSubRogado.poderId | 2026-05-20 | ativo | Código do poder ao qual pertence o órgão subrogado |
| data.orgaoSubRogado.esferaId | 2026-05-20 | ativo | Código da esfera administrativa do órgão subrogado |
| data.valorTotalHomologado | 2026-05-20 | ativo | Valor total homologado da contratação, com base nos resultados incluídos |
| data.numeroControlePNCP | 2026-05-20 | ativo | Número de controle PNCP da contratação (identificador único da contratação no PNCP) |
| data.modoDisputaId | 2026-05-20 | ativo | Código do modo de disputa utilizado na contratação (1 – Aberto, 2 – Fechado, 3 – Aberto‑Fechado) |
| data.dataAtualizacaoGlobal | 2026-05-20 | ativo | Data da última atualização global do registro da contratação no PNCP |
| data.linkProcessoEletronico | 2026-05-20 | ativo | URL do processo eletrônico relacionado à contratação (se disponível) |
| data.modalidadeId | 2026-05-20 | ativo | Código da modalidade de contratação conforme tabela de domínios |
| data.valorTotalEstimado | 2026-05-20 | ativo | Valor total estimado da contratação; retorna zero quando o orçamento é sigiloso e ainda não há resultado |
| data.modalidadeNome | 2026-05-20 | ativo | Nome da modalidade de contratação |
| data.modoDisputaNome | 2026-05-20 | ativo | Nome do modo de disputa utilizado na contratação |
| data.tipoInstrumentoConvocatorioCodigo | 2026-05-20 | ativo | Código do instrumento convocatório utilizado na contratação |
| data.tipoInstrumentoConvocatorioNome | 2026-05-20 | ativo | Nome do instrumento convocatório utilizado na contratação |
| data.fontesOrcamentarias | 2026-05-20 | ativo | Lista de fontes orçamentárias que financiam a contratação |
| data.fontesOrcamentarias.codigo | 2026-05-20 | ativo | Código da fonte orçamentária |
| data.fontesOrcamentarias.nome | 2026-05-20 | ativo | Nome da fonte orçamentária |
| data.fontesOrcamentarias.descricao | 2026-05-20 | ativo | Descrição da fonte orçamentária |
| data.fontesOrcamentarias.dataInclusao | 2026-05-20 | ativo | Data em que a fonte orçamentária foi cadastrada |
| data.situacaoCompraId | 2026-05-20 | ativo | Código da situação da contratação conforme tabela de domínios |
| data.situacaoCompraNome | 2026-05-20 | ativo | Nome descritivo da situação da contratação |
| data.usuarioNome | 2026-05-20 | ativo | Nome do usuário ou sistema que enviou a contratação ao PNCP |
| data.emendaParlamentar | 2026-05-21 | ativo | INCLUIR DESCRIÇÃO EM dicionario-dados.py |

### itens

| Nome do campo | Data de inicio da coleta | Status | Descricao curta |
|---|---|---|---|
| numeroItem | 2026-05-20 | ativo | Número sequencial do item dentro da contratação |
| endpoint | 2026-05-20 | operacional | Caminho do endpoint utilizado para consultar os detalhes do item |
| descricao | 2026-05-20 | ativo | Descrição detalhada do material ou serviço correspondente ao item |
| materialOuServico | 2026-05-20 | ativo | Indica se o item refere‑se a um material ("M") ou a um serviço ("S") |
| materialOuServicoNome | 2026-05-20 | ativo | Nome do material ou serviço associado ao item |
| valorUnitarioEstimado | 2026-05-20 | ativo | Valor unitário estimado do item conforme informado na contratação |
| valorTotal | 2026-05-20 | ativo | Valor total estimado do item (quantidade × valor unitário) |
| quantidade | 2026-05-20 | ativo | Quantidade do item a ser contratada |
| unidadeMedida | 2026-05-20 | ativo | Unidade de medida utilizada para quantificar o item |
| orcamentoSigiloso | 2026-05-20 | ativo | Indicador se o orçamento do item é sigiloso (True/False) |
| itemCategoriaId | 2026-05-20 | ativo | Identificador da categoria do item no PNCP |
| itemCategoriaNome | 2026-05-20 | ativo | Nome da categoria do item |
| patrimonio | 2026-05-20 | ativo | Indica se o item se refere a um bem patrimonial (True/False) |
| codigoRegistroImobiliario | 2026-05-20 | ativo | Código de registro imobiliário, aplicável quando o item é um bem imóvel |
| criterioJulgamentoId | 2026-05-20 | ativo | Identificador do critério de julgamento associado ao item |
| criterioJulgamentoNome | 2026-05-20 | ativo | Nome do critério de julgamento associado ao item |
| situacaoCompraItem | 2026-05-20 | ativo | Código da situação do item da compra (1 – Em andamento, 2 – Homologado, 3 – Anulado/Revogado/Cancelado, 4 – Deserto, 5 – Fracassado) |
| situacaoCompraItemNome | 2026-05-20 | ativo | Descrição da situação do item da compra |
| tipoBeneficio | 2026-05-20 | ativo | Código do tipo de benefício aplicado ao item (domínio definido pelo PNCP) |
| tipoBeneficioNome | 2026-05-20 | ativo | Nome do tipo de benefício aplicado ao item |
| incentivoProdutivoBasico | 2026-05-20 | ativo | Indicador de incentivo produtivo básico associado ao item (True/False) |
| dataInclusao | 2026-05-20 | ativo | Data em que o item foi incluído no PNCP |
| dataAtualizacao | 2026-05-20 | ativo | Data da última atualização do item no PNCP |
| temResultado | 2026-05-20 | ativo | Indicador se existe resultado associado ao item (True/False) |
| imagem | 2026-05-20 | ativo | URL ou referência a uma imagem ilustrativa do item |
| aplicabilidadeMargemPreferenciaNormal | 2026-05-20 | ativo | Indica se se aplica margem de preferência normal ao item (True/False) |
| aplicabilidadeMargemPreferenciaAdicional | 2026-05-20 | ativo | Indica se se aplica margem de preferência adicional ao item (True/False) |
| percentualMargemPreferenciaNormal | 2026-05-20 | ativo | Percentual de margem de preferência normal aplicado ao item |
| percentualMargemPreferenciaAdicional | 2026-05-20 | ativo | Percentual de margem de preferência adicional aplicado ao item |
| ncmNbsCodigo | 2026-05-20 | ativo | Código NCM ou NBS (Nomenclatura Comum do Mercosul/Nomenclatura Brasileira de Serviços) do item |
| ncmNbsDescricao | 2026-05-20 | ativo | Descrição da Nomenclatura Comum do Mercosul ou NBS do item |
| catalogo.id | 2026-05-20 | ativo | Identificador do item no catálogo de bens ou serviços |
| catalogo.nome | 2026-05-20 | ativo | Nome do item conforme cadastrado no catálogo |
| catalogo.descricao | 2026-05-20 | ativo | Descrição do item conforme o catálogo |
| catalogo.dataInclusao | 2026-05-20 | ativo | Data de inclusão do item no catálogo |
| catalogo.dataAtualizacao | 2026-05-20 | ativo | Data de última atualização do item no catálogo |
| catalogo.statusAtivo | 2026-05-20 | ativo | Indica se o item do catálogo está ativo (True/False) |
| catalogo.url | 2026-05-20 | ativo | URL de referência para o item no catálogo oficial |
| categoriaItemCatalogo.id | 2026-05-20 | ativo | Identificador da categoria do item no catálogo |
| categoriaItemCatalogo.nome | 2026-05-20 | ativo | Nome da categoria do item no catálogo |
| categoriaItemCatalogo.descricao | 2026-05-20 | ativo | Descrição da categoria do item no catálogo |
| categoriaItemCatalogo.dataInclusao | 2026-05-20 | ativo | Data de inclusão da categoria no catálogo |
| categoriaItemCatalogo.dataAtualizacao | 2026-05-20 | ativo | Data de atualização da categoria no catálogo |
| categoriaItemCatalogo.statusAtivo | 2026-05-20 | ativo | Indica se a categoria do catálogo está ativa (True/False) |
| catalogoCodigoItem | 2026-05-20 | ativo | Código do item no catálogo utilizado pela contratação |
| informacaoComplementar | 2026-05-20 | ativo | Informações complementares sobre o item da contratação |
| tipoMargemPreferencia.codigo | 2026-05-21 | ativo | INCLUIR DESCRIÇÃO EM dicionario-dados.py |
| tipoMargemPreferencia.nome | 2026-05-21 | ativo | INCLUIR DESCRIÇÃO EM dicionario-dados.py |
| exigenciaConteudoNacional | 2026-05-21 | ativo | INCLUIR DESCRIÇÃO EM dicionario-dados.py |

### resultados_itens

| Nome do campo | Data de inicio da coleta | Status | Descricao curta |
|---|---|---|---|
| numeroControlePNCPCompra | 2026-05-20 | ativo | Número de controle PNCP da contratação a que o item pertence |
| numeroItem | 2026-05-20 | ativo | Número do item na contratação |
| endpoint | 2026-05-20 | operacional | Caminho do endpoint utilizado para consultar detalhes do resultado do item |
| sequencialResultado | 2026-05-20 | ativo | Número sequencial do resultado associado ao item |
| situacaoCompraItemResultadoId | 2026-05-20 | ativo | Identificador da situação do item no resultado de compra |
| situacaoCompraItemResultadoNome | 2026-05-20 | ativo | Nome descritivo da situação do item no resultado de compra |
| dataInclusao | 2026-05-20 | ativo | Data de inclusão do resultado do item no PNCP |
| dataAtualizacao | 2026-05-20 | ativo | Data de última atualização do resultado do item no PNCP |
| niFornecedor | 2026-05-20 | ativo | Número de Identificação Fiscal do fornecedor (CPF ou CNPJ) |
| nomeRazaoSocialFornecedor | 2026-05-20 | ativo | Nome ou razão social do fornecedor vencedor do item |
| tipoPessoa | 2026-05-20 | ativo | Tipo de pessoa do fornecedor (física ou jurídica) |
| porteFornecedorId | 2026-05-20 | ativo | Identificador do porte do fornecedor (micro, pequena, média ou grande empresa) |
| porteFornecedorNome | 2026-05-20 | ativo | Nome do porte do fornecedor |
| naturezaJuridicaId | 2026-05-20 | ativo | Identificador da natureza jurídica do fornecedor |
| naturezaJuridicaNome | 2026-05-20 | ativo | Nome da natureza jurídica do fornecedor |
| codigoPais | 2026-05-20 | ativo | Código do país do fornecedor |
| quantidadeHomologada | 2026-05-20 | ativo | Quantidade homologada do item no resultado |
| valorUnitarioHomologado | 2026-05-20 | ativo | Valor unitário homologado do item |
| valorTotalHomologado | 2026-05-20 | ativo | Valor total homologado do item no resultado |
| percentualDesconto | 2026-05-20 | ativo | Percentual de desconto oferecido pelo fornecedor vencedor |
| paisOrigemProdutoServico.id | 2026-05-20 | ativo | Código do país de origem do produto ou serviço fornecido |
| paisOrigemProdutoServico.nome | 2026-05-20 | ativo | Nome do país de origem do produto ou serviço |
| moedaEstrangeira.id | 2026-05-20 | ativo | Identificador da moeda estrangeira utilizada no resultado (quando aplicável) |
| moedaEstrangeira.simbolo | 2026-05-20 | ativo | Símbolo da moeda estrangeira utilizada |
| moedaEstrangeira.nome | 2026-05-20 | ativo | Nome da moeda estrangeira utilizada |
| timezoneCotacaoMoedaEstrangeira | 2026-05-20 | ativo | Fuso horário de referência da cotação da moeda estrangeira |
| valorNominalMoedaEstrangeira | 2026-05-20 | ativo | Valor nominal do item em moeda estrangeira |
| dataCotacaoMoedaEstrangeira | 2026-05-20 | ativo | Data em que foi realizada a cotação da moeda estrangeira |
| aplicacaoMargemPreferencia | 2026-05-20 | ativo | Indicador se foi aplicada margem de preferência na contratação (True/False) |
| amparoLegalMargemPreferencia.id | 2026-05-20 | ativo | Identificador do amparo legal relacionado à aplicação da margem de preferência |
| amparoLegalMargemPreferencia.nome | 2026-05-20 | ativo | Nome do amparo legal relacionado à aplicação da margem de preferência |
| amparoLegalMargemPreferencia.descricao | 2026-05-20 | ativo | Descrição do amparo legal relacionado à aplicação da margem de preferência |
| amparoLegalMargemPreferencia.statusAtivo | 2026-05-20 | ativo | Indica se o amparo legal de margem de preferência está ativo |
| aplicacaoBeneficioMeEpp | 2026-05-20 | ativo | Indicador se foi concedido benefício específico para ME/EPP (Micro e Pequenas Empresas) |
| aplicacaoCriterioDesempate | 2026-05-20 | ativo | Indicador se foi aplicado critério de desempate conforme a legislação |
| amparoLegalCriterioDesempate.id | 2026-05-20 | ativo | Identificador do amparo legal relacionado ao critério de desempate |
| amparoLegalCriterioDesempate.nome | 2026-05-20 | ativo | Nome do amparo legal relacionado ao critério de desempate |
| amparoLegalCriterioDesempate.descricao | 2026-05-20 | ativo | Descrição do amparo legal relacionado ao critério de desempate |
| amparoLegalCriterioDesempate.statusAtivo | 2026-05-20 | ativo | Indica se o amparo legal do critério de desempate está ativo |
| indicadorSubcontratacao | 2026-05-20 | ativo | Indica se há subcontratação no resultado do item (True/False) |
| ordemClassificacaoSrp | 2026-05-20 | ativo | Ordem de classificação do fornecedor no Sistema de Registro de Preços (SRP) |
| dataResultado | 2026-05-20 | ativo | Data do resultado homologado para o item no PNCP |
| dataCancelamento | 2026-05-20 | ativo | Data de cancelamento do resultado do item (se houver) |
| motivoCancelamento | 2026-05-20 | ativo | Motivo do cancelamento do resultado do item (quando cancelado) |
| reservaRemanescente.codigo | 2026-08-14 | ativo | INCLUIR DESCRIÇÃO EM dicionario-dados.py |
| reservaRemanescente.nome | 2026-08-14 | ativo | INCLUIR DESCRIÇÃO EM dicionario-dados.py |
| localidadeExterior | 2026-08-14 | ativo | INCLUIR DESCRIÇÃO EM dicionario-dados.py |
| localidadeFornecedor.ufNome | 2026-08-14 | ativo | INCLUIR DESCRIÇÃO EM dicionario-dados.py |
| localidadeFornecedor.uf | 2026-08-14 | ativo | INCLUIR DESCRIÇÃO EM dicionario-dados.py |
| localidadeFornecedor.nomeMunicipio | 2026-08-14 | ativo | INCLUIR DESCRIÇÃO EM dicionario-dados.py |
| localidadeFornecedor.codigoIbge | 2026-08-14 | ativo | INCLUIR DESCRIÇÃO EM dicionario-dados.py |
