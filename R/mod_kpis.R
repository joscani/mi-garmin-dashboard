#' Módulo de KPIs

library(bslib)
library(bsicons)

mod_kpis_ui <- function(id) {
  ns <- NS(id)
  layout_column_wrap(
    width = "180px", fixed_width = FALSE, heights_equal = "row",
    value_box(title = "Sesiones", value = textOutput(ns("sessions")),
      showcase = bs_icon("water"), theme = "primary", max_height = "120px"),
    value_box(title = "Distancia", value = textOutput(ns("distance")),
      showcase = bs_icon("signpost-2"), theme = "info", max_height = "120px"),
    value_box(title = "SWOLF", value = textOutput(ns("swolf")),
      showcase = bs_icon("speedometer"), theme = "success", max_height = "120px"),
    value_box(title = "Ritmo /100m", value = textOutput(ns("pace")),
      showcase = bs_icon("stopwatch"), theme = "warning", max_height = "120px"),
    value_box(title = "Brazadas/largo", value = textOutput(ns("strokes")),
      showcase = bs_icon("arrow-repeat"), theme = "primary", max_height = "120px"),
    value_box(title = "Tiempo activo", value = textOutput(ns("active_time")),
      showcase = bs_icon("clock-history"), theme = "info", max_height = "120px")
  )
}

mod_kpis_server <- function(id, activities) {
  moduleServer(id, function(input, output, session) {
    output$sessions <- renderText(nrow(activities()))

    output$distance <- renderText({
      d <- sum(activities()$distance_m, na.rm = TRUE)
      if (d >= 1000) paste0(format(round(d / 1000, 1), nsmall = 1), " km")
      else paste0(round(d), " m")
    })

    output$swolf <- renderText({
      v <- mean(activities()$averageSwolf, na.rm = TRUE)
      if (is.nan(v)) "\u2014" else round(v, 1)
    })

    output$pace <- renderText({
      v <- mean(activities()$pace_100m, na.rm = TRUE)
      if (is.nan(v)) "\u2014" else format_pace(v)
    })

    output$strokes <- renderText({
      v <- mean(activities()$avg_brazadas, na.rm = TRUE)
      if (is.nan(v)) "\u2014" else round(v, 1)
    })

    output$active_time <- renderText({
      mins <- sum(activities()$duration_min, na.rm = TRUE)
      h <- floor(mins / 60)
      m <- round(mins %% 60)
      if (h > 0) sprintf("%dh %02dmin", h, m) else sprintf("%d min", m)
    })
  })
}
