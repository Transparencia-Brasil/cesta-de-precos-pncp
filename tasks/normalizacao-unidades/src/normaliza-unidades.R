#' Documentação do script
#' 

library(here)         # File referencing

CAMINHO_CATALOGO <- here("data/catmat/catmat.rds")
catmat <- readRDS(CAMINHO_CATALOGO)

# Desaninha a coluna unidadeFornecimento do catmat
catmat_expandido <- catmat %>% unnest(unidadeFornecimento)

# Substitui DOSE(s) por DOSE e etc
catmat_expandido <-  catmat_expandido %>%
  mutate(
    siglaUnidadeFornecimento = ifelse(siglaUnidadeFornecimento == "DOSE(S)", "DOSE", siglaUnidadeFornecimento),
    nomeUnidadeFornecimento = case_when(nomeUnidadeFornecimento == "(Doses)" ~ "dose",
                                        nomeUnidadeFornecimento == "Gigabecquerell" ~ "gigabecquerell",
                                        TRUE ~ nomeUnidadeFornecimento),
    siglaUnidadeMedida = ifelse(siglaUnidadeMedida == "DOSE(S)", "DOSE", siglaUnidadeMedida),
    nomeUnidadeMedida = ifelse(nomeUnidadeMedida == "DOSE(S)", "DOSE", nomeUnidadeMedida),
    
  )

# limpa os textos
catmat_expandido <- catmat_expandido %>%
  mutate(siglaUnidadeFornecimento = clean_text(siglaUnidadeFornecimento),
         nomeUnidadeFornecimento = clean_text(nomeUnidadeFornecimento),
         siglaUnidadeMedida = clean_text(siglaUnidadeMedida),
         nomeUnidadeMedida = clean_text(nomeUnidadeMedida),
)
  
# Estrutura as unidades de fornecimento, unidades de medida e capacidades em uma lista nomeada
unidades <- catmat_expandido %>%
  group_by(codigo_br, siglaUnidadeFornecimento, nomeUnidadeFornecimento) %>%
  summarise(unidades_medida = list(c(unique(nomeUnidadeMedida), unique(siglaUnidadeMedida))), .groups = "drop")



# [codigo_br] > [unidade de fornecimento] > [unidade de medida] > [capacidade]