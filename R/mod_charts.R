#' Módulo de gráficos - orquestador
#' Los gráficos están divididos por pestaña:
#'   mod_charts_evolucion.R  → pestaña Evolución
#'   mod_charts_sesiones.R   → pestaña Sesiones
#'   mod_charts_resumen.R    → pestaña Resumen

library(ggplot2)
library(ggiraph)
library(tidyr)
library(DT)

source("R/mod_trend_chart.R")
source("R/mod_lap_chart.R")
source("R/mod_charts_evolucion.R")
source("R/mod_charts_sesiones.R")
source("R/mod_charts_resumen.R")
source("R/mod_charts_comparar.R")

CHART_W <- 10
CHART_H <- 5

gi_opts    <- opts_sizing(rescale = TRUE, width = 1)
gi_hover   <- opts_hover(css = "fill-opacity:0.9; stroke-width:2;")
gi_tooltip <- opts_tooltip(
  css = "background:white; border:1px solid #cbd5e1; border-radius:8px; padding:8px 12px; font-size:12px; color:#1a1a2e; box-shadow:0 2px 8px rgba(0,0,0,0.1);",
  opacity = 1
)
gi_select <- opts_selection(type = "single", css = "fill:#ffd166;stroke:#ffd166;r:5px;")

make_girafe <- function(gg, selectable = FALSE) {
  opts <- list(gi_opts, gi_hover, gi_tooltip)
  if (selectable) opts <- c(opts, list(gi_select))
  girafe(ggobj = gg, width_svg = CHART_W, height_svg = CHART_H, options = opts)
}

# ── UI ──────────────────────────────────────────────────────────────────────

mod_charts_ui <- function(id) {
  ns <- NS(id)
  list(
    evolucion = mod_evolucion_ui(ns("evolucion")),
    laps      = mod_sesiones_ui(ns("sesiones")),
    resumen   = mod_resumen_ui(ns("resumen")),
    comparar  = mod_comparar_ui(ns("comparar"))
  )
}

# ── Server ──────────────────────────────────────────────────────────────────

mod_charts_server <- function(id, summary_data, activities, laps, stroke_filter, aggregation) {
  moduleServer(id, function(input, output, session) {

    # Reactivos compartidos entre sub-módulos
    active_laps <- reactive({
      al <- filter_active_laps(laps())
      sf <- stroke_filter()
      if (!is.null(sf) && sf != "all") al <- al |> filter(swimStroke == sf)
      al
    })

    session_quality <- reactive({
      compute_session_quality(laps())
    })

    sessions_ordered <- reactive({
      activities() |>
        left_join(session_quality(), by = "activityId") |>
        arrange(desc(date))
    })

    mod_evolucion_server("evolucion", activities, sessions_ordered, laps)
    mod_sesiones_server("sesiones",   activities, active_laps, sessions_ordered)
    mod_resumen_server("resumen",     summary_data, activities, laps, aggregation)
    mod_comparar_server("comparar",   sessions_ordered, active_laps)
  })
}
