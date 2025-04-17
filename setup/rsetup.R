library(colorspace)

#' Paleta de cores Transparência Brasil
cores_tb <- c(
  laranja = "#F6A323",
  cinza_escuro = "#1d1d1b",
  cinza_claro = "#6f7171",
  cinza_quase_branco = "#ececec",
  azul = "#41ACBD",
  vermelho_tadepe = "#7d1611",
  azul_tadepe = "#124C7D",
  verde_mais_defensoria = "#10624E",
  azul_medicamentos_transparente = "#1587A9",
  verde_medicamentos_transparente = "#BACC29"
)

#' Paleta de cores Achados e pedidos
cores_aep <- c(
  laranja = "#fcaa27",
  rosa = "#D81755",
  vermelho = "#F03034",
  cinza = "#969696",
  marrom = "#B27D5C"
)

# uso de fontes e plot-aesthetics
library(ggplot2)
hrbrthemes::import_roboto_condensed()
extrafont::loadfonts()
ggplot2::theme_set(hrbrthemes::theme_ipsum_rc())

theme_update(
  panel.grid.minor = element_blank(),
  panel.background = element_rect(fill = "gray97", color = "transparent"),
  axis.line.y = element_blank(),
  axis.line.x = element_blank(), # element_line(color = "gray30"),
  axis.title = ggtext::element_markdown(hjust = .5, size = 12),
  axis.title.x = ggtext::element_markdown(hjust = .5, size = 12),
  axis.title.x.top = ggtext::element_markdown(hjust = .5, size = 12),
  axis.title.x.bottom = ggtext::element_markdown(hjust = .5, size = 12),
  axis.title.y = ggtext::element_markdown(hjust = .5, size = 12),
  axis.title.y.left = ggtext::element_markdown(hjust = .5, size = 12),
  axis.title.y.right = ggtext::element_markdown(hjust = .5, size = 12),
  axis.text = ggtext::element_markdown(size = 12),
  axis.text.x = ggtext::element_markdown(size = 12),
  axis.text.x.top = ggtext::element_markdown(size = 12),
  axis.text.x.bottom = ggtext::element_markdown(size = 12),
  axis.text.y = ggtext::element_markdown(size = 12),
  axis.text.y.left = ggtext::element_markdown(size = 12),
  axis.text.y.right = ggtext::element_markdown(size = 12),
  text = element_text(family = "Roboto Condensed"),
  legend.text = ggtext::element_markdown(size = 12),
  legend.title = ggtext::element_markdown(),
  plot.title.position = "plot",
  plot.title = ggtext::element_markdown(),
  plot.subtitle = ggtext::element_markdown(hjust = 0, color = cores_tb[["cinza_claro"]]),
  plot.caption = ggtext::element_markdown(size = 10, color = cores_tb[["cinza_claro"]]),
  plot.tag = ggtext::element_markdown(),
  strip.text = ggtext::element_markdown(size = 13, hjust = .5),
  strip.text.x = ggtext::element_markdown(),
  strip.text.x.bottom = ggtext::element_markdown(),
  strip.text.x.top = ggtext::element_markdown(),
  strip.text.y = ggtext::element_markdown(),
  strip.text.y.left = ggtext::element_markdown(),
  strip.text.y.right = ggtext::element_markdown(),
  panel.grid.major.x = element_blank(),
  panel.grid.major.y = element_line(color = "gray80", linewidth = .1)
)

# helper functions:

# funções auxiliares
reais <- function(...) scales::dollar(..., big.mark = ".", decimal.mark = ",", prefix = "R$ ")
numero <- function(...) scales::number(..., big.mark = ".", decimal.mark = ",")
perc <- function(...) scales::percent(..., big.mark = ".", decimal.mark = ",")

hrbrthemes::update_geom_font_defaults(
  color = "gray30",
  family = "Roboto Condensed"
)

fmt_currency_brl <- function(...) {
  gt::fmt_currency(
    ...,
    sep_mark = ".",
    dec_mark = ",",
    currency = "BRL",
    decimals = 0
  )
}

fmt_integer_ptbr <- function(...) {
  gt::fmt_integer(
    ...,
    sep_mark = "."
  )
}

fmt_percent_ptbr <- function(...) {
  gt::fmt_percent(
    ...,
    sep_mark = ".",
    dec_mark = ","
  )
}

fmt_number_ptbr <- function(...) {
  gt::fmt_number(
    ...,
    sep_mark = ".",
    dec_mark = ","
  )
}

tidy_currency <- function(x) {
  x %>%
    str_remove_all("^R\\$") %>%
    str_remove_all("\\s*") %>%
    str_remove_all("\\.") %>%
    str_replace_all(",", "\\.") %>%
    as.numeric()
}