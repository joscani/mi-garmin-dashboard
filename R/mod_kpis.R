#' Módulo de KPIs

library(bslib)
library(bsicons)

kpi_box <- function(ns, id, title, icon, theme) {
  value_box(
    title = title, value = textOutput(ns(id)),
    uiOutput(ns(paste0(id, "_delta")), class = "kpi-delta"),
    showcase = bs_icon(icon), showcase_layout = "top right", theme = theme
  )
}

mod_kpis_ui <- function(id) {
  ns <- NS(id)
  layout_column_wrap(
    width = "165px", fixed_width = FALSE, heights_equal = "row",
    # Altura natural: si no, page_sidebar las aplasta al repartir la altura
    fill = FALSE, class = "kpis",
    kpi_box(ns, "sessions",    "Sesiones",       "water",         "primary"),
    kpi_box(ns, "distance",    "Distancia",      "signpost-2",    "info"),
    kpi_box(ns, "swolf",       "SWOLF",          "speedometer",   "success"),
    kpi_box(ns, "pace",        "Ritmo /100m",    "stopwatch",     "warning"),
    kpi_box(ns, "strokes",     "Brazadas/largo", "arrow-repeat",  "primary"),
    kpi_box(ns, "active_time", "Tiempo activo",  "clock-history", "info")
  )
}

# Métricas de un conjunto de sesiones (NA si no hay datos)
kpi_valores <- function(acts) {
  m <- function(x) { v <- mean(x, na.rm = TRUE); if (is.nan(v)) NA_real_ else v }
  list(
    sessions    = nrow(acts),
    distance    = sum(acts$distance_m, na.rm = TRUE),
    swolf       = m(acts$averageSwolf),
    pace        = m(acts$pace_100m),
    strokes     = m(acts$avg_brazadas),
    active_time = sum(acts$duration_min, na.rm = TRUE)
  )
}

#' Etiqueta "↑ 12% vs periodo anterior" coloreada según si mejora
kpi_delta_tag <- function(actual, previo, lower_is_better = FALSE, fmt = NULL) {
  if (is.na(actual) || is.na(previo) || previo == 0) return(NULL)
  diff <- actual - previo
  if (abs(diff) < 1e-9) return(tags$span("= que el periodo anterior"))
  texto <- if (is.null(fmt)) paste0(round(abs(diff) / previo * 100), "%") else fmt(abs(diff))
  mejor <- if (lower_is_better) diff < 0 else diff > 0
  tags$span(
    class = if (mejor) "kpi-mejor" else "kpi-peor",
    paste0(if (diff > 0) "↑ " else "↓ ", texto, " vs periodo anterior")
  )
}

#' @param activities     reactive con las sesiones del periodo filtrado
#' @param activities_all reactive con todas las sesiones (para el periodo anterior)
#' @param date_range     reactive con el rango de fechas actual
mod_kpis_server <- function(id, activities, activities_all = NULL, date_range = NULL) {
  moduleServer(id, function(input, output, session) {

    actual <- reactive(kpi_valores(activities()))

    # Periodo anterior de la misma duración, justo antes del inicio del filtro
    previo <- reactive({
      if (is.null(activities_all) || is.null(date_range)) return(NULL)
      dr <- as.Date(date_range())
      req(length(dr) == 2, !anyNA(dr))
      dias <- as.numeric(dr[2] - dr[1]) + 1
      acts <- activities_all() |> filter(date >= dr[1] - dias, date < dr[1])
      if (nrow(acts) == 0) return(NULL)
      kpi_valores(acts)
    })

    output$sessions <- renderText(actual()$sessions)

    output$distance <- renderText({
      d <- actual()$distance
      if (d >= 1000) paste0(format(round(d / 1000, 1), nsmall = 1), " km")
      else paste0(round(d), " m")
    })

    output$swolf <- renderText({
      v <- actual()$swolf
      if (is.na(v)) "—" else round(v, 1)
    })

    output$pace <- renderText({
      v <- actual()$pace
      if (is.na(v)) "—" else format_pace(v)
    })

    output$strokes <- renderText({
      v <- actual()$strokes
      if (is.na(v)) "—" else round(v, 1)
    })

    output$active_time <- renderText(format_duration(actual()$active_time))

    # Deltas frente al periodo anterior. Menor es mejor en SWOLF, ritmo y brazadas.
    delta_output <- function(clave, lower_is_better = FALSE, fmt = NULL) {
      renderUI({
        p <- previo()
        if (is.null(p)) return(NULL)
        kpi_delta_tag(actual()[[clave]], p[[clave]], lower_is_better, fmt)
      })
    }
    output$sessions_delta    <- delta_output("sessions")
    output$distance_delta    <- delta_output("distance")
    output$swolf_delta       <- delta_output("swolf",   TRUE, function(x) round(x, 1))
    output$pace_delta        <- delta_output("pace",    TRUE, function(x) paste0(round(x * 60), "\""))
    output$strokes_delta     <- delta_output("strokes", TRUE, function(x) round(x, 1))
    output$active_time_delta <- delta_output("active_time")
  })
}
