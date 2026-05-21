"""Atualiza templates dos coletores PNCP a partir da documentacao OpenAPI.

O script consulta apenas recursos de documentacao Swagger/OpenAPI. Ele nao
chama endpoints operacionais de coleta.
"""

from __future__ import annotations

import argparse
import csv
import importlib.util
import json
import socket
import sys
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple


DEFAULT_BASELINE_DATE = "2026-05-20"
CSV_FIELDS = [
    "endpoint_alias",
    "campo",
    "coluna_template",
    "fonte",
    "schema_api",
    "tipo_api",
    "formato_api",
    "descricao",
    "data_inicio_coleta",
    "data_atualizacao_template",
    "presente_na_api",
    "usar_no_template",
    "status_template",
    "ordem_template",
    "ordem_api",
]

DESCRIPTION_PLACEHOLDER = "INCLUIR DESCRIÇÃO EM dicionario-dados.py"


INITIAL_TEMPLATE_COLUMNS: Dict[str, List[str]] = {
    "contratacoes": [
        "data.srp",
        "data.orgaoEntidade",
        "data.orgaoEntidade.cnpj",
        "data.orgaoEntidade.razaoSocial",
        "data.orgaoEntidade.poderId",
        "data.orgaoEntidade.esferaId",
        "data.anoCompra",
        "data.sequencialCompra",
        "data.dataInclusao",
        "data.dataPublicacaoPncp",
        "data.dataAtualizacao",
        "data.numeroCompra",
        "data.unidadeOrgao",
        "data.unidadeOrgao.ufNome",
        "data.unidadeOrgao.codigoIbge",
        "data.unidadeOrgao.codigoUnidade",
        "data.unidadeOrgao.nomeUnidade",
        "data.unidadeOrgao.ufSigla",
        "data.unidadeOrgao.municipioNome",
        "data.amparoLegal",
        "data.amparoLegal.descricao",
        "data.amparoLegal.nome",
        "data.amparoLegal.codigo",
        "data.dataAberturaProposta",
        "data.dataEncerramentoProposta",
        "data.informacaoComplementar",
        "data.processo",
        "data.objetoCompra",
        "data.linkSistemaOrigem",
        "data.justificativaPresencial",
        "data.unidadeSubRogada",
        "data.unidadeSubRogada.ufNome",
        "data.unidadeSubRogada.codigoIbge",
        "data.unidadeSubRogada.codigoUnidade",
        "data.unidadeSubRogada.nomeUnidade",
        "data.unidadeSubRogada.ufSigla",
        "data.unidadeSubRogada.municipioNome",
        "data.orgaoSubRogado",
        "data.orgaoSubRogado.cnpj",
        "data.orgaoSubRogado.razaoSocial",
        "data.orgaoSubRogado.poderId",
        "data.orgaoSubRogado.esferaId",
        "data.valorTotalHomologado",
        "data.numeroControlePNCP",
        "data.modoDisputaId",
        "data.dataAtualizacaoGlobal",
        "data.linkProcessoEletronico",
        "data.modalidadeId",
        "data.valorTotalEstimado",
        "data.modalidadeNome",
        "data.modoDisputaNome",
        "data.tipoInstrumentoConvocatorioCodigo",
        "data.tipoInstrumentoConvocatorioNome",
        "data.fontesOrcamentarias",
        "data.fontesOrcamentarias.codigo",
        "data.fontesOrcamentarias.nome",
        "data.fontesOrcamentarias.descricao",
        "data.fontesOrcamentarias.dataInclusao",
        "data.situacaoCompraId",
        "data.situacaoCompraNome",
        "data.usuarioNome",
    ],
    "itens": [
        "numeroItem",
        "endpoint",
        "descricao",
        "materialOuServico",
        "materialOuServicoNome",
        "valorUnitarioEstimado",
        "valorTotal",
        "quantidade",
        "unidadeMedida",
        "orcamentoSigiloso",
        "itemCategoriaId",
        "itemCategoriaNome",
        "patrimonio",
        "codigoRegistroImobiliario",
        "criterioJulgamentoId",
        "criterioJulgamentoNome",
        "situacaoCompraItem",
        "situacaoCompraItemNome",
        "tipoBeneficio",
        "tipoBeneficioNome",
        "incentivoProdutivoBasico",
        "dataInclusao",
        "dataAtualizacao",
        "temResultado",
        "imagem",
        "aplicabilidadeMargemPreferenciaNormal",
        "aplicabilidadeMargemPreferenciaAdicional",
        "percentualMargemPreferenciaNormal",
        "percentualMargemPreferenciaAdicional",
        "ncmNbsCodigo",
        "ncmNbsDescricao",
        "catalogo.id",
        "catalogo.nome",
        "catalogo.descricao",
        "catalogo.dataInclusao",
        "catalogo.dataAtualizacao",
        "catalogo.statusAtivo",
        "catalogo.url",
        "categoriaItemCatalogo.id",
        "categoriaItemCatalogo.nome",
        "categoriaItemCatalogo.descricao",
        "categoriaItemCatalogo.dataInclusao",
        "categoriaItemCatalogo.dataAtualizacao",
        "categoriaItemCatalogo.statusAtivo",
        "catalogoCodigoItem",
        "informacaoComplementar",
    ],
    "resultados_itens": [
        "numeroControlePNCPCompra",
        "numeroItem",
        "endpoint",
        "sequencialResultado",
        "situacaoCompraItemResultadoId",
        "situacaoCompraItemResultadoNome",
        "dataInclusao",
        "dataAtualizacao",
        "niFornecedor",
        "nomeRazaoSocialFornecedor",
        "tipoPessoa",
        "porteFornecedorId",
        "porteFornecedorNome",
        "naturezaJuridicaId",
        "naturezaJuridicaNome",
        "codigoPais",
        "quantidadeHomologada",
        "valorUnitarioHomologado",
        "valorTotalHomologado",
        "percentualDesconto",
        "paisOrigemProdutoServico.id",
        "paisOrigemProdutoServico.nome",
        "moedaEstrangeira.id",
        "moedaEstrangeira.simbolo",
        "moedaEstrangeira.nome",
        "timezoneCotacaoMoedaEstrangeira",
        "valorNominalMoedaEstrangeira",
        "dataCotacaoMoedaEstrangeira",
        "aplicacaoMargemPreferencia",
        "amparoLegalMargemPreferencia.id",
        "amparoLegalMargemPreferencia.nome",
        "amparoLegalMargemPreferencia.descricao",
        "amparoLegalMargemPreferencia.statusAtivo",
        "aplicacaoBeneficioMeEpp",
        "aplicacaoCriterioDesempate",
        "amparoLegalCriterioDesempate.id",
        "amparoLegalCriterioDesempate.nome",
        "amparoLegalCriterioDesempate.descricao",
        "amparoLegalCriterioDesempate.statusAtivo",
        "indicadorSubcontratacao",
        "ordemClassificacaoSrp",
        "dataResultado",
        "dataCancelamento",
        "motivoCancelamento",
    ],
}


@dataclass(frozen=True)
class EndpointConfig:
    alias: str
    modulo: str
    swagger_ui_url: str
    openapi_url: str
    operation_id: str
    template_file: str
    response_data_property: Optional[str]
    column_prefix: str = ""
    include_object_parents: bool = False
    collector_parameters: Tuple[str, ...] = ()


ENDPOINTS: Tuple[EndpointConfig, ...] = (
    EndpointConfig(
        alias="contratacoes",
        modulo="API PNCP Consulta",
        swagger_ui_url="https://pncp.gov.br/api/consulta/swagger-ui/index.html",
        openapi_url="https://pncp.gov.br/pncp-consulta/v3/api-docs",
        operation_id="consultarContratacaoPorDataUltimaAtualizacao",
        template_file="template-contratacoes.csv",
        response_data_property="data",
        column_prefix="data.",
        include_object_parents=True,
        collector_parameters=("dataInicial", "dataFinal", "codigoModalidadeContratacao", "pagina", "tamanhoPagina"),
    ),
    EndpointConfig(
        alias="itens",
        modulo="API PNCP",
        swagger_ui_url="https://pncp.gov.br/api/pncp/swagger-ui/index.html",
        openapi_url="https://pncp.gov.br/pncp-api/v3/api-docs",
        operation_id="pesquisarCompraItem",
        template_file="template-itens.csv",
        response_data_property=None,
        collector_parameters=("cnpj", "ano", "sequencial"),
    ),
    EndpointConfig(
        alias="resultados_itens",
        modulo="API PNCP",
        swagger_ui_url="https://pncp.gov.br/api/pncp/swagger-ui/index.html",
        openapi_url="https://pncp.gov.br/pncp-api/v3/api-docs",
        operation_id="recuperarResultados",
        template_file="template-resultados-itens.csv",
        response_data_property=None,
        collector_parameters=("cnpj", "ano", "sequencial", "numeroItem"),
    ),
)


def parse_args() -> argparse.Namespace:
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(
        description="Atualiza CSVs de template dos coletores PNCP a partir da OpenAPI oficial."
    )
    parser.add_argument("--templates-dir", default=str(root / "templates"))
    parser.add_argument("--readme", default=str(root / "README.md"))
    parser.add_argument("--timeout", type=int, default=30)
    parser.add_argument(
        "--attempts",
        type=int,
        default=10,
        help="Total de tentativas por recurso de documentacao. Padrao: 1 chamada + 5 retentativas.",
    )
    parser.add_argument("--retry-sleep", type=float, default=1.0)
    parser.add_argument("--today", default=date.today().isoformat())
    parser.add_argument("--dry-run", action="store_true", help="Calcula mudancas sem gravar CSVs/README.")
    parser.add_argument("--allow-ipv6", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--force-ipv4", action="store_true", help="Forca IPv4 ao consultar a documentacao.")
    parser.add_argument(
        "--dicionario",
        default=str(Path(__file__).parent / "dicionario-dados.py"),
        help="Caminho para dicionario-dados.py com as descricoes dos campos para o README.",
    )
    return parser.parse_args()


def force_ipv4() -> None:
    original_getaddrinfo = socket.getaddrinfo

    def getaddrinfo_ipv4(
        host: str,
        port: int,
        family: int = 0,
        type: int = 0,
        proto: int = 0,
        flags: int = 0,
    ) -> List[Tuple[Any, ...]]:
        return original_getaddrinfo(host, port, socket.AF_INET, type, proto, flags)

    socket.getaddrinfo = getaddrinfo_ipv4  # type: ignore[assignment]


def url_origin(url: str) -> str:
    parsed = urllib.parse.urlparse(url)
    return urllib.parse.urlunparse((parsed.scheme, parsed.netloc, "", "", "", ""))


def swagger_prefix(swagger_ui_url: str) -> str:
    path = urllib.parse.urlparse(swagger_ui_url).path
    for marker in ("/swagger-ui/", "/swaggerui/"):
        if marker in path:
            return path.split(marker, 1)[0].rstrip("/")
    return path.rsplit("/", 1)[0].rstrip("/")


def make_absolute_url(reference_url: str, candidate_url: str) -> str:
    if candidate_url.startswith("//"):
        parsed = urllib.parse.urlparse(reference_url)
        return "{}:{}".format(parsed.scheme, candidate_url)
    if candidate_url.startswith("/"):
        return "{}{}".format(url_origin(reference_url), candidate_url)
    return urllib.parse.urljoin(reference_url, candidate_url)


def pncp_aliases(candidate_url: str) -> List[str]:
    parsed = urllib.parse.urlparse(candidate_url)
    aliases = [candidate_url]
    replacements = {
        "/pncp-consulta/": "/api/consulta/",
        "/pncp-api/": "/api/pncp/",
        "/api/consulta/": "/pncp-consulta/",
        "/api/pncp/": "/pncp-api/",
    }
    for old, new in replacements.items():
        if parsed.path.startswith(old):
            new_path = new + parsed.path[len(old) :]
            aliases.append(urllib.parse.urlunparse(parsed._replace(path=new_path)))
    return dedupe(aliases)


def dedupe(values: Iterable[str]) -> List[str]:
    seen = set()
    output = []
    for value in values:
        if value and value not in seen:
            output.append(value)
            seen.add(value)
    return output


def fetch_text(url: str, timeout: int, attempts: int, retry_sleep: float) -> str:
    last_error: Optional[BaseException] = None
    for attempt in range(1, attempts + 1):
        request = urllib.request.Request(
            url,
            headers={
                "Accept": "application/json, text/html;q=0.9, */*;q=0.1",
                "User-Agent": "cesta-de-precos-pncp-template-validator/1.0",
            },
            method="GET",
        )
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                body = response.read()
                charset = response.headers.get_content_charset() or "utf-8"
                return body.decode(charset, errors="replace")
        except Exception as exc:  # noqa: BLE001 - erro vai para diagnostico operacional.
            last_error = exc
            if attempt < attempts:
                print(
                    "Falha ao consultar documentacao. "
                    "Fazendo nova tentativa {} de {}: {}".format(attempt, attempts - 1, url),
                    file=sys.stderr,
                )
                time.sleep(retry_sleep)
    raise RuntimeError("Falha ao obter {} apos {} tentativas: {!r}".format(url, attempts, last_error))


def fetch_json(url: str, timeout: int, attempts: int, retry_sleep: float) -> Dict[str, Any]:
    return json.loads(fetch_text(url, timeout=timeout, attempts=attempts, retry_sleep=retry_sleep))


def openapi_candidates(config: EndpointConfig, timeout: int, attempts: int, retry_sleep: float) -> List[str]:
    candidates = [config.openapi_url]
    origin = url_origin(config.swagger_ui_url)
    prefix = swagger_prefix(config.swagger_ui_url)
    candidates.append("{}{}/v3/api-docs".format(origin, prefix))

    output: List[str] = []
    for candidate in candidates:
        output.extend(pncp_aliases(candidate))
    return dedupe(output)


def fetch_openapi(config: EndpointConfig, timeout: int, attempts: int, retry_sleep: float) -> Dict[str, Any]:
    errors = []
    for candidate in openapi_candidates(config, timeout=timeout, attempts=attempts, retry_sleep=retry_sleep):
        try:
            spec = fetch_json(candidate, timeout=timeout, attempts=attempts, retry_sleep=retry_sleep)
        except Exception as exc:  # noqa: BLE001 - manter diagnostico.
            errors.append("{} -> {!r}".format(candidate, exc))
            continue
        if isinstance(spec, dict) and "paths" in spec and ("openapi" in spec or "swagger" in spec):
            return spec
        errors.append("{} -> resposta nao e OpenAPI".format(candidate))
    raise RuntimeError("Nao foi possivel obter OpenAPI para {}. Tentativas: {}".format(config.alias, errors))


def get_operation(spec: Dict[str, Any], operation_id: str) -> Tuple[str, str, Dict[str, Any]]:
    for path, path_item in spec.get("paths", {}).items():
        if not isinstance(path_item, dict):
            continue
        for method, operation in path_item.items():
            if isinstance(operation, dict) and operation.get("operationId") == operation_id:
                return path, str(method).upper(), operation
    raise KeyError("operationId nao encontrado: {}".format(operation_id))


def response_schema(operation: Dict[str, Any]) -> Dict[str, Any]:
    responses = operation.get("responses", {})
    response = responses.get("200")
    if response is None:
        for status_code, candidate in responses.items():
            if str(status_code).startswith("2"):
                response = candidate
                break
    if not isinstance(response, dict):
        raise KeyError("Operacao sem resposta 2xx documentada.")

    content = response.get("content", {})
    if "*/*" in content:
        schema = content["*/*"].get("schema")
    else:
        first_content = next(iter(content.values()), {})
        schema = first_content.get("schema")
    if not isinstance(schema, dict):
        raise KeyError("Resposta 2xx sem schema documentado.")
    return schema


def ref_name(ref: str) -> str:
    return urllib.parse.unquote(ref.rsplit("/", 1)[-1])


def resolve_ref(spec: Dict[str, Any], ref: str) -> Tuple[str, Dict[str, Any]]:
    if not ref.startswith("#/"):
        raise ValueError("Somente refs locais sao suportadas: {}".format(ref))
    node: Any = spec
    for part in ref[2:].split("/"):
        node = node[urllib.parse.unquote(part)]
    if not isinstance(node, dict):
        raise ValueError("Ref nao aponta para objeto: {}".format(ref))
    return ref_name(ref), node


def resolve_schema(spec: Dict[str, Any], schema: Dict[str, Any]) -> Tuple[Optional[str], Dict[str, Any]]:
    if "$ref" in schema:
        return resolve_ref(spec, str(schema["$ref"]))
    return None, schema


def operation_item_schema(spec: Dict[str, Any], operation: Dict[str, Any], config: EndpointConfig) -> Tuple[str, Dict[str, Any]]:
    schema_name, schema = resolve_schema(spec, response_schema(operation))

    if schema.get("type") == "array":
        items = schema.get("items", {})
        item_name, item_schema = resolve_schema(spec, items)
        return item_name or schema_name or "response_item", item_schema

    if config.response_data_property:
        prop = schema.get("properties", {}).get(config.response_data_property)
        if not isinstance(prop, dict):
            raise KeyError("Schema de resposta nao contem propriedade '{}'".format(config.response_data_property))
        _, prop_schema = resolve_schema(spec, prop)
        if prop_schema.get("type") == "array":
            item_name, item_schema = resolve_schema(spec, prop_schema.get("items", {}))
            return item_name or "response_item", item_schema
        return schema_name or "response", prop_schema

    return schema_name or "response", schema


def schema_type(schema: Dict[str, Any]) -> str:
    if "$ref" in schema:
        return "object"
    if schema.get("type"):
        return str(schema["type"])
    if schema.get("properties"):
        return "object"
    if "items" in schema:
        return "array"
    return ""


def flatten_schema(
    spec: Dict[str, Any],
    schema: Dict[str, Any],
    current_schema_name: str,
    prefix: str = "",
    include_object_parents: bool = False,
) -> List[Dict[str, str]]:
    output: List[Dict[str, str]] = []
    properties = schema.get("properties", {})
    if not isinstance(properties, dict):
        return output

    for property_name, property_schema in properties.items():
        if not isinstance(property_schema, dict):
            continue

        field_name = "{}.{}".format(prefix, property_name) if prefix else property_name
        property_type = schema_type(property_schema)
        property_format = str(property_schema.get("format", "") or "")

        if "$ref" in property_schema:
            child_schema_name, child_schema = resolve_ref(spec, str(property_schema["$ref"]))
            if include_object_parents:
                output.append(
                    {
                        "campo": field_name,
                        "schema_api": current_schema_name,
                        "tipo_api": "object",
                        "formato_api": property_format,
                        "descricao": "",
                    }
                )
            output.extend(
                flatten_schema(
                    spec,
                    child_schema,
                    child_schema_name,
                    prefix=field_name,
                    include_object_parents=include_object_parents,
                )
            )
            continue

        if property_type == "array":
            output.append(
                {
                    "campo": field_name,
                    "schema_api": current_schema_name,
                    "tipo_api": "array",
                    "formato_api": property_format,
                    "descricao": "",
                }
            )
            items = property_schema.get("items")
            if isinstance(items, dict):
                item_schema_name, item_schema = resolve_schema(spec, items)
                output.extend(
                    flatten_schema(
                        spec,
                        item_schema,
                        item_schema_name or current_schema_name,
                        prefix=field_name,
                        include_object_parents=include_object_parents,
                    )
                )
            continue

        if property_type == "object":
            if include_object_parents:
                output.append(
                    {
                        "campo": field_name,
                        "schema_api": current_schema_name,
                        "tipo_api": "object",
                        "formato_api": property_format,
                        "descricao": "",
                    }
                )
            output.extend(
                flatten_schema(
                    spec,
                    property_schema,
                    current_schema_name,
                    prefix=field_name,
                    include_object_parents=include_object_parents,
                )
            )
            continue

        output.append(
            {
                "campo": field_name,
                "schema_api": current_schema_name,
                "tipo_api": property_type,
                "formato_api": property_format,
                "descricao": "",
            }
        )

    return output


def api_metadata(spec: Dict[str, Any], config: EndpointConfig) -> Tuple[Dict[str, Dict[str, str]], Dict[str, Any]]:
    path, method, operation = get_operation(spec, config.operation_id)
    item_schema_name, item_schema = operation_item_schema(spec, operation, config)
    rows = flatten_schema(
        spec,
        item_schema,
        item_schema_name,
        include_object_parents=config.include_object_parents,
    )
    output: Dict[str, Dict[str, str]] = {}
    for order, row in enumerate(rows, start=1):
        column_name = "{}{}".format(config.column_prefix, row["campo"])
        output[column_name] = {
            "endpoint_alias": config.alias,
            "campo": row["campo"],
            "coluna_template": column_name,
            "fonte": "api",
            "schema_api": row["schema_api"],
            "tipo_api": row["tipo_api"],
            "formato_api": row["formato_api"],
            "descricao": row["descricao"],
            "presente_na_api": "TRUE",
            "usar_no_template": "TRUE",
            "status_template": "ativo",
            "ordem_api": str(order),
        }
    operation_info = {
        "path": path,
        "method": method,
        "summary": operation.get("summary", ""),
        "parameters": operation.get("parameters", []),
    }
    return output, operation_info


def strip_prefix(column: str, prefix: str) -> str:
    return column[len(prefix) :] if prefix and column.startswith(prefix) else column


def seed_rows(config: EndpointConfig) -> List[Dict[str, str]]:
    rows = []
    for order, column in enumerate(INITIAL_TEMPLATE_COLUMNS[config.alias], start=1):
        is_operational = column == "endpoint"
        rows.append(
            {
                "endpoint_alias": config.alias,
                "campo": strip_prefix(column, config.column_prefix),
                "coluna_template": column,
                "fonte": "coletor" if is_operational else "template_legado",
                "schema_api": "",
                "tipo_api": "",
                "formato_api": "",
                "descricao": "URL consultada pelo coletor." if is_operational else "",
                "data_inicio_coleta": DEFAULT_BASELINE_DATE,
                "data_atualizacao_template": DEFAULT_BASELINE_DATE,
                "presente_na_api": "FALSE",
                "usar_no_template": "TRUE",
                "status_template": "operacional" if is_operational else "legado",
                "ordem_template": str(order),
                "ordem_api": "",
            }
        )
    return rows


def read_template(path: Path, config: EndpointConfig) -> List[Dict[str, str]]:
    if not path.exists():
        return seed_rows(config)
    with path.open("r", encoding="utf-8-sig", newline="") as file:
        reader = csv.DictReader(file)
        rows = []
        for row in reader:
            normalized = {field: str(row.get(field, "") or "") for field in CSV_FIELDS}
            rows.append(normalized)
        return rows


def row_changed(row: Dict[str, str], api_row: Dict[str, str]) -> bool:
    for key in ("fonte", "schema_api", "tipo_api", "formato_api", "descricao", "presente_na_api", "status_template", "ordem_api"):
        if row.get(key, "") != api_row.get(key, ""):
            return True
    return False


def resolve_description(
    alias: str,
    column: str,
    source: str,
    existing_description: str,
    descriptions: Dict[str, Dict[str, str]],
) -> str:
    if column == "endpoint" or source == "coletor":
        return existing_description or "URL consultada pelo coletor."

    mapped = descriptions.get(alias, {}).get(column, "")
    return mapped or DESCRIPTION_PLACEHOLDER


def next_template_order(rows: Sequence[Dict[str, str]]) -> int:
    orders = []
    for row in rows:
        try:
            orders.append(int(row.get("ordem_template", "") or 0))
        except ValueError:
            continue
    return (max(orders) if orders else 0) + 1


def merge_template(
    config: EndpointConfig,
    existing_rows: List[Dict[str, str]],
    api_rows: Dict[str, Dict[str, str]],
    descriptions: Dict[str, Dict[str, str]],
    today: str,
) -> Tuple[List[Dict[str, str]], List[Dict[str, str]], List[Dict[str, str]]]:
    merged: List[Dict[str, str]] = []
    existing_by_column = {row["coluna_template"]: row for row in existing_rows}
    added: List[Dict[str, str]] = []
    legacy: List[Dict[str, str]] = []

    for row in existing_rows:
        column = row["coluna_template"]
        api_row = api_rows.get(column)
        if api_row:
            updated = {**row, **api_row}
            updated["data_inicio_coleta"] = row.get("data_inicio_coleta") or DEFAULT_BASELINE_DATE
            updated["data_atualizacao_template"] = row.get("data_atualizacao_template") or DEFAULT_BASELINE_DATE
            updated["descricao"] = resolve_description(
                alias=config.alias,
                column=column,
                source=updated.get("fonte", ""),
                existing_description=row.get("descricao", ""),
                descriptions=descriptions,
            )
            if row_changed(row, updated):
                updated["data_atualizacao_template"] = today
            merged.append(updated)
            continue

        updated = dict(row)
        if row.get("fonte") == "coletor" or column == "endpoint":
            updated["fonte"] = "coletor"
            updated["status_template"] = "operacional"
            updated["descricao"] = updated.get("descricao") or "URL consultada pelo coletor."
        else:
            updated["status_template"] = "legado"
            legacy.append(updated)
        updated["presente_na_api"] = "FALSE"
        updated["usar_no_template"] = "TRUE"
        updated["descricao"] = resolve_description(
            alias=config.alias,
            column=column,
            source=updated.get("fonte", ""),
            existing_description=row.get("descricao", ""),
            descriptions=descriptions,
        )
        if row_changed(row, updated):
            updated["data_atualizacao_template"] = today
        merged.append(updated)

    order = next_template_order(merged)
    for column, api_row in sorted(api_rows.items(), key=lambda item: int(item[1].get("ordem_api") or 0)):
        if column in existing_by_column:
            continue
        new_row = dict(api_row)
        new_row["data_inicio_coleta"] = today
        new_row["data_atualizacao_template"] = today
        new_row["ordem_template"] = str(order)
        new_row["descricao"] = resolve_description(
            alias=config.alias,
            column=column,
            source=new_row.get("fonte", ""),
            existing_description="",
            descriptions=descriptions,
        )
        order += 1
        merged.append(new_row)
        added.append(new_row)

    merged.sort(key=lambda row: int(row.get("ordem_template") or 0))
    return merged, added, legacy


def write_template(path: Path, rows: Sequence[Dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=CSV_FIELDS, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in CSV_FIELDS})


def truthy(value: str) -> bool:
    return str(value).strip().upper() in {"TRUE", "T", "1", "S", "SIM", "YES"}


def markdown_escape(value: str) -> str:
    text = str(value or "").replace("\n", " ").replace("\r", " ")
    return text.replace("|", "\\|")


def parameter_summary(operation_info: Dict[str, Any], used_parameters: Sequence[str]) -> str:
    documented = []
    for parameter in operation_info.get("parameters", []):
        if not isinstance(parameter, dict):
            continue
        name = str(parameter.get("name", ""))
        location = str(parameter.get("in", ""))
        required = "obrigatorio" if parameter.get("required") else "opcional"
        marker = "usado" if name in used_parameters else "nao usado"
        documented.append("{} ({}, {}, {})".format(name, location, required, marker))
    return "; ".join(documented)


def load_dicionario(path: Path) -> Dict[str, Dict[str, str]]:
    spec = importlib.util.spec_from_file_location("dicionario_dados", path)
    if spec is None or spec.loader is None:
        return {}
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)  # type: ignore[union-attr]
    result = getattr(module, "DESCRICOES", {})
    if isinstance(result, dict):
        return result
    return {}


def write_readme(path: Path, endpoint_outputs: Sequence[Tuple[EndpointConfig, Dict[str, Any], Sequence[Dict[str, str]]]], descriptions: Dict[str, Dict[str, str]]) -> None:
    lines: List[str] = [
        "# Templates PNCP",
        "",
        "Este diretorio mantem os templates versionados usados pelos coletores do PNCP. "
        "Antes da coleta, o validador consulta a documentacao OpenAPI oficial, atualiza "
        "os CSVs de template e preserva campos legados para manter compatibilidade com "
        "os CSVs historicos e os loaders.",
        "",
        "## Metadados dos endpoints",
        "",
        "| Alias | Modulo | URL Swagger | OpenAPI | Metodo e path | operationId | Parametros |",
        "|---|---|---|---|---|---|---|",
    ]

    for config, operation_info, _rows in endpoint_outputs:
        lines.append(
            "| {} | {} | {} | {} | {} {} | {} | {} |".format(
                markdown_escape(config.alias),
                markdown_escape(config.modulo),
                markdown_escape(config.swagger_ui_url),
                markdown_escape(config.openapi_url),
                markdown_escape(operation_info.get("method", "")),
                markdown_escape(operation_info.get("path", "")),
                markdown_escape(config.operation_id),
                markdown_escape(parameter_summary(operation_info, config.collector_parameters)),
            )
        )

    lines.extend(["", "## Dicionario de dados", ""])

    for config, _operation_info, rows in endpoint_outputs:
        lines.extend(
            [
                "### {}".format(config.alias),
                "",
                "| Nome do campo | Data de inicio da coleta | Status | Descricao curta |",
                "|---|---|---|---|",
            ]
        )
        active_rows = [row for row in rows if truthy(row.get("usar_no_template", "TRUE"))]
        active_rows.sort(key=lambda row: int(row.get("ordem_template") or 0))
        for row in active_rows:
            column = row.get("coluna_template", "")
            descricao = descriptions.get(config.alias, {}).get(column) or ""
            if not descricao:
                descricao = DESCRIPTION_PLACEHOLDER
            lines.append(
                "| {} | {} | {} | {} |".format(
                    markdown_escape(column),
                    markdown_escape(row.get("data_inicio_coleta", "")),
                    markdown_escape(row.get("status_template", "")),
                    markdown_escape(descricao),
                )
            )
        lines.append("")

    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def update_templates(args: argparse.Namespace) -> int:
    templates_dir = Path(args.templates_dir).resolve()
    readme_path = Path(args.readme).resolve()
    descriptions = load_dicionario(Path(args.dicionario))
    endpoint_outputs: List[Tuple[EndpointConfig, Dict[str, Any], Sequence[Dict[str, str]]]] = []
    total_added = 0
    total_legacy = 0

    for config in ENDPOINTS:
        print("---")
        print("Atualizando template: {}".format(config.alias))
        spec = fetch_openapi(config, timeout=args.timeout, attempts=args.attempts, retry_sleep=args.retry_sleep)
        api_rows, operation_info = api_metadata(spec, config)
        template_path = templates_dir / config.template_file
        existing_rows = read_template(template_path, config)
        merged, added, legacy = merge_template(
            config,
            existing_rows,
            api_rows,
            descriptions,
            today=args.today,
        )
        endpoint_outputs.append((config, operation_info, merged))

        if not args.dry_run:
            write_template(template_path, merged)

        for row in added:
            print(
                "ATENÇÃO NOVO CAMPO ENCONTRADO: {campo}, {descricao} "
                "(tipo={tipo}, formato={formato}, schema={schema}, endpoint={endpoint})".format(
                    campo=row["coluna_template"],
                    descricao=row.get("descricao") or "sem descricao",
                    tipo=row.get("tipo_api") or "nao informado",
                    formato=row.get("formato_api") or "nao informado",
                    schema=row.get("schema_api") or "nao informado",
                    endpoint=config.operation_id,
                )
            )

        print(
            "Resumo {}: {} campos no template, {} novos, {} legados.".format(
                config.alias,
                len(merged),
                len(added),
                len(legacy),
            )
        )
        total_added += len(added)
        total_legacy += len(legacy)

    if not args.dry_run:
        write_readme(readme_path, endpoint_outputs, descriptions)

    print("---")
    print("Templates atualizados em: {}".format(templates_dir))
    print("Campos novos: {}".format(total_added))
    print("Campos legados preservados: {}".format(total_legacy))
    if args.dry_run:
        print("Modo dry-run: nenhum arquivo foi alterado.")
    return 0


def main() -> int:
    args = parse_args()
    if args.force_ipv4 and not args.allow_ipv6:
        force_ipv4()
    return update_templates(args)


if __name__ == "__main__":
    sys.exit(main())
