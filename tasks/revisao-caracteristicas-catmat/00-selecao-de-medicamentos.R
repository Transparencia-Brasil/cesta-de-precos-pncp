# :: LIBS ----------------------------------------------------------------------
library(tidyverse)
library(here)
library(jsonlite)
options(width = 150)
source(here("src/ETL/loaders/utils.R"))

# :: COUNT MEDICAMENTOS --------------------------------------------------------

# conecta ao BD
con <- conecta_bd_medicamentos_transparentes()

# Edição de query
qry <- "
  with item_h as (
    select codigo_item_catalogo as codigo_item,
          count(codigo_item_catalogo) as qtd
    from item_homologado
    group by codigo_item_catalogo
    order by qtd desc
  ), catmat as (
    select codigo_pdm,
          codigo_item,
          nome_item,
          características,
          unidades_fornecimento
    from catalogo
  ) select item_h.qtd,
        item_h.codigo_item,
        catmat.codigo_pdm,
        catmat.nome_item,
        catmat.características,
        catmat.unidades_fornecimento
  from item_h
  left join catmat on (item_h.codigo_item = catmat.codigo_item)
"

# Executa query
count_medicines <- get_query(qry)

# recodifica campos para performar joins
count_medicines <- count_medicines %>%
  mutate(
    qtd = as.integer(qtd),
    codigo_pdm = as.character(codigo_pdm),
    codigo_item = as.character(codigo_item)
  )


# :: CHERRY PICK ---------------------------------------------------------------

# Critério de decisão para editar características manualmente
count_medicines %>%
  left_join(select(catalogo, codigo_item = codigo_br, codigo_pdm, nome_pdm)) %>%
  summarise(qtd = sum(qtd), .by = nome_pdm) %>%
  mutate(nome_pdm = fct_reorder(nome_pdm, qtd)) %>%
  slice_max(order_by = qtd, n = 50) %>%
  arrange(as.character(nome_pdm)) %>%
  pull(nome_pdm) %>%
  paste0(collapse = '",\n"') %>%
  paste0('c(\n"', ., '"\n)\n') %>%
  cat()

# lista de medicamentos (PDM) mais comprados
cherry_pick <- c(
  "Acebrofilina",
  "Acetilcisteína",
  "Aciclovir",
  # "Albendazol",
  # "Alopurinol",
  # "Alprazolam",
  # "Ambroxol",
  # "Aminofilina",
  # "Amiodarona",
  "Amoxicilina",
  "Ampicilina",
  # "Anlodipino Besilato",
  # "Aripiprazol",
  # "Atenolol",
  # "Atropina Sulfato",
  "Azitromicina",
  # "Benzilpenicilina",
  "Bicarbonato De Sódio",
  # "Biperideno",
  # "Bromoprida",
  # "Carbamazepina",
  # "Carbonato De Cálcio",
  # "Carvedilol",
  # "Cefalexina",
  # "Cetoprofeno",
  # "Clonazepam",
  # "Cloreto De Potássio",
  # "Cloreto De Sódio",
  # "Clorexidina Digluconato",
  # "Clorpromazina",
  "Dexametasona",
  "Diclofenaco",
  "Dipirona Sódica",
  # "Enoxaparina",
  # "Escopolamina Butilbrometo",
  # "Extrato Medicinal",
  # "Haloperidol",
  "Insulina",
  # "Lidocaína Cloridrato",
  # "Nutrição Parenteral",
  "Omeprazol",
  # "Pregabalina",
  # "Risperidona",
  # "Soro",
  # "Ácido Acetilsalicílico",
  # "Ácido Acético",
  # "Ácido Ascórbico",
  # "Ácido Fólico",
  # "Ácido Tranexâmico",
  # "Ácido Valpróico",
  # "Álcool Etílico",
  "Paracetamol" # Paracetamol é popular
)

# Visualização das compras mais comuns
count_medicines %>%
  left_join(select(catalogo, codigo_item = codigo_br, codigo_pdm, nome_pdm)) %>%
  summarise(qtd = sum(qtd), .by = nome_pdm) %>%
  mutate(
    revisar_caracteristicas = nome_pdm %in% cherry_pick,
    nome_pdm = fct_reorder(nome_pdm, qtd)
  ) %>%
  slice_max(order_by = qtd, n = 50) %>%
  ggplot(aes(y = nome_pdm, x = qtd, fill = revisar_caracteristicas)) +
  geom_col() +
  scale_fill_manual(values = c("gray50", "darkred")) +
  scale_x_continuous(expand = c(0.01, 0))
