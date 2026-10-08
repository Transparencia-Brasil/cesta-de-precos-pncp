# Análise de unidades compradoras

Levanta, nas coletas do PNCP de 2025-2026, as contratações de um conjunto de CNPJs-alvo (unidades compradoras), com seus itens, medicamentos identificados pelo classificador e resultados homologados.

## Passo a passo

1. **Baixar as coletas** — `src/00-dowload-data.R` baixa do Google Drive os CSVs de cada quinzena (sem `monitoramento` e `erros`) para `tmp/`. Pede login no Drive no navegador.
2. **Filtrar por período** — `docs/analise_unidades_compradoras.ipynb`: defina `PERIODO_DIR` (quinzena em `tmp/`) e `CNPJS_ALVO` (CNPJ completo ou raiz) e rode. Gera em `output/<AAAA-MM-QUINZENA-N>/`:
   - `contratacoes.csv`: contratações dos CNPJs-alvo;
   - `itens.csv`: itens dessas contratações, com `medicamento = True` nos classificados;
   - `medicamentos-resultados.csv`: medicamentos × resultados.

   Repita para cada quinzena.
3. **Consolidar** — `python docs/gera_consolidado.py` junta todos os períodos em `output/consolidado/` (um CSV por tabela + um XLSX com uma aba por tabela).
4. **Relatório** — `python docs/gera_relatorio.py` gera `docs/relatorio-unidades-compradoras.html`, usando a versão mais recente de cada contratação e item.

`tmp/` e `output/` são saídas locais, ignoradas pelo git.
