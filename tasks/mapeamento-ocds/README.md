# RODAR O MAPEAMENTO

```bash
# se estiver usando WSL, rode isso primeiro. Se estiver no bash comum ignore.
export WSLENV=ANO:MES:$WSLENV

# realiza o mapeamento das contratações de um ANO e MES
ANO=2025 MES=1 ./.venv/Scripts/python.exe tasks/mapeamento-ocds/src/mapeamento-pncp-ocds.py
```

```bash
# opcional no WSL para propagar variáveis ao python.exe do Windows
export WSLENV=ANO:MES:$WSLENV

# cria a pasta de logs, se não existir
mkdir -p tasks/mapeamento-ocds/output/logs

# roda o mapeamento para os meses de 1 a 9 de 2025, salvando o log de cada mês em um arquivo separado
for MES in {1..9}; do
  MES_PAD=$(printf "%02d" "$MES")
  LOG="tasks/mapeamento-ocds/output/logs/mapeamento-2025-${MES_PAD}.log"
  {
    echo "==== Início ANO=2025 MES=${MES} $(date -Iseconds) ===="
    ANO=2025 MES=$MES ./.venv/Scripts/python.exe tasks/mapeamento-ocds/src/mapeamento-pncp-ocds.py
    echo "==== Fim MES=${MES} $(date -Iseconds) ===="
    echo
  } 2>&1 | tee -a "$LOG"
done
```
