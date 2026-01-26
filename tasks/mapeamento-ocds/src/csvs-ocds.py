"""Gera CSVs/ZIPs a partir dos JSONs OCDS produzidos pelo mapeamento.

O script busca JSONs em:
    tasks/mapeamento-ocds/output/<ANO>/**/JSON/*.json

Para cada JSON (alias = nome do arquivo sem extensão), ele:
1) Executa o `flattentool` para gerar CSVs.
2) Compacta os CSVs em um ZIP.

Convenções de saída (por mês):
    .../<ANO>/<MES>/CSV/<alias>*
    .../<ANO>/<MES>/ZIP/CSV/<alias>-csv.zip

Observação: o ZIP fica em `ZIP/CSV` por decisão do pipeline (evita misturar
outros ZIPs que não sejam de CSVs).
"""

import argparse
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


def _zip_from_prefix(output_csv_prefix: Path, output_zip: Path) -> None:
    """Compacta em ZIP os CSVs gerados pelo `flattentool`.

    O `flattentool` pode:
    - criar uma pasta `output_name/` com múltiplos CSVs; ou
    - gerar CSVs diretamente no diretório pai, com prefixo `output_name`.
    """
    output_zip.parent.mkdir(parents=True, exist_ok=True)

    with ZipFile(output_zip, "w", compression=ZIP_DEFLATED) as zf:
        # Se o flattentool criar uma pasta (p.ex. .../CSV/<alias>/...), zipa recursivamente
        if output_csv_prefix.exists() and output_csv_prefix.is_dir():
            for p in output_csv_prefix.rglob("*"):
                if p.is_file():
                    # Normaliza o separador para '/' dentro do ZIP (melhor compatibilidade).
                    arc = p.relative_to(output_csv_prefix).as_posix()
                    zf.write(p, arcname=arc)
            return

        # Caso contrário, zipa os CSVs gerados no diretório pai com o prefixo definido
        for p in output_csv_prefix.parent.glob(f"{output_csv_prefix.name}*.csv"):
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
    parser.add_argument("--ano", type=int, default=2025)
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

    total = len(json_paths)
    failures: list[tuple[str, str]] = []

    for i, input_json in enumerate(json_paths, start=1):
        alias = input_json.stem

        # Estrutura esperada: .../<ANO>/<MES>/JSON/<alias>.json
        # `base_output_dir` é a pasta do mês (pai de `JSON/`).
        base_output_dir = input_json.parent.parent
        output_csv_prefix = base_output_dir / "CSV" / alias

        # Requisito do projeto: o ZIP dos CSVs deve ficar em `ZIP/CSV/`.
        output_zip = base_output_dir / "ZIP" / "CSV" / f"{alias}-csv.zip"

        print(f"[{i}/{total}] {alias}")

        try:
            # Garante que a pasta de CSV exista (o flattentool também precisa disso).
            output_csv_prefix.parent.mkdir(parents=True, exist_ok=True)

            # Garante a existência do subdiretório `ZIP/CSV`.
            output_zip.parent.mkdir(parents=True, exist_ok=True)

            if args.skip_existing_zip and output_zip.exists() and output_zip.stat().st_size > 0:
                print(f"  - pulando (ZIP já existe): {output_zip}")
                continue

            flattentool.flatten(
                str(input_json),
                root_list_path="releases",
                main_sheet_name="releases",
                sheet_prefix=f"{alias}-",
                root_id="ocid",
                output_format="csv",
                output_name=str(output_csv_prefix),
            )

            _zip_from_prefix(output_csv_prefix, output_zip)
        except KeyboardInterrupt:
            print("Interrompido pelo usuário.")
            return 130
        except Exception as exc:
            failures.append((alias, repr(exc)))
            print(f"  - ERRO em {alias}: {exc!r}")

    if failures:
        print("\nFalhas:")
        for alias, err in failures:
            print(f"- {alias}: {err}")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())