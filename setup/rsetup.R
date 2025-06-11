
# color pallet ----------------------------------------------------------------

# cores tb logo
cores_tb <- c(
  laranja = "#F6A323",
  cinza_escuro = "#1d1d1b",
  cinza_claro = "#6f7171",
  cinza_quase_branco = "#ececec",
  azul = "#41ACBD"
)

#' Paleta de cores Achados e pedidos
cores_aep <- c(
  laranja = "#fcaa27",
  rosa = "#D81755",
  cinza = "#969696",
  marrom = "#B27D5C"
)

# ggplot theme customization --------------------------------------------------

ggplot2::theme_set(ggpubr::theme_pubclean())

theme_update(
  legend.position = 'bottom', 
  axis.title = element_text(size = 12, vjust = 1, hjust = 1),
  axis.text = element_text(size = 11),
  plot.caption = element_text(vjust = 1, hjust = 0)
)

# helper functions ------------------------------------------------------------

reais <- function(x) {
  scales::dollar(
    x,
    prefix = "R$ ",
    accuracy = 1.0,
    big.mark = ".",
    decimal.mark = ","
  )
}

reais_milhoes <- function(x) {
  scales::number(
    x / 1e6,
    prefix = "R$ ",
    big.mark = ".",
    decimal.mark = ",",
    suffix = " Mi",
    accuracy = 0.100
  )
}

reais_bilhoes <- function(x) {
  scales::number(
    x / 1e9,
    prefix = "R$ ",
    big.mark = ".",
    decimal.mark = ",",
    suffix = " Bi",
    accuracy = 0.100
  )
}
