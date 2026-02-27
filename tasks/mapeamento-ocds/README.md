# Mapeamento PNCP → OCDS

Esta task converte dados de contratações do PNCP para o padrão [OCDS](https://standard.open-contracting.org/) e, em seguida, gera CSVs/ZIPs a partir dos JSONs produzidos.

## Estrutura de diretórios

```
tasks/mapeamento-ocds/
├── src/
│   ├── mapeamento-pncp-ocds.py       # Script Python: mapeamento PNCP → JSON OCDS
│   ├── csvs-ocds.py                   # Script Python: JSON OCDS → CSVs/ZIPs
│   ├── run-mapeamento-pncp-ocds.sh    # Runner interativo do mapeamento
│   └── run-csvs-ocds.sh              # Runner interativo da geração de CSVs
├── output/
│   ├── LOGS/                          # Logs de execução
│   └── <ANO>/<MES>/
│       ├── JSON/                      # JSONs OCDS gerados pelo mapeamento
│       ├── CSV/                       # CSVs gerados pelo flattentool
│       └── ZIP/CSV/                   # ZIPs com os CSVs agrupados
└── README.md
```

## Pré-requisitos

- **Python** com ambiente virtual (`.venv`) configurado na raiz do repositório.
- Pacotes Python: `sentence-transformers`, `pandas`, `flattentool`, entre outros (ver `requirements.txt`).
- **WSL** (se estiver no Windows): os scripts `.sh` devem ser executados no terminal WSL.

## Etapa 1 — Mapeamento PNCP → JSON OCDS

Converte os dados de contratações do PNCP em JSONs no formato OCDS.

### Via script interativo (recomendado)

O script solicita ANO e MES interativamente e grava o log automaticamente:

```bash
bash tasks/mapeamento-ocds/src/run-mapeamento-pncp-ocds.sh
```

### Via linha de comando direta

```bash
# Se estiver usando WSL, exporte as variáveis primeiro:
export WSLENV=ANO:MES:$WSLENV

# Execução para um mês específico (ex.: janeiro de 2026)
ANO=2026 MES=1; MES_PAD=$(printf "%02d" "$MES"); \
  mkdir -p tasks/mapeamento-ocds/output/LOGS && \
  ANO=$ANO MES=$MES ./.venv/Scripts/python.exe tasks/mapeamento-ocds/src/mapeamento-pncp-ocds.py \
  2>&1 | tee -a "tasks/mapeamento-ocds/output/LOGS/mapeamento-${ANO}-${MES_PAD}.log"
```

### Execução em lote (vários meses)

```bash
export WSLENV=ANO:MES:$WSLENV

for MES in {1..9}; do
  MES_PAD=$(printf "%02d" "$MES")
  LOG="tasks/mapeamento-ocds/output/LOGS/mapeamento-2025-${MES_PAD}.log"
  {
    echo "==== Início ANO=2025 MES=${MES} $(date -Iseconds) ===="
    ANO=2025 MES=$MES ./.venv/Scripts/python.exe tasks/mapeamento-ocds/src/mapeamento-pncp-ocds.py
    echo "==== Fim MES=${MES} $(date -Iseconds) ===="
    echo
  } 2>&1 | tee -a "$LOG"
done
```

## Etapa 2 — Geração de CSVs/ZIPs a partir dos JSONs OCDS

Após o mapeamento, este passo usa o `flattentool` para achatar os JSONs em CSVs e compactá-los em ZIPs.

### Via script interativo (recomendado)

O script solicita ANO e MES interativamente:

```bash
bash tasks/mapeamento-ocds/src/run-csvs-ocds.sh
```

### Via linha de comando direta

```bash
# Janeiro de 2026
./.venv/Scripts/python.exe tasks/mapeamento-ocds/src/csvs-ocds.py --ano 2026 --mes 1

# Todos os meses de 2025
./.venv/Scripts/python.exe tasks/mapeamento-ocds/src/csvs-ocds.py --ano 2025

# Smoke test (limitar a 3 JSONs)
./.venv/Scripts/python.exe tasks/mapeamento-ocds/src/csvs-ocds.py --ano 2026 --mes 1 --limit 3

# Pular grupos já processados
./.venv/Scripts/python.exe tasks/mapeamento-ocds/src/csvs-ocds.py --ano 2026 --mes 1 --skip-existing-zip
```

### Parâmetros do `csvs-ocds.py`

| Parâmetro             | Obrigatório | Descrição                                               |
| --------------------- | ----------- | ------------------------------------------------------- |
| `--ano`               | Sim         | Ano dos dados a processar.                              |
| `--mes`               | Não         | Mês (1-12). Se omitido, processa todos os meses do ano. |
| `--base-dir`          | Não         | Raiz do repositório (detectado automaticamente).        |
| `--aliases`           | Não         | Lista de aliases específicos para processar.            |
| `--limit`             | Não         | Limita a N JSONs (útil para testes).                    |
| `--skip-existing-zip` | Não         | Pula grupos cujo ZIP já existe.                         |
