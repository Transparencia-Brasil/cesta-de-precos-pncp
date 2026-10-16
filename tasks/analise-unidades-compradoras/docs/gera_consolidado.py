"""Consolida as saídas por período de ../output em output/consolidado/.

Gera um CSV por tabela (contratações, itens, medicamentos-resultados) e um XLSX com uma aba por tabela.
Mantém todas as linhas de todos os períodos (a mesma contratação pode aparecer em mais de um, pois a
coleta do PNCP é por data de atualização), com a coluna `periodo` indicando a origem de cada linha.
Só uma seleção de colunas é exportada, renomeadas para nomes legíveis.
"""

from pathlib import Path

import pandas as pd

TASK_DIR = Path(__file__).resolve().parents[1]
OUTPUT_DIR = TASK_DIR / "output"
DESTINO = OUTPUT_DIR / "consolidado"
NOME_BASE = "unidades-compradoras"

# coluna original -> nome legível (a ordem aqui é a ordem no arquivo final)
COLUNAS = {
    "contratacoes": {
        "periodo": "periodo",
        "unidade_alvo": "unidade_alvo",
        "data.numeroControlePNCP": "numero_controle_pncp",
        "data.anoCompra": "ano_compra",
        "data.sequencialCompra": "sequencial_compra",
        "data.numeroCompra": "numero_compra",
        "data.processo": "processo",
        "data.orgaoEntidade.cnpj": "cnpj_orgao",
        "data.orgaoEntidade.razaoSocial": "razao_social_orgao",
        "data.unidadeOrgao.codigoUnidade": "codigo_unidade",
        "data.unidadeOrgao.nomeUnidade": "nome_unidade",
        "data.unidadeOrgao.municipioNome": "municipio",
        "data.unidadeOrgao.ufSigla": "uf",
        "data.modalidadeNome": "modalidade",
        "data.modoDisputaNome": "modo_disputa",
        "data.tipoInstrumentoConvocatorioNome": "instrumento_convocatorio",
        "data.amparoLegal.nome": "amparo_legal",
        "data.srp": "registro_de_precos",
        "data.situacaoCompraNome": "situacao",
        "data.objetoCompra": "objeto",
        "data.informacaoComplementar": "informacao_complementar",
        "data.valorTotalEstimado": "valor_total_estimado",
        "data.valorTotalHomologado": "valor_total_homologado",
        "data.dataAberturaProposta": "data_abertura_proposta",
        "data.dataEncerramentoProposta": "data_encerramento_proposta",
        "data.dataPublicacaoPncp": "data_publicacao_pncp",
        "data.dataInclusao": "data_inclusao",
        "data.dataAtualizacao": "data_atualizacao",
        "data.dataAtualizacaoGlobal": "data_atualizacao_global",
        "link_pncp": "link_pncp",
        "data.linkSistemaOrigem": "link_sistema_origem",
    },
    "itens": {
        "periodo": "periodo",
        "unidade_alvo": "unidade_alvo",
        "numeroControlePNCP": "numero_controle_pncp",
        "data.orgaoEntidade.cnpj": "cnpj_orgao",
        "data.unidadeOrgao.nomeUnidade": "nome_unidade",
        "data.modalidadeNome": "modalidade",
        "numeroItem": "numero_item",
        "descricao": "descricao",
        "materialOuServicoNome": "material_ou_servico",
        "unidadeMedida": "unidade_medida",
        "quantidade": "quantidade",
        "valorUnitarioEstimado": "valor_unitario_estimado",
        "valorTotal": "valor_total_estimado",
        "orcamentoSigiloso": "orcamento_sigiloso",
        "criterioJulgamentoNome": "criterio_julgamento",
        "situacaoCompraItemNome": "situacao_item",
        "tipoBeneficioNome": "tipo_beneficio",
        "temResultado": "tem_resultado",
        "ncmNbsCodigo": "ncm_nbs_codigo",
        "ncmNbsDescricao": "ncm_nbs_descricao",
        "catalogoCodigoItem": "codigo_item_catalogo",
        "informacaoComplementar": "informacao_complementar",
        "medicamento": "medicamento",
        "codigo_pdm": "codigo_pdm",
        "codigo_br": "codigo_br",
        "similaridade": "similaridade",
        "dataInclusao": "data_inclusao",
        "dataAtualizacao": "data_atualizacao",
    },
    "medicamentos-resultados": {
        "periodo": "periodo",
        "unidade_alvo": "unidade_alvo",
        "numeroControlePNCP": "numero_controle_pncp",
        "data.orgaoEntidade.cnpj": "cnpj_orgao",
        "data.unidadeOrgao.nomeUnidade": "nome_unidade",
        "numeroItem": "numero_item",
        "descricao": "descricao",
        "codigo_br": "codigo_br",
        "codigo_pdm": "codigo_pdm",
        "similaridade": "similaridade",
        "unidadeMedida": "unidade_medida",
        "quantidade": "quantidade",
        "valorUnitarioEstimado": "valor_unitario_estimado",
        "valorTotal": "valor_total_estimado",
        "situacaoCompraItemNome": "situacao_item",
        "resultado.sequencialResultado": "sequencial_resultado",
        "resultado.situacaoCompraItemResultadoNome": "situacao_resultado",
        "resultado.niFornecedor": "cnpj_cpf_fornecedor",
        "resultado.nomeRazaoSocialFornecedor": "fornecedor",
        "resultado.tipoPessoa": "tipo_pessoa_fornecedor",
        "resultado.porteFornecedorNome": "porte_fornecedor",
        "resultado.naturezaJuridicaNome": "natureza_juridica_fornecedor",
        "resultado.localidadeFornecedor.nomeMunicipio": "municipio_fornecedor",
        "resultado.localidadeFornecedor.uf": "uf_fornecedor",
        "resultado.quantidadeHomologada": "quantidade_homologada",
        "resultado.valorUnitarioHomologado": "valor_unitario_homologado",
        "resultado.valorTotalHomologado": "valor_total_homologado",
        "resultado.percentualDesconto": "percentual_desconto",
        "resultado.aplicacaoBeneficioMeEpp": "beneficio_me_epp",
        "resultado.ordemClassificacaoSrp": "ordem_classificacao_srp",
        "resultado.dataResultado": "data_resultado",
        "resultado.dataCancelamento": "data_cancelamento",
        "resultado.motivoCancelamento": "motivo_cancelamento",
    },
}

# saídas antigas do notebook trazem o nome da unidade em `unidade_alvo`; troca pelo CNPJ (ou raiz) buscado,
# igual ao `CNPJS_ALVO` do notebook. Saídas novas já trazem o CNPJ e passam sem mudança.
CNPJ_POR_UNIDADE = {
    "unidade01": "25089137000195",
    "unidade02": "16723250000190",
    "unidade03": "18729020",
}

# tipos aplicados só no XLSX (o CSV mantém o texto como veio dos arquivos de origem)
NUMERICAS = {
    "numero_item", "quantidade", "valor_unitario_estimado", "valor_total_estimado", "valor_total_homologado",
    "similaridade", "quantidade_homologada", "valor_unitario_homologado", "percentual_desconto",
    "ordem_classificacao_srp", "sequencial_resultado",
}
BOOLEANAS = {"registro_de_precos", "orcamento_sigiloso", "tem_resultado", "medicamento", "beneficio_me_epp"}
# códigos que o pandas gravou como float ("2036.0")
CODIGOS = ["codigo_pdm", "codigo_br"]


def le_tabela(nome: str) -> pd.DataFrame:
    partes = []
    for pasta in sorted(p for p in OUTPUT_DIR.iterdir() if p.is_dir() and p != DESTINO):
        arquivo = pasta / f"{nome}.csv"
        if arquivo.exists():
            partes.append(pd.read_csv(arquivo, dtype=str).assign(periodo=pasta.name))
    df = pd.concat(partes, ignore_index=True)
    df["unidade_alvo"] = df["unidade_alvo"].replace(CNPJ_POR_UNIDADE)

    if nome == "contratacoes":
        df["link_pncp"] = (
            "https://pncp.gov.br/app/editais/" + df["data.orgaoEntidade.cnpj"] + "/"
            + df["data.anoCompra"] + "/" + df["data.sequencialCompra"]
        )

    colunas = COLUNAS[nome]
    df = df.reindex(columns=list(colunas)).rename(columns=colunas)
    for col in CODIGOS:
        if col in df:
            df[col] = df[col].str.replace(r"\.0$", "", regex=True)
    return df


def tipa_para_xlsx(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    for col in df.columns:
        if col in NUMERICAS:
            df[col] = pd.to_numeric(df[col], errors="coerce")
        elif col in BOOLEANAS:
            df[col] = df[col].str.upper().map({"TRUE": True, "FALSE": False})
        elif col.startswith("data_"):
            df[col] = pd.to_datetime(df[col], errors="coerce")
    return df


def formata_aba(ws, df: pd.DataFrame) -> None:
    ws.freeze_panes = "A2"
    ws.auto_filter.ref = ws.dimensions
    for i, col in enumerate(df.columns, start=1):
        maior = max([len(col), *df[col].astype(str).str.len().head(500).tolist()]) if len(df) else len(col)
        ws.column_dimensions[ws.cell(row=1, column=i).column_letter].width = min(max(maior + 2, 10), 60)


def main() -> None:
    DESTINO.mkdir(parents=True, exist_ok=True)
    tabelas = {nome: le_tabela(nome) for nome in COLUNAS}

    for nome, df in tabelas.items():
        caminho = DESTINO / f"{nome}.csv"
        df.to_csv(caminho, index=False)
        print(f"{caminho.relative_to(TASK_DIR)}: {len(df)} linhas x {df.shape[1]} colunas")

    caminho_xlsx = DESTINO / f"{NOME_BASE}.xlsx"
    with pd.ExcelWriter(caminho_xlsx, engine="openpyxl", datetime_format="yyyy-mm-dd hh:mm:ss") as writer:
        for nome, df in tabelas.items():
            tipado = tipa_para_xlsx(df)
            tipado.to_excel(writer, sheet_name=nome, index=False)
            formata_aba(writer.sheets[nome], df)
    print(f"{caminho_xlsx.relative_to(TASK_DIR)}: abas {', '.join(tabelas)}")


if __name__ == "__main__":
    main()
