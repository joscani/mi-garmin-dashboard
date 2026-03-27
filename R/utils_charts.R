#' Tema ggplot2 para el dashboard de natación

library(ggplot2)

swim_palette <- c(
  primary   = "#0077b6",
  accent    = "#00b4d8",
  light     = "#48cae4",
  lighter   = "#90e0ef",
  success   = "#06d6a0",
  warning   = "#ffd166",
  heart_avg = "#e63946",
  heart_max = "#f4a261",
  text      = "#1a1a2e",
  text_soft = "#64748b",
  grid      = "#e2e8f0",
  bg        = "#ffffff"
)

theme_swim <- function(base_size = 13) {
  theme_minimal(base_size = base_size, base_family = "sans") +
    theme(
      plot.background  = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA),
      panel.grid.major = element_line(color = "#e2e8f0", linewidth = 0.3),
      panel.grid.minor = element_blank(),
      axis.text        = element_text(color = "#64748b", size = rel(0.85)),
      axis.title       = element_text(color = "#1a1a2e", size = rel(0.9), face = "bold"),
      plot.title       = element_text(color = "#1a1a2e", size = rel(1.1), face = "bold", margin = margin(b = 8)),
      plot.subtitle    = element_text(color = "#64748b", size = rel(0.88), lineheight = 1.5, margin = margin(b = 14)),
      legend.position  = "bottom",
      legend.text      = element_text(color = "#1a1a2e", size = rel(0.85)),
      legend.title     = element_blank(),
      strip.text       = element_text(color = "#1a1a2e", face = "bold"),
      plot.margin      = margin(10, 15, 10, 10)
    )
}
