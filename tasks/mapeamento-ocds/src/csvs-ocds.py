"""
Gera CSVs/ZIPs a partir dos JSONs OCDS produzidos pelo mapeamento.

Uso:
    python csvs-ocds.py --ano <ANO> [--mes <MES>] [--aliases ...] [--limit N] [--skip-existing-zip]

Parâmetros obrigatórios:
    --ano           Ano dos dados a processar (ex.: 2026).

Parâmetros opcionais:
    --mes           Mês específico (1-12). Se omitido, processa todos os meses do ano.
    --base-dir      Raiz do repositório (detectado automaticamente por padrão).
    --aliases       Lista de aliases específicos para processar.
    --limit         Limita a N JSONs processados (útil para smoke test).
    --skip-existing-zip  Pula grupos cujo ZIP já existe.

O script busca JSONs em:
    tasks/mapeamento-ocds/output/<ANO>/**/JSON/*.json          (sem --mes)
    tasks/mapeamento-ocds/output/<ANO>/<MES>/**/JSON/*.json    (com --mes)

Os JSONs seguem o padrão de nome `{uf}-{mes}-{ano}[-{parte}].json`.
Aliases com a mesma chave `{uf}-{mes}-{ano}` são agrupados e seus CSVs
compactados num único ZIP.

Para cada grupo (group_key = `{uf}-{mes}-{ano}`):
1) Executa o `flattentool` para cada JSON do grupo, gerando CSVs.
2) Compacta todos os CSVs do grupo em um único ZIP.

Convenções de saída (por mês):
    .../<ANO>/<MES>/CSV/<alias>*        (CSVs individuais por alias)
    .../<ANO>/<MES>/ZIP/CSV/<group_key>-csv.zip  (ZIP único por grupo)

Observação: o ZIP fica em `ZIP/CSV` por decisão do pipeline (evita misturar
outros ZIPs que não sejam de CSVs).
"""

import argparse
import re
from collections import defaultdict
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

import flattentool


def _repo_root() -> Path:
    """Detecta a raiz do repositório a partir do caminho deste arquivo."""
    # tasks/mapeamento-ocds/src/csvs-ocds.py -> repo root é 3 níveis acima
    return Path(__file__).resolve().parents[3]


def _discover_jsons(output_root: Path) -> list[Path]:
    """Lista os JSONs OCDS sob `output_root` (recursivo)."""
    return sorted(p for p in output_root.glob("**/JSON/*.json") if p.is_file())


# Padrão: {uf}-{mes}-{ano} seguido opcionalmente de -{parte}
_ALIAS_RE = re.compile(r"^([a-z]{2}-\d+-\d{4})(?:-\d+)?$")


def _group_key(alias: str) -> str:
    """Extrai a chave de agrupamento `{uf}-{mes}-{ano}` de um alias.

    Exemplos:
        'sp-1-2025-1' -> 'sp-1-2025'
        'sp-1-2025-2' -> 'sp-1-2025'
        'ac-1-2025'   -> 'ac-1-2025'
    """
    m = _ALIAS_RE.match(alias)
    if m:
        return m.group(1)
    # Fallback: o próprio alias (sem parte) já é a chave.
    return alias


def _zip_from_prefixes(csv_prefixes: list[Path], output_zip: Path) -> None:
    """Compacta em um único ZIP os CSVs gerados por múltiplos prefixos.

    Para cada prefixo o `flattentool` pode:
    - criar uma pasta `output_name/` com múltiplos CSVs; ou
    - gerar CSVs diretamente no diretório pai, com prefixo `output_name`.
    """
    output_zip.parent.mkdir(parents=True, exist_ok=True)

    with ZipFile(output_zip, "w", compression=ZIP_DEFLATED) as zf:
        for prefix in csv_prefixes:
            # Se o flattentool criar uma pasta (p.ex. .../CSV/<alias>/...), zipa recursivamente
            if prefix.exists() and prefix.is_dir():
                for p in prefix.rglob("*"):
                    if p.is_file():
                        arc = p.relative_to(prefix.parent).as_posix()
                        zf.write(p, arcname=arc)
                continue

            # Caso contrário, zipa os CSVs gerados no diretório pai com o prefixo definido
            for p in prefix.parent.glob(f"{prefix.name}*.csv"):
                if p.is_file():
                    zf.write(p, arcname=p.name)


def main() -> int:
    """Ponto de entrada do CLI.

    Exit codes:
    - 0: sucesso (inclusive quando não há JSONs)
    - 1: ao menos um alias falhou
    - 2: diretório-base não encontrado
    - 130: interrompido pelo usuário (Ctrl+C)
    """
    parser = argparse.ArgumentParser(
        description=(
            "Gera CSVs (via flattentool) e ZIPs a partir dos JSONs OCDS gerados em tasks/mapeamento-ocds/output/<ANO>/**/JSON/*.json"
        )
    )
    parser.add_argument(
        "--ano",
        type=int,
        required=True,
        help="Ano para processar."
    )
    parser.add_argument(
        "--mes",
        type=int,
        default=None,
        help="Mês específico para processar (1-12). Se omitido, processa todos os meses do ano.",
    )
    parser.add_argument(
        "--base-dir",
        type=Path,
        default=_repo_root(),
        help="Raiz do repositório. Por padrão, detectado a partir do caminho do script.",
    )
    parser.add_argument(
        "--aliases",
        nargs="*",
        default=None,
        help="Processa apenas estes aliases (nomes dos arquivos .json sem extensão).",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Processa no máximo N JSONs (útil para smoke test).",
    )
    parser.add_argument(
        "--skip-existing-zip",
        action="store_true",
        help="Se o ZIP de saída já existir, pula o alias (evita reprocessar).",
    )
    args = parser.parse_args()

    # Diretório onde o mapeamento OCDS escreve os JSONs (organizados por ano/mês).
    output_root = args.base_dir / "tasks" / "mapeamento-ocds" / "output" / str(args.ano)
    if args.mes is not None:
        output_root = output_root / str(args.mes)
    if not output_root.exists():
        print(f"ERRO: diretório não encontrado: {output_root}")
        return 2

    # Descobre todos os JSONs disponíveis; pode filtrar por alias e/ou limitar para testes.
    json_paths = _discover_jsons(output_root)
    if args.aliases:
        aliases_set = set(args.aliases)
        json_paths = [p for p in json_paths if p.stem in aliases_set]

    if args.limit is not None:
        json_paths = json_paths[: args.limit]

    if not json_paths:
        print(f"Nenhum JSON encontrado em {output_root} (padrão: **/JSON/*.json)")
        return 0

    # Agrupa JSONs pela chave {uf}-{mes}-{ano}.
    # Aliases como sp-1-2025-1 e sp-1-2025-2 ficam no mesmo grupo "sp-1-2025".
    groups: dict[str, list[Path]] = defaultdict(list)
    for p in json_paths:
        groups[_group_key(p.stem)].append(p)

    total_groups = len(groups)
    total_jsons = len(json_paths)
    failures: list[tuple[str, str]] = []

    print(f"{total_jsons} JSONs em {total_groups} grupos\n")

    for g_idx, (gkey, group_jsons) in enumerate(sorted(groups.items()), start=1):
        # Todos os JSONs de um grupo estão no mesmo mês → mesmo base_output_dir.
        base_output_dir = group_jsons[0].parent.parent
        output_zip = base_output_dir / "ZIP" / "CSV" / f"{gkey}-csv.zip"

        print(f"[grupo {g_idx}/{total_groups}] {gkey} ({len(group_jsons)} arquivo(s))")

        if args.skip_existing_zip and output_zip.exists() and output_zip.stat().st_size > 0:
            print(f"  - pulando (ZIP já existe): {output_zip}")
            continue

        csv_prefixes: list[Path] = []
        group_failed = False

        for input_json in group_jsons:
            alias = input_json.stem
            output_csv_prefix = base_output_dir / "CSV" / alias

            print(f"  flatten: {alias}")

            try:
                # Garante que a pasta de CSV exista (o flattentool também precisa disso).
                output_csv_prefix.parent.mkdir(parents=True, exist_ok=True)

                flattentool.flatten(
                    str(input_json),
                    root_list_path="releases",
                    main_sheet_name="releases",
                    sheet_prefix=f"{alias}-",
                    root_id="ocid",
                    output_format="csv",
                    output_name=str(output_csv_prefix),
                )

                csv_prefixes.append(output_csv_prefix)
            except KeyboardInterrupt:
                print("Interrompido pelo usuário.")
                return 130
            except Exception as exc:
                group_failed = True
                failures.append((alias, repr(exc)))
                print(f"    ERRO em {alias}: {exc!r}")

        # Gera o ZIP unificado do grupo (mesmo que algum alias tenha falhado,
        # zipa os que deram certo).
        if csv_prefixes:
            try:
                output_zip.parent.mkdir(parents=True, exist_ok=True)
                _zip_from_prefixes(csv_prefixes, output_zip)
                print(f"  zip: {output_zip.name}")
            except KeyboardInterrupt:
                print("Interrompido pelo usuário.")
                return 130
            except Exception as exc:
                failures.append((gkey, repr(exc)))
                print(f"    ERRO ao criar ZIP {gkey}: {exc!r}")

    if failures:
        print("\nFalhas:")
        for name, err in failures:
            print(f"- {name}: {err}")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())