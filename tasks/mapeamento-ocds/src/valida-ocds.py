"""
Valida os JSONs OCDS produzidos pelo mapeamento com o `libcoveocds`, a mesma
biblioteca usada pelo OCDS Data Review Tool (https://review.standard.open-contracting.org/).

Uso:
    python valida-ocds.py --ano <ANO> --mes <MES> [--base-dir DIR] [--input-dir DIR]

Parâmetros obrigatórios:
    --ano           Ano dos dados (ex.: 2026).
    --mes           Mês dos dados (1-12).

Parâmetros opcionais:
    --base-dir      Raiz do repositório (detectado automaticamente por padrão).
    --input-dir     Diretório com os JSONs a validar. Padrão:
                    tasks/mapeamento-ocds/output/<ANO>/<MES>/JSON

Para cada JSON, o relatório completo do `libcoveocds` é gravado em
`<input-dir>/../VALIDACAO/<arquivo>.json`, e um resumo é impresso no stdout
(que o orquestrador grava em output/LOGS/valida-ocds-<ANO>-<MM>.log).

O que bloqueia (exit code 1):
    - erros de schema (OCDS 1.1 + extensões declaradas no pacote);
    - valores fora de codelists fechadas.

O que só é registrado:
    - campos adicionais (fora do schema e das extensões);
    - valores fora de codelists abertas (ex.: formas farmacêuticas em português);
    - checagens adicionais do libcoveocds.

Exit codes:
    - 0: todos os arquivos sem erros bloqueantes
    - 1: ao menos um arquivo com erro bloqueante (ou falha ao validar)
    - 2: diretório de entrada não encontrado ou sem JSONs
"""

import argparse
import json
import shutil
import sys
import tempfile
import time
from collections import Counter, defaultdict
from pathlib import Path

from libcoveocds.api import ocds_json_output


MAX_EXEMPLOS = 5


def _repo_root() -> Path:
    """Detecta a raiz do repositório a partir do caminho deste arquivo."""
    # tasks/mapeamento-ocds/src/valida-ocds.py -> repo root é 3 níveis acima
    return Path(__file__).resolve().parents[3]


def _valida_arquivo(caminho: Path) -> dict:
    """Roda o libcoveocds sobre um JSON e devolve o relatório (dict)."""
    temporario = tempfile.mkdtemp(prefix="valida-ocds-")
    try:
        return ocds_json_output(temporario, str(caminho))
    finally:
        shutil.rmtree(temporario, ignore_errors=True)


def _chave_erro(erro) -> str:
    """Resume um erro de validação para agrupamento (sem o valor que o causou)."""
    if isinstance(erro, dict):
        partes = [str(erro.get(k)) for k in ("type", "field", "description", "message") if erro.get(k)]
        return " | ".join(partes) or json.dumps(erro, ensure_ascii=False, default=str)[:300]
    return str(erro)[:300]


def _exemplo_erro(erro) -> str:
    if isinstance(erro, dict):
        exemplo = {k: erro[k] for k in ("path", "value", "values") if k in erro}
        return json.dumps(exemplo or erro, ensure_ascii=False, default=str)[:300]
    return str(erro)[:300]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Valida os JSONs OCDS de um mês com o libcoveocds (motor do OCDS Data Review Tool)."
    )
    parser.add_argument("--ano", type=int, required=True, help="Ano dos dados.")
    parser.add_argument("--mes", type=int, required=True, help="Mês dos dados (1-12).")
    parser.add_argument(
        "--base-dir",
        type=Path,
        default=_repo_root(),
        help="Raiz do repositório. Por padrão, detectado a partir do caminho do script.",
    )
    parser.add_argument(
        "--input-dir",
        type=Path,
        default=None,
        help="Diretório com os JSONs. Padrão: tasks/mapeamento-ocds/output/<ANO>/<MES>/JSON",
    )
    args = parser.parse_args()

    input_dir = args.input_dir or (
        args.base_dir / "tasks" / "mapeamento-ocds" / "output" / str(args.ano) / str(args.mes) / "JSON"
    )
    if not input_dir.is_dir():
        print(f"ERRO: diretório não encontrado: {input_dir}")
        return 2

    jsons = sorted(p for p in input_dir.glob("*.json") if p.is_file())
    if not jsons:
        print(f"ERRO: nenhum JSON encontrado em {input_dir}")
        return 2

    relatorio_dir = input_dir.parent / "VALIDACAO"
    relatorio_dir.mkdir(parents=True, exist_ok=True)

    print(f"Validando {len(jsons)} JSON(s) de {input_dir}")
    print(f"Relatórios completos em {relatorio_dir}")
    print("")

    erros_schema = defaultdict(lambda: {"total": 0, "arquivos": set(), "exemplos": []})
    codelists_fechadas = defaultdict(set)
    codelists_abertas = defaultdict(set)
    campos_adicionais = Counter()
    checagens_adicionais = Counter()
    extensoes_invalidas = set()
    arquivos_com_erro = []

    for caminho in jsons:
        inicio = time.time()
        try:
            resultado = _valida_arquivo(caminho)
        except Exception as exc:  # falha do validador também bloqueia
            print(f"  {caminho.name}: FALHA AO VALIDAR ({type(exc).__name__}: {exc})")
            arquivos_com_erro.append(caminho.name)
            continue

        (relatorio_dir / caminho.name).write_text(
            json.dumps(resultado, ensure_ascii=False, indent=2, default=str), encoding="utf-8"
        )

        n_erros = 0
        for erro in resultado.get("validation_errors") or []:
            # no contexto "api", cada erro pode vir como [descrição_json, [ocorrências]]
            if isinstance(erro, (list, tuple)) and len(erro) == 2:
                descricao, ocorrencias = erro
                try:
                    descricao = json.loads(descricao)
                except (TypeError, ValueError):
                    pass
                ocorrencias = ocorrencias if isinstance(ocorrencias, list) else [ocorrencias]
            else:
                descricao, ocorrencias = erro, [erro]
            grupo = erros_schema[_chave_erro(descricao)]
            grupo["total"] += len(ocorrencias)
            grupo["arquivos"].add(caminho.name)
            for ocorrencia in ocorrencias:
                if len(grupo["exemplos"]) < MAX_EXEMPLOS:
                    grupo["exemplos"].append(f"{caminho.name}: {_exemplo_erro(ocorrencia)}")
            n_erros += len(ocorrencias)

        n_fechadas = 0
        for chave, info in (resultado.get("additional_closed_codelist_values") or {}).items():
            valores = info.get("values", []) if isinstance(info, dict) else []
            codelists_fechadas[chave].update(map(str, valores))
            n_fechadas += len(valores)

        for chave, info in (resultado.get("additional_open_codelist_values") or {}).items():
            valores = info.get("values", []) if isinstance(info, dict) else []
            codelists_abertas[chave].update(map(str, valores))

        for campo in resultado.get("additional_fields") or []:
            campos_adicionais[f"{campo.get('path')}/{campo.get('field')}"] += int(campo.get("usage_count") or 1)

        for tipo, ocorrencias in (resultado.get("additional_checks") or {}).items():
            checagens_adicionais[tipo] += len(ocorrencias) if hasattr(ocorrencias, "__len__") else 1

        for extensao in (resultado.get("extensions") or {}).get("invalid_extensions") or []:
            extensoes_invalidas.add(str(extensao))

        bloqueante = n_erros or n_fechadas
        if bloqueante:
            arquivos_com_erro.append(caminho.name)

        print(
            f"  {caminho.name}: {resultado.get('count', '?')} releases, "
            f"{n_erros} erro(s) de schema, {n_fechadas} valor(es) fora de codelist fechada "
            f"[{'ERRO' if bloqueante else 'ok'}] ({time.time() - inicio:.0f}s)"
        )

    print("")
    print("== Erros de schema (bloqueiam)")
    if not erros_schema:
        print("  nenhum")
    for chave, grupo in sorted(erros_schema.items(), key=lambda kv: -kv[1]["total"]):
        print(f"  {grupo['total']}x em {len(grupo['arquivos'])} arquivo(s): {chave}")
        for exemplo in grupo["exemplos"]:
            print(f"      ex.: {exemplo}")

    print("== Valores fora de codelists fechadas (bloqueiam)")
    if not codelists_fechadas:
        print("  nenhum")
    for chave, valores in sorted(codelists_fechadas.items()):
        print(f"  {chave}: {', '.join(sorted(valores))}")

    print("== Extensões que não puderam ser carregadas")
    print("  nenhuma" if not extensoes_invalidas else "\n".join(f"  {e}" for e in sorted(extensoes_invalidas)))

    print("== Campos adicionais (só registro)")
    if not campos_adicionais:
        print("  nenhum")
    for campo, total in campos_adicionais.most_common():
        print(f"  {total}x {campo}")

    print("== Valores fora de codelists abertas (só registro)")
    if not codelists_abertas:
        print("  nenhum")
    for chave, valores in sorted(codelists_abertas.items()):
        amostra = sorted(valores)
        sufixo = f" ... (+{len(amostra) - 10})" if len(amostra) > 10 else ""
        print(f"  {chave}: {len(amostra)} valor(es): {', '.join(amostra[:10])}{sufixo}")

    print("== Checagens adicionais (só registro)")
    if not checagens_adicionais:
        print("  nenhuma")
    for tipo, total in checagens_adicionais.most_common():
        print(f"  {total}x {tipo}")

    print("")
    if arquivos_com_erro or extensoes_invalidas:
        print(f"RESULTADO: FALHOU ({len(arquivos_com_erro)} arquivo(s) com erro bloqueante: {', '.join(arquivos_com_erro)})")
        return 1

    print(f"RESULTADO: OK ({len(jsons)} arquivo(s) sem erros bloqueantes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
