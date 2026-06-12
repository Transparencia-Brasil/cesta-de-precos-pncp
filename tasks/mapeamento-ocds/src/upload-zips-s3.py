"""
Valida e envia ZIPs OCDS locais para um bucket AWS S3.

Uso:
    python upload-zips-s3.py --ano <ANO> [--mes <MES>] [--overwrite]

O script busca arquivos em:
    tasks/mapeamento-ocds/output/<ANO>/<MES>/ZIP/CSV/*.zip
    tasks/mapeamento-ocds/output/<ANO>/<MES>/ZIP/JSON/*.zip

Os ZIPs devem seguir o padrao:
    {uf}-{mes}-{ano}-{formato}.zip

Uploads sao feitos sem prefixo/pasta no S3, usando apenas o nome do arquivo
como key do objeto. Por padrao, objetos existentes no S3 sao pulados. Use
--overwrite para substituir objetos existentes.
"""

from __future__ import annotations

import argparse
import logging
import os
import re
from dataclasses import dataclass
from pathlib import Path

try:
    import boto3
    from botocore.exceptions import ClientError
except ImportError:  # pragma: no cover - mensagem de erro amigavel no runtime
    boto3 = None
    ClientError = Exception


DEFAULT_BUCKET = "medicamentos-transparentes-dados-abertos"
ZIP_NAME_RE = re.compile(r"^(?P<uf>[a-z]{2})-(?P<mes>\d{1,2})-(?P<ano>\d{4})-(?P<formato>csv|json)\.zip$", re.IGNORECASE)


@dataclass(frozen=True)
class ZipCandidate:
    path: Path
    key: str
    ano: int
    mes: int
    formato: str


@dataclass
class TransferSummary:
    found: int = 0
    uploaded: int = 0
    overwritten: int = 0
    skipped: int = 0
    invalid: int = 0
    failed: int = 0


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _load_env_file(env_file: Path) -> None:
    if not env_file.exists():
        return

    for raw_line in env_file.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        name, value = line.split("=", 1)
        name = name.strip()
        value = value.strip().strip('"').strip("'")
        if name and name not in os.environ:
            os.environ[name] = value


def _month_dirs(output_root: Path, ano: int, mes: int | None) -> list[Path]:
    year_dir = output_root / str(ano)
    if mes is not None:
        return [year_dir / str(mes)]

    if not year_dir.exists():
        return [year_dir]

    return sorted(p for p in year_dir.iterdir() if p.is_dir() and p.name.isdigit())


def _validate_zip_path(path: Path, expected_ano: int, expected_mes: int, expected_formato: str) -> ZipCandidate | None:
    match = ZIP_NAME_RE.match(path.name)
    if not match:
        logging.error("Nome de ZIP invalido: %s", path)
        return None

    file_ano = int(match.group("ano"))
    file_mes = int(match.group("mes"))
    file_formato = match.group("formato").lower()

    if file_ano != expected_ano or file_mes != expected_mes:
        logging.error(
            "ZIP fora do periodo esperado: %s (arquivo=%s/%s, pasta=%s/%s)",
            path,
            file_ano,
            file_mes,
            expected_ano,
            expected_mes,
        )
        return None

    if file_formato != expected_formato:
        logging.error("ZIP no diretorio errado: %s (esperado formato=%s)", path, expected_formato)
        return None

    return ZipCandidate(
        path=path,
        key=path.name,
        ano=file_ano,
        mes=file_mes,
        formato=file_formato,
    )


def _discover_zips(output_root: Path, ano: int, mes: int | None) -> tuple[list[ZipCandidate], int]:
    candidates: list[ZipCandidate] = []
    invalid = 0

    for month_dir in _month_dirs(output_root, ano, mes):
        if not month_dir.exists():
            logging.error("Diretorio de periodo nao encontrado: %s", month_dir)
            invalid += 1
            continue

        if not month_dir.name.isdigit():
            logging.error("Diretorio de mes invalido: %s", month_dir)
            invalid += 1
            continue

        expected_mes = int(month_dir.name)
        if expected_mes < 1 or expected_mes > 12:
            logging.error("Mes fora do intervalo 1-12: %s", month_dir)
            invalid += 1
            continue

        zip_dir = month_dir / "ZIP"
        for formato_dir, expected_formato in ((zip_dir / "CSV", "csv"), (zip_dir / "JSON", "json")):
            if not formato_dir.exists() or not formato_dir.is_dir():
                logging.error("Diretorio obrigatorio nao encontrado: %s", formato_dir)
                invalid += 1
                continue

            zip_paths = sorted(p for p in formato_dir.glob("*.zip") if p.is_file())
            if not zip_paths:
                logging.error("Diretorio sem ZIPs: %s", formato_dir)
                invalid += 1
                continue

            for zip_path in zip_paths:
                candidate = _validate_zip_path(zip_path, ano, expected_mes, expected_formato)
                if candidate is None:
                    invalid += 1
                    continue
                candidates.append(candidate)

    return candidates, invalid


def _create_s3_client():
    if boto3 is None:
        raise RuntimeError("Dependencia ausente: instale boto3 no ambiente Python do projeto.")

    profile = os.getenv("AWS_PROFILE")
    region = os.getenv("AWS_REGION") or os.getenv("AWS_DEFAULT_REGION")
    session_kwargs: dict[str, str] = {}
    if profile:
        session_kwargs["profile_name"] = profile
    if region:
        session_kwargs["region_name"] = region

    session = boto3.Session(**session_kwargs)
    return session.client("s3")


def _object_exists(s3_client, bucket: str, key: str) -> bool:
    try:
        s3_client.head_object(Bucket=bucket, Key=key)
        return True
    except ClientError as exc:
        error_code = exc.response.get("Error", {}).get("Code")
        if error_code in {"404", "NoSuchKey", "NotFound"}:
            return False
        raise


def _upload_zips(s3_client, bucket: str, candidates: list[ZipCandidate], overwrite: bool = False) -> TransferSummary:
    summary = TransferSummary(found=len(candidates))

    for candidate in candidates:
        try:
            object_exists = _object_exists(s3_client, bucket, candidate.key)
            if object_exists and not overwrite:
                summary.skipped += 1
                logging.warning("SKIP objeto ja existe: s3://%s/%s", bucket, candidate.key)
                continue

            s3_client.upload_file(str(candidate.path), bucket, candidate.key)
            if object_exists:
                summary.overwritten += 1
                logging.warning("OVERWRITE OK: %s -> s3://%s/%s", candidate.path, bucket, candidate.key)
            else:
                summary.uploaded += 1
                logging.info("UPLOAD OK: %s -> s3://%s/%s", candidate.path, bucket, candidate.key)
        except Exception as exc:
            summary.failed += 1
            logging.error("UPLOAD ERRO: %s -> s3://%s/%s (%r)", candidate.path, bucket, candidate.key, exc)

    return summary


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Envia ZIPs OCDS gerados localmente para um bucket AWS S3.")
    parser.add_argument("--ano", type=int, required=True, help="Ano dos ZIPs a transferir.")
    parser.add_argument("--mes", type=int, default=None, help="Mes especifico (1-12). Se omitido, processa todos os meses do ano.")
    parser.add_argument(
        "--base-dir",
        type=Path,
        default=_repo_root(),
        help="Raiz do repositorio. Por padrao, detectado a partir do caminho do script.",
    )
    parser.add_argument(
        "--bucket",
        default=None,
        help=f"Bucket S3 de destino. Default: env AWS_S3_BUCKET ou {DEFAULT_BUCKET}.",
    )
    parser.add_argument(
        "--env-file",
        type=Path,
        default=None,
        help="Arquivo .env a carregar antes de criar o cliente AWS. Default: <base-dir>/.env.",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Sobrescreve objetos existentes no bucket S3. Por padrao, objetos existentes sao pulados.",
    )
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

    if args.ano < 2022:
        logging.error("ANO deve ser maior ou igual a 2022.")
        return 2
    if args.mes is not None and (args.mes < 1 or args.mes > 12):
        logging.error("MES deve estar entre 1 e 12.")
        return 2

    base_dir = args.base_dir.resolve()
    env_file = args.env_file.resolve() if args.env_file else base_dir / ".env"
    _load_env_file(env_file)

    output_root = Path(os.getenv("MAPEAMENTO_OCDS_OUTPUT_DIR", base_dir / "tasks" / "mapeamento-ocds" / "output"))
    if not output_root.is_absolute():
        output_root = base_dir / output_root
    output_root = output_root.resolve()

    bucket = args.bucket or os.getenv("AWS_S3_BUCKET") or DEFAULT_BUCKET

    logging.info("Raiz de output: %s", output_root)
    logging.info("Bucket S3: %s", bucket)
    logging.info("Overwrite remoto: %s", "ativado" if args.overwrite else "desativado")

    candidates, invalid = _discover_zips(output_root, args.ano, args.mes)
    if invalid:
        logging.error("Transferencia abortada: %s problema(s) de validacao encontrado(s).", invalid)
        return 1
    if not candidates:
        logging.error("Nenhum ZIP valido encontrado para transferencia.")
        return 1

    try:
        s3_client = _create_s3_client()
    except Exception as exc:
        logging.error("Erro ao criar cliente S3: %r", exc)
        return 1

    summary = _upload_zips(s3_client, bucket, candidates, overwrite=args.overwrite)
    logging.info(
        "Resumo: encontrados=%s enviados=%s sobrescritos=%s pulados=%s invalidos=%s falhas=%s",
        summary.found,
        summary.uploaded,
        summary.overwritten,
        summary.skipped,
        invalid,
        summary.failed,
    )

    if summary.failed:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
