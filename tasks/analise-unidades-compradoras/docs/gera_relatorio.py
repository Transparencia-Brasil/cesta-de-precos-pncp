import html
from pathlib import Path

import pandas as pd

# gera o relatório em HTML a partir das saídas do notebook em ../output
TASK_DIR = Path(__file__).resolve().parents[1]
O = TASK_DIR / "output"
SAIDA = Path(__file__).with_name("relatorio-unidades-compradoras.html")

PERIODOS = sorted(d.name for d in O.iterdir())


def junta(nome):
    return pd.concat(
        [pd.read_csv(O / p / nome, dtype=str).assign(periodo=p) for p in PERIODOS if (O / p / nome).stat().st_size > 5],
        ignore_index=True,
    )


c_raw, i_raw, r = junta("contratacoes.csv"), junta("itens.csv"), junta("medicamentos-resultados.csv")
c = c_raw.sort_values(["data.dataAtualizacaoGlobal", "periodo"]).drop_duplicates("data.numeroControlePNCP", keep="last")
i = i_raw.sort_values(["dataAtualizacao", "periodo"]).drop_duplicates(["numeroControlePNCP", "numeroItem"], keep="last")
for col in ["data.valorTotalEstimado", "data.valorTotalHomologado"]:
    c[col] = pd.to_numeric(c[col])
c["seq"] = c["data.sequencialCompra"].astype(int)
c = c.sort_values(["data.anoCompra", "seq"])

ANOMALIA = "25089137000195-1-000007/2024"
TRUNCADAS = {  # quantidade real consultada em /itens/quantidade na API do PNCP (05/10/2026)
    "2024/4": 37, "2025/9": 42, "2025/10": 12, "2026/12": 32, "2025/13": 12, "2026/13": 32, "2026/14": 12,
    "2026/15": 12, "2025/16": 42, "2024/18": 14, "2024/20": 70, "2025/23": 31, "2025/24": 31,
}
n_itens = i.groupby("numeroControlePNCP").size()
reais_truncadas = sum(TRUNCADAS.values())
itens_reais = len(i) - 10 * len(TRUNCADAS) + reais_truncadas

periodos_por_contr = c_raw.groupby("data.numeroControlePNCP").periodo.nunique()
sig = set(i[i.orcamentoSigiloso.str.upper() == "TRUE"].numeroControlePNCP)


def brl(v, casas=2):
    if pd.isna(v):
        return "—"
    s = f"{v:,.{casas}f}".replace(",", "X").replace(".", ",").replace("X", ".")
    return "R$ " + s


def mi(v):
    return brl(v / 1e6, 1) + " mi"


def e(s):
    return html.escape("" if pd.isna(s) else str(s))


def num(n):
    return f"{n:,}".replace(",", ".")


def chave_curta(k):
    cnpj, resto = k.split("-1-")
    seq, ano = resto.split("/")
    return f"{int(seq)}/{ano}", f"https://pncp.gov.br/app/editais/{cnpj}/{ano}/{int(seq)}"


# ---------- tabelas agregadas ----------
mod = (
    c.groupby("data.modalidadeNome")
    .agg(n=("data.numeroControlePNCP", "size"), est=("data.valorTotalEstimado", "sum"),
         hom_n=("data.valorTotalHomologado", "count"))
    .sort_values("n", ascending=False)
)
hom_sem = c.loc[c["data.numeroControlePNCP"] != ANOMALIA].groupby("data.modalidadeNome")["data.valorTotalHomologado"].sum()

ano_pub = c["data.dataPublicacaoPncp"].str[:4].value_counts().sort_index()
unid = c.groupby(["data.unidadeOrgao.codigoUnidade", "data.unidadeOrgao.nomeUnidade"]).size().sort_values(ascending=False)
sit_item = i.situacaoCompraItemNome.value_counts()
mat = i.materialOuServicoNome.value_counts()

# pares de possível republicação: mesmo valor estimado (>0)
pares = (
    c[c["data.valorTotalEstimado"] > 0].groupby("data.valorTotalEstimado")
    .filter(lambda g: len(g) > 1)
    .sort_values(["data.valorTotalEstimado", "seq"])
)

total_est = c["data.valorTotalEstimado"].sum()
hom = c["data.valorTotalHomologado"]
total_hom = hom.sum()
total_hom_sem = hom[c["data.numeroControlePNCP"] != ANOMALIA].sum()
an = c[c["data.numeroControlePNCP"] == ANOMALIA].iloc[0]
an_itens = i[i.numeroControlePNCP == ANOMALIA]
an_itens_total = pd.to_numeric(an_itens.valorTotal).sum()


def barra(v, vmax):
    pct = 0 if vmax == 0 else v / vmax * 100
    return f'<span class="bar"><span style="width:{pct:.1f}%"></span></span>'


# ---------- html ----------
linhas_mod = "".join(
    f"<tr><td>{e(m)}</td><td class='n'>{row.n}</td><td class='n'>{brl(row.est)}</td>"
    f"<td class='n'>{row.hom_n}</td><td class='n'>{brl(hom_sem.get(m, 0))}</td></tr>"
    for m, row in mod.iterrows()
)
linhas_ano = "".join(
    f"<tr><td>{a}</td><td class='n'>{n}</td><td class='w'>{barra(n, ano_pub.max())}</td></tr>" for a, n in ano_pub.items()
)
linhas_unid = "".join(f"<tr><td class='mono'>{cod}</td><td>{e(nome)}</td><td class='n'>{n}</td></tr>" for (cod, nome), n in unid.items())
linhas_sit = "".join(
    f"<tr><td>{e(s)}</td><td class='n'>{n}</td><td class='w'>{barra(n, sit_item.max())}</td></tr>" for s, n in sit_item.items()
)
linhas_trunc = "".join(
    f"<tr><td class='mono'><a href='https://pncp.gov.br/app/editais/25089137000195/{k.split('/')[1]}/{k.split('/')[0]}'>{k}</a></td>"
    f"<td class='n'>10</td><td class='n'>{v}</td><td class='n'>{v - 10}</td></tr>"
    for k, v in sorted(TRUNCADAS.items(), key=lambda kv: -kv[1])
)
linhas_med = "".join(
    f"<tr><td>{e(x.descricao)}</td><td class='mono'>{e(x.codigo_br)}</td><td class='n'>{float(x.similaridade):.2f}</td>"
    f"<td class='n'>{num(int(float(x.quantidade)))}</td><td class='n'>{brl(float(x.valorUnitarioEstimado))}</td>"
    f"<td class='n'>{brl(float(x['resultado.valorUnitarioHomologado']))}</td>"
    f"<td class='n'>{(float(x['resultado.valorUnitarioHomologado']) / float(x.valorUnitarioEstimado) - 1) * 100:.0f}%</td></tr>"
    for _, x in r.iterrows()
)
med_forn = r["resultado.nomeRazaoSocialFornecedor"].iloc[0]
med_total = pd.to_numeric(r["resultado.valorTotalHomologado"]).sum()

linhas_pares = ""
for v, g in pares.groupby("data.valorTotalEstimado", sort=True):
    ks = ", ".join(f"<a class='mono' href='{chave_curta(k)[1]}'>{chave_curta(k)[0]}</a>" for k in g["data.numeroControlePNCP"])
    homs = " / ".join("—" if pd.isna(h) else "homologado" for h in g["data.valorTotalHomologado"])
    linhas_pares += f"<tr><td>{ks}</td><td class='n'>{brl(v)}</td><td>{e(g['data.objetoCompra'].iloc[0][:90])}…</td><td>{homs}</td></tr>"

linhas_c = ""
for _, x in c.iterrows():
    k, url = chave_curta(x["data.numeroControlePNCP"])
    flags = []
    if x["data.numeroControlePNCP"] == ANOMALIA:
        flags.append("<span class='tag crit'>valor homologado suspeito</span>")
    if x["data.situacaoCompraNome"] == "Anulada":
        flags.append("<span class='tag'>anulada</span>")
    if x["data.numeroControlePNCP"] in sig and x["data.valorTotalEstimado"] == 0:
        flags.append("<span class='tag'>orçamento sigiloso</span>")
    nit = n_itens.get(x["data.numeroControlePNCP"], 0)
    trunc = f"{x['data.anoCompra']}/{x['seq']}" in TRUNCADAS
    if trunc:
        flags.append("<span class='tag warn'>itens incompletos</span>")
    if x["data.numeroControlePNCP"] in set(r.numeroControlePNCP):
        flags.append("<span class='tag ok'>medicamento</span>")
    linhas_c += (
        f"<tr><td class='mono'><a href='{url}'>{k}</a></td><td>{e(x['data.dataPublicacaoPncp'][:10])}</td>"
        f"<td>{e(x['data.modalidadeNome'])}</td><td class='obj'>{e(x['data.objetoCompra'])}</td>"
        f"<td class='n'>{nit}{'*' if trunc else ''}</td><td class='n'>{brl(x['data.valorTotalEstimado'])}</td>"
        f"<td class='n'>{brl(x['data.valorTotalHomologado'])}</td>"
        f"<td class='n'>{periodos_por_contr[x['data.numeroControlePNCP']]}</td><td>{' '.join(flags)}</td></tr>"
    )

periodo_ini, periodo_fim = PERIODOS[0], PERIODOS[-1]
n_periodos_dados = c_raw.periodo.nunique()
n_estimado_zero = int((c["data.valorTotalEstimado"] == 0).sum())

page = f"""<title>Unidades compradoras no PNCP</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Source+Serif+4:opsz,wght@8..60,600;8..60,700&family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
/* Layout: relatório de coluna única, ~72ch de texto, tabelas largas em contêineres roláveis */
:root {{
  --bg: #f6f7f5; --surface: #ffffff; --fg: #1d2420; --muted: #5c6862; --line: #d9dfdb;
  --accent: #1f6b52; --accent-soft: #e2efe9;
  --crit: #a3302a; --crit-soft: #f7e3e1; --warn: #8a5a00; --warn-soft: #f6ecd6; --ok: #1f6b52; --ok-soft: #e2efe9;
  --f-display: "Source Serif 4", Georgia, serif;
  --f-body: "IBM Plex Sans", system-ui, sans-serif;
  --f-mono: "IBM Plex Mono", ui-monospace, Consolas, monospace;
}}
@media (prefers-color-scheme: dark) {{ :root:not([data-theme="light"]) {{
  --bg: #141917; --surface: #1b2220; --fg: #e3e8e5; --muted: #9aa8a1; --line: #2f3936;
  --accent: #6cc4a1; --accent-soft: #1d3a30;
  --crit: #f08a80; --crit-soft: #3d2120; --warn: #e3b55a; --warn-soft: #3a2f17; --ok: #6cc4a1; --ok-soft: #1d3a30;
  color-scheme: dark; }} }}
:root[data-theme="dark"] {{
  --bg: #141917; --surface: #1b2220; --fg: #e3e8e5; --muted: #9aa8a1; --line: #2f3936;
  --accent: #6cc4a1; --accent-soft: #1d3a30;
  --crit: #f08a80; --crit-soft: #3d2120; --warn: #e3b55a; --warn-soft: #3a2f17; --ok: #6cc4a1; --ok-soft: #1d3a30;
  color-scheme: dark; }}
body {{ background: var(--bg); color: var(--fg); font: 15px/1.6 var(--f-body); }}
.wrap {{ max-width: 980px; margin: 0 auto; padding-inline: 20px; padding-block: 40px 80px; display: grid; gap: 44px; }}
header {{ display: grid; gap: 10px; border-bottom: 2px solid var(--fg); padding-bottom: 22px; }}
.eyebrow {{ font: 500 12px/1.4 var(--f-mono); letter-spacing: .08em; text-transform: uppercase; color: var(--accent); }}
h1 {{ font: 700 clamp(28px, 5vw, 40px)/1.1 var(--f-display); margin: 0; text-wrap: balance; }}
h2 {{ font: 600 24px/1.25 var(--f-display); margin: 0; text-wrap: balance; }}
h3 {{ font: 600 16px/1.3 var(--f-body); margin: 0; }}
p {{ margin: 0; max-width: 72ch; }}
.meta {{ color: var(--muted); font-size: 14px; }}
section {{ display: grid; gap: 16px; min-width: 0; }}
.stats {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); gap: 1px; background: var(--line); border: 1px solid var(--line); }}
.stat {{ background: var(--surface); padding: 14px 16px; display: grid; gap: 2px; }}
.stat b {{ font: 600 24px/1.2 var(--f-display); font-variant-numeric: tabular-nums; }}
.stat span {{ color: var(--muted); font-size: 13px; }}
ul.find {{ margin: 0; padding-left: 20px; display: grid; gap: 8px; max-width: 80ch; }}
.alert {{ border-left: 4px solid var(--warn); background: var(--warn-soft); padding: 16px 18px; display: grid; gap: 10px; min-width: 0; }}
.alert.crit {{ border-color: var(--crit); background: var(--crit-soft); }}
.alert.info {{ border-color: var(--muted); background: var(--surface); }}
.alert .sev {{ font: 500 11px/1 var(--f-mono); letter-spacing: .08em; text-transform: uppercase; color: var(--warn); }}
.alert.crit .sev {{ color: var(--crit); }}
.alert.info .sev {{ color: var(--muted); }}
.tbl {{ overflow-x: auto; border: 1px solid var(--line); background: var(--surface); }}
table {{ border-collapse: collapse; width: 100%; font-size: 13.5px; }}
th, td {{ text-align: left; padding: 8px 12px; border-bottom: 1px solid var(--line); vertical-align: top; }}
th {{ font: 500 11.5px/1.3 var(--f-mono); letter-spacing: .05em; text-transform: uppercase; color: var(--muted); background: var(--bg); position: sticky; top: 0; }}
tr:last-child td {{ border-bottom: 0; }}
td.n, th.n {{ text-align: right; font-variant-numeric: tabular-nums; white-space: nowrap; }}
td.w {{ width: 40%; }}
td.obj {{ min-width: 260px; max-width: 420px; }}
.mono {{ font-family: var(--f-mono); font-size: 12.5px; white-space: nowrap; }}
.bar {{ display: block; height: 8px; background: var(--line); }}
.bar span {{ display: block; height: 100%; background: var(--accent); }}
.tag {{ display: inline-block; font: 500 11px/1 var(--f-mono); padding: 4px 6px; margin: 0 4px 4px 0; border: 1px solid var(--line); color: var(--muted); white-space: nowrap; }}
.tag.crit {{ color: var(--crit); border-color: var(--crit); }}
.tag.warn {{ color: var(--warn); border-color: var(--warn); }}
.tag.ok {{ color: var(--ok); border-color: var(--ok); background: var(--ok-soft); }}
a {{ color: var(--accent); }}
a:focus-visible {{ outline: 2px solid var(--accent); outline-offset: 2px; }}
code {{ font-family: var(--f-mono); font-size: 13px; background: var(--accent-soft); padding: 1px 4px; }}
.two {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }}
.two > div {{ display: grid; gap: 10px; align-content: start; min-width: 0; }}
.foot {{ color: var(--muted); font-size: 13px; }}
</style>

<div class="wrap">
<header>
  <div class="eyebrow">Medicamentos Transparentes · análise de unidades compradoras</div>
  <h1>Unidades compradoras no PNCP</h1>
  <p class="meta">{len(PERIODOS)} períodos de coleta, de {periodo_ini} a {periodo_fim} · dados em <code>tasks/analise-unidades-compradoras/output</code> · gerado em 05/10/2026</p>
</header>

<section>
  <h2>Resumo</h2>
  <div class="stats">
    <div class="stat"><b>{len(c)}</b><span>contratações únicas ({len(c_raw)} registros em {n_periodos_dados} períodos)</span></div>
    <div class="stat"><b>{len(i)}</b><span>itens coletados (de {itens_reais} existentes no PNCP)</span></div>
    <div class="stat"><b>{mi(total_est)}</b><span>valor total estimado</span></div>
    <div class="stat"><b>{len(r)}</b><span>itens classificados como medicamento</span></div>
  </div>
  <ul class="find">
    <li>Dos três CNPJs buscados, <strong>só a unidade01 (25.089.137/0001-95) aparece</strong>. É a Secretaria da Agricultura, Pecuária e Aquicultura do Tocantins, em Palmas. As raízes 16.723.250 e 18.729.020 não aparecem em nenhum período, nem como órgão responsável nem como sub-rogado.</li>
    <li>São {len(c)} contratações, quase todas pregões eletrônicos ({mod.loc['Pregão - Eletrônico','n']}) e dispensas ({mod.loc['Dispensa','n']}). O valor homologado informado soma {mi(total_hom)}, mas {mi(hom[c['data.numeroControlePNCP']==ANOMALIA].iloc[0])} vêm de <strong>uma única contratação com valor provavelmente errado</strong>. Sem ela, o homologado é {mi(total_hom_sem)}.</li>
    <li>Os únicos medicamentos são <strong>hormônios veterinários</strong> (progesterona e estradiol para inseminação de bovinos). O classificador marcou os itens com similaridade pouco acima do limite de 0,5, então eles não são compras de saúde humana.</li>
    <li><strong>A coleta de itens do pipeline guarda no máximo 10 itens por contratação.</strong> Neste órgão, {len(TRUNCADAS)} contratações foram cortadas e faltam {reais_truncadas - 10*len(TRUNCADAS)} itens. O problema atinge cerca de 19% das contratações de toda a base.</li>
  </ul>
</section>

<section>
  <h2>CNPJs buscados</h2>
  <div class="tbl"><table>
    <tr><th>Unidade</th><th>CNPJ ou raiz</th><th>Busca</th><th class="n">Contratações</th><th>Órgão</th></tr>
    <tr><td>unidade01</td><td class="mono">25.089.137/0001-95</td><td>exata</td><td class="n">{len(c)}</td><td>Secretaria da Agricultura, Pecuária e Aquicultura (TO)</td></tr>
    <tr><td>unidade02</td><td class="mono">16.723.250/0001-90</td><td>exata</td><td class="n">0</td><td>—</td></tr>
    <tr><td>unidade03</td><td class="mono">18.729.020</td><td>raiz (todas as filiais)</td><td class="n">0</td><td>—</td></tr>
  </table></div>
  <p class="meta">A unidade02 e a unidade03 também foram procuradas pela raiz de 8 dígitos e como órgão sub-rogado, sem resultado. Vale conferir se os CNPJs estão certos ou se esses órgãos publicam no PNCP com outro CNPJ.</p>
</section>

<section>
  <h2>Contratações da unidade01</h2>
  <div class="two">
    <div>
      <h3>Unidades compradoras</h3>
      <div class="tbl"><table><tr><th>Código</th><th>Nome no PNCP</th><th class="n">Contratações</th></tr>{linhas_unid}</table></div>
      <p class="meta">As duas unidades são a mesma secretaria com cadastros diferentes no PNCP.</p>
    </div>
    <div>
      <h3>Ano de publicação no PNCP</h3>
      <div class="tbl"><table><tr><th>Ano</th><th class="n">Contratações</th><th></th></tr>{linhas_ano}</table></div>
      <p class="meta">Contratações de 2024 aparecem porque foram atualizadas durante as coletas de 2025 e 2026.</p>
    </div>
  </div>
  <h3>Por modalidade</h3>
  <div class="tbl"><table>
    <tr><th>Modalidade</th><th class="n">Contratações</th><th class="n">Valor estimado</th><th class="n">Com homologado</th><th class="n">Valor homologado*</th></tr>
    {linhas_mod}
    <tr><td><strong>Total</strong></td><td class="n"><strong>{len(c)}</strong></td><td class="n"><strong>{brl(total_est)}</strong></td><td class="n"><strong>{int(hom.notna().sum())}</strong></td><td class="n"><strong>{brl(total_hom_sem)}</strong></td></tr>
  </table></div>
  <p class="meta">* Sem a contratação 7/2024 (ver alertas). Todas usam a Lei 14.133/2021 e o critério de menor preço. {int((c['data.srp']=='TRUE').sum())} são registro de preços (SRP). {int((c['data.situacaoCompraNome']=='Anulada').sum())} estão anuladas. {n_estimado_zero} têm valor estimado zero porque o orçamento é sigiloso, então o valor estimado real é maior que o total acima.</p>
  <p>Os objetos são típicos de uma secretaria de agricultura: locação de máquinas e ônibus, sementes e mudas, equipamentos agrícolas, transferência de embriões bovinos, hormônios veterinários, paisagismo para feiras, hospedagem e serviços de apoio.</p>
</section>

<section>
  <h2>Itens</h2>
  <div class="two">
    <div>
      <h3>Situação dos itens</h3>
      <div class="tbl"><table><tr><th>Situação</th><th class="n">Itens</th><th></th></tr>{linhas_sit}</table></div>
    </div>
    <div>
      <h3>Composição</h3>
      <div class="tbl"><table>
        <tr><th>Tipo</th><th class="n">Itens</th></tr>
        <tr><td>Serviço</td><td class="n">{mat.get('Serviço',0)}</td></tr>
        <tr><td>Material</td><td class="n">{mat.get('Material',0)}</td></tr>
        <tr><td>Com orçamento sigiloso</td><td class="n">{int((i.orcamentoSigiloso.str.upper()=='TRUE').sum())}</td></tr>
        <tr><td>Medicamentos (classificador)</td><td class="n">{len(r)}</td></tr>
      </table></div>
      <p class="meta">Os números se referem aos {len(i)} itens coletados. Por causa do limite de 10 itens por contratação, faltam {reais_truncadas - 10*len(TRUNCADAS)}.</p>
    </div>
  </div>
</section>

<section>
  <h2>Medicamentos e resultados</h2>
  <p>Há uma única contratação com medicamentos: o pregão <a class="mono" href="https://pncp.gov.br/app/editais/25089137000195/2025/39">39/2025</a>, de hormônios veterinários para protocolos de inseminação artificial em tempo fixo. Os três itens foram homologados para <strong>{e(med_forn)}</strong>, que somou {brl(med_total)}, todos abaixo do preço estimado.</p>
  <div class="tbl"><table>
    <tr><th>Item</th><th>Código BR</th><th class="n">Similaridade</th><th class="n">Quantidade</th><th class="n">Unit. estimado</th><th class="n">Unit. homologado</th><th class="n">Diferença</th></tr>
    {linhas_med}
  </table></div>
  <p class="meta">O pregão 40/2025 tem o mesmo objeto (fornecimento de hormônios veterinários), mas nenhum item dele foi classificado como medicamento. Isso reforça que a classificação desses itens está no limite.</p>
</section>

<section>
  <h2>Alertas de qualidade dos dados</h2>

  <div class="alert crit">
    <div class="sev">Crítico · pipeline</div>
    <h3>A coleta de itens guarda no máximo 10 itens por contratação</h3>
    <p>O <code>coleta-itens.R</code> chama <code>/compras/&lt;ano&gt;/&lt;seq&gt;/itens</code> sem os parâmetros de paginação, e a API do PNCP devolve só os 10 primeiros itens. Testei na API: o pregão 13/2025 devolve 10 itens sem parâmetros, 12 com <code>tamanhoPagina=500</code>, e <code>/itens/quantidade</code> confirma 12. Em toda a base, nenhuma contratação tem mais de 10 itens, e cerca de 19% param exatamente em 10 (5.568 de 29.228 em 2025-01/Q1; 16.117 de 88.100 em 2026-03/Q2). Isso também afeta a identificação de medicamentos no Medicamentos Transparentes.</p>
    <div class="tbl"><table>
      <tr><th>Contratação</th><th class="n">Coletados</th><th class="n">No PNCP</th><th class="n">Faltando</th></tr>
      {linhas_trunc}
      <tr><td><strong>Total</strong></td><td class="n"><strong>{10*len(TRUNCADAS)}</strong></td><td class="n"><strong>{reais_truncadas}</strong></td><td class="n"><strong>{reais_truncadas-10*len(TRUNCADAS)}</strong></td></tr>
    </table></div>
  </div>

  <div class="alert">
    <div class="sev">Atenção · dado de origem</div>
    <h3>Valor homologado provavelmente errado no pregão 7/2024</h3>
    <p>A contratação <a class="mono" href="https://pncp.gov.br/app/editais/25089137000195/2024/7">7/2024</a> (locação de ônibus) tem valor estimado de {brl(an['data.valorTotalEstimado'])} e <strong>valor homologado de {brl(an['data.valorTotalHomologado'])}</strong>, cerca de {an['data.valorTotalHomologado']/an['data.valorTotalEstimado']:.0f} vezes maior. Os quatro itens são quilômetros rodados a cerca de R$ 13 por km e somam {brl(an_itens_total)} estimados. O valor homologado no cabeçalho deve ter sido registrado errado no PNCP. Ele foi retirado dos totais deste relatório.</p>
  </div>

  <div class="alert">
    <div class="sev">Atenção · classificador</div>
    <h3>Os medicamentos encontrados são de uso veterinário</h3>
    <p>Progesterona e estradiol foram classificados com similaridade entre 0,52 e 0,54, pouco acima do limite de 0,5. São insumos de reprodução animal. Se a ferramenta for só sobre saúde humana, esses itens são falsos positivos.</p>
  </div>

  <div class="alert info">
    <div class="sev">Para conferir · possível republicação</div>
    <h3>Contratações com o mesmo objeto e o mesmo valor estimado</h3>
    <p>Em {pares['data.valorTotalEstimado'].nunique()} casos, duas ou três contratações têm valor estimado idêntico e objeto equivalente, e em geral só uma tem homologação. Parece um edital publicado de novo, ou o aviso de registro de preços separado da contratação. Somar o valor estimado dessas contratações conta o mesmo valor duas vezes.</p>
    <div class="tbl"><table><tr><th>Contratações</th><th class="n">Valor estimado</th><th>Objeto</th><th>Homologação</th></tr>{linhas_pares}</table></div>
  </div>
</section>

<section>
  <h2>Todas as contratações</h2>
  <p class="meta">Versão mais recente de cada contratação, ordenada por ano e sequencial. O número leva à página da contratação no PNCP. Um * na coluna de itens indica que a coleta parou em 10 itens. A última coluna diz em quantos períodos de coleta a contratação apareceu.</p>
  <div class="tbl"><table>
    <tr><th>Nº</th><th>Publicação</th><th>Modalidade</th><th>Objeto</th><th class="n">Itens</th><th class="n">Estimado</th><th class="n">Homologado</th><th class="n">Períodos</th><th>Observações</th></tr>
    {linhas_c}
  </table></div>
</section>

<section class="foot">
  <h3>Como os números foram calculados</h3>
  <p>Fonte: os arquivos <code>contratacoes.csv</code>, <code>itens.csv</code> e <code>medicamentos-resultados.csv</code> de cada período em <code>output/</code>, gerados pelo notebook <code>analise_unidades_compradoras.ipynb</code>. Como o PNCP é coletado pelas datas de atualização, a mesma contratação aparece em mais de um período: {len(c_raw)} registros correspondem a {len(c)} contratações únicas. Para cada contratação e cada item, foi usada a versão mais recente (maior <code>dataAtualizacao</code>). Valores em reais, como informados no PNCP. O total real de itens das contratações cortadas foi consultado em <code>/itens/quantidade</code> na API do PNCP em 05/10/2026.</p>
</section>
</div>
"""
SAIDA.write_text(page, encoding="utf-8")
print(SAIDA, len(page))
