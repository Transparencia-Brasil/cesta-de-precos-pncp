# Análise exploratória da coluna de marcas

Esta pasta reúne o notebook e os dados de entrada usados para avaliar a qualidade da
coluna `marca` dos itens homologados de compras públicas.

O objetivo da análise é estimar quanto dessa coluna possui informações válidas sobre marcas de medicamentos. Como não existe, neste fluxo, um catálogo oficial de marcas para validar cada valor, o resultado deve ser interpretado como uma estimativa
heurística e auditável, não como uma validação definitiva.

## Arquivos

- `analisa-marcas.ipynb`: notebook com as regras, tabelas, exemplos e resultado
  consolidado.
- `inputs/item_homologado_marcas.csv`: recorte de itens homologados analisado pelo
  notebook.

O CSV é tratado como dado de entrada. O notebook preserva o texto original de `marca`
e cria uma versão normalizada apenas para comparações.

## Perguntas da análise

O notebook procura responder, nesta ordem:

1. Existem valores formados somente por números?
2. Existem textos que aparentam não ser marcas, como unidades, embalagens, dosagens
   ou respostas genéricas?
3. Existem valores nulos ou textos em branco?
4. Qual é o percentual estimado de marcas válidas ou possivelmente válidas?

Para cada problema são mostrados a quantidade, o percentual e exemplos que permitam
conferir as regras.

## Metodologia

### 1. Leitura e preservação do dado

O arquivo é lido com `dtype=str`. Essa decisão evita conversões automáticas que
poderiam alterar códigos, números ou zeros à esquerda. Apenas as colunas necessárias
para a análise e para contextualizar os exemplos são selecionadas.

### 2. Normalização

Uma coluna auxiliar é criada para:

- remover diferenças de acentuação;
- converter letras para maiúsculas;
- uniformizar espaços;
- preservar caracteres úteis para reconhecer dosagens, como `%`, `/`, `+` e `-`.

A normalização não substitui nem corrige a coluna original. Os exemplos continuam
mostrando o valor recebido da fonte.

### 3. Valores somente numéricos

Um valor é classificado como somente numérico quando todo o seu conteúdo corresponde
a dígitos, admitindo separador decimal opcional.

Esses valores podem representar códigos, quantidades ou preenchimentos incorretos.
Sem uma fonte externa de referência, não são tratados como marcas válidas.

### 4. Descrições que aparentam não ser marcas

As descrições problemáticas são divididas em quatro grupos:

- **marcador genérico:** respostas como `SEM MARCA`, `NÃO INFORMADO`, `CONFORME
  EDITAL` ou `A DEFINIR`;
- **unidade/embalagem:** textos como `CAIXA`, `AMPOLA`, `FRASCO AMPOLA`, `TUBO` ou
  combinações desses termos com quantidades;
- **dosagem/concentração:** textos como `500 MG`, `10 MG/ML` ou outras combinações
  formadas essencialmente por quantidade e unidade de medida;
- **formatação inválida:** valores compostos somente por pontuação (`-`, `--`, `.`
  etc.) ou textos iniciados por aspas, que indicam preenchimento truncado ou malformado.

A segunda rodada de melhoria também identifica:

- expressões compostas apenas por parcelas numéricas, como `(3 + 5 + 100 + 100)`;
- dosagens no início do campo, mesmo quando seguidas por outros detalhes;
- embalagens precedidas por pontuação, como `.Ampola de vidro.` e `/CX C/60 FRS`;
- prefixos de registro sanitário (`ANVISA`, `RMS`, `REGISTRO`);
- códigos estruturados nos formatos observados no dataset, como `01A1019.01.BJ`.

As expressões de unidade, embalagem e dosagem mantêm a correspondência do texto
inteiro como regra principal. Regras complementares, ancoradas no início do campo,
capturam valores que começam claramente por embalagem, quantidade ou dosagem e depois
trazem apresentação, registro ou texto livre. Uma marca que apenas contenha um desses
termos no meio do nome não é rejeitada automaticamente.

Além das regex, o notebook lê `inputs/codelist_infos_erradas.csv`, transforma a coluna
`marca` em uma lista normalizada chamada `marcadores_genericos_codelist` e a incorpora
ao conjunto `marcadores_genericos`. O CSV possui 551 valores; após normalização e
remoção de duplicatas, 515 termos distintos são usados na comparação.

O notebook preserva a máscara da lógica original e mostra um comparativo com a
segunda rodada consolidada, incluindo todos os valores reclassificados e o motivo
aplicado.

Por decisão metodológica, valores iniciados por `GENÉRICO` ou `GENÉRICA` são mantidos
como possivelmente válidos.

### 5. Valores nulos e em branco

Os dois casos são contabilizados separadamente:

- **nulo:** ausência de valor interpretada pelo pandas como `NaN`;
- **em branco:** valor existente, mas vazio ou composto somente por espaços.

Como essas linhas não possuem uma marca que possa ser exibida, os exemplos apresentam
o número de controle PNCP, a descrição detalhada do item e a unidade de fornecimento.

### 6. Classificação consolidada

No resultado final cada linha pertence a apenas uma categoria. A precedência é:

1. nula;
2. em branco;
3. somente numérica;
4. descrição não-marca;
5. válida ou possivelmente válida.

Essa precedência evita dupla contagem. O último grupo é residual: reúne os valores que
não foram rejeitados por nenhuma regra, mas não garante que todos sejam marcas reais.

## Resultado do recorte atual

Na execução registrada no notebook, foram analisadas 65.976 linhas:

| Classificação | Quantidade | Percentual |
|---|---:|---:|
| Somente numérica | 798 | 1,21% |
| Descrição não-marca | 17.271 | 26,18% |
| Em branco | 0 | 0,00% |
| Nula | 48 | 0,07% |
| Válida ou possivelmente válida | 47.859 | 72,54% |
| **Total** | **65.976** | **100,00%** |

Entre as descrições não-marca, o notebook encontrou:

| Motivo | Quantidade | Percentual do total |
|---|---:|---:|
| Unidade/embalagem | 10.670 | 16,17% |
| Dosagem/concentração | 2.962 | 4,49% |
| Marcador genérico (informações genéricas) | 3.070 | 4,65% |
| Registro/código | 323 | 0,49% |
| Formatação inválida | 244 | 0,37% |
| Expressão numérica | 2 | 0,00% |

### Comparativo: lógica original × segunda rodada

| Resultado | Quantidade | Percentual do total |
|---|---:|---:|
| Possivelmente válidas — lógica original | 50.099 | 75,94% |
| Possivelmente válidas — segunda rodada | 47.859 | 72,54% |
| Redução líquida de possíveis marcas | 2.240 | 3,40% |

## Conclusões

O recorte analisado possui **65.976 registros de itens homologados**. Após a aplicação
das regex, das regras de formatação e da codelist de informações erradas:

- **47.859 registros (72,54%)** permaneceram como marcas válidas ou possivelmente
  válidas;
- **18.117 registros (27,46%)** foram considerados não aproveitáveis como marca.

O grupo não aproveitável é formado por 17.271 descrições não-marca, 798 valores
somente numéricos e 48 valores nulos. Não foram encontrados textos em branco; as
ausências de conteúdo presentes no arquivo foram interpretadas como nulas.

### Exemplos reais de informações que não são marcas

Os exemplos abaixo foram retirados diretamente do arquivo analisado. A quantidade
indica quantas linhas possuem exatamente aquele valor na coluna `marca`.

| Tipo de problema | Exemplos reais e quantidade | Por que não é considerado marca |
|---|---|---|
| Somente numérica | `1` (67), `500.0000` (12), `2025` (10), `1014600690070` (7) | São números, anos, quantidades ou possíveis registros sem identificação textual de marca. |
| Informação genérica | `NÃO SE APLICA` (725), `MANIPULADO` (276), `MEDICAMENTO MANIPULA` (206), `DIVERSOS` (60) | Informam ausência, tipo ou condição do produto, mas não identificam uma marca. |
| Unidade ou embalagem | `COMPRIMIDO` (944), `CPR` (552), `FRASCO` (463), `AMP` (333), `AMPOLA` (263) | Descrevem unidade de fornecimento, recipiente ou apresentação. |
| Dosagem ou concentração | `50 MG PO LIOF SOL IN` (35), `100 U/ML SOL INJ CT` (34), `1L` (20), `10 MG/ML SOL DIL INF` (20) | Descrevem concentração, volume ou forma farmacêutica. |
| Formatação inválida | `-` (114), `.` (57), `..` (24), `---` (5), `"SUSP. INJETÁVEL"` (3) | São apenas sinais ou fragmentos malformados, sem um nome de marca confiável. |
| Registro ou código | `AA09870RA` (4), `EP-11-20973` (4), `01A1019.01.BJ` (3), `T6399-100G` (2) | Correspondem a códigos estruturados, registros ou referências de catálogo. |
| Expressão numérica | `(10,0 + 2,5 + 10,0)` (1), `(3 + 5 + 100 + 100)` (1) | São composições ou somas numéricas, não nomes de marca. |
| Valor nulo | 48 linhas; entre elas, itens descritos como `Tofacitinibe` e `Insulina tipo degludeca` | A descrição do item existe, mas a coluna `marca` não foi preenchida. |

### Exemplos reais de marcas possíveis

Entre os valores que passaram pelas regras estão nomes reconhecíveis de laboratórios
ou marcas:

| Valor informado | Quantidade |
|---|---:|
| `HIPOLABOR` | 666 |
| `EMS` | 648 |
| `TEUTO` | 537 |
| `CRISTALIA` | 440 |
| `PRATI` | 359 |
| `GEOLAB` | 340 |
| `DFL` | 332 |
| `EUROFARMA` | 283 |

Por decisão metodológica, `GENERICO` (1.452 ocorrências) e `GENÉRICO` (757 ocorrências), e variações referentes à esse termo também permanecem no grupo possivelmente válido. Isso deve ser considerado ao interpretar o percentual final.
