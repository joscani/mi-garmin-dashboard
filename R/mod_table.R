#' Módulo de tabla de sesiones

library(DT)

mod_table_ui <- function(id) {
  ns <- NS(id)
  DTOutput(ns("table"), width = "100%")
}

mod_table_server <- function(id, activities) {
  moduleServer(id, function(input, output, session) {

    table_data <- reactive({
      activities() |>
        transmute(
          Fecha            = date,
          Nombre           = activityName,
          `Dist. (m)`      = round(distance_m),
          `T. activo`      = if_else(!is.na(duration_min),
            sprintf("%d:%02d", floor(duration_min), round((duration_min %% 1) * 60)),
            "\u2014"),
          SWOLF            = averageSwolf,
          `Braz/largo`     = round(avg_brazadas, 1),
          Largos           = largos,
          `Piscina`        = paste0(pool_length_m, "m"),
          `FC med`         = averageHR,
          `Ritmo /100m`    = if_else(!is.na(pace_100m), format_pace(pace_100m), "\u2014")
        ) |>
        arrange(desc(Fecha))
    })

    output$table <- renderDT({
      datatable(
        table_data(),
        rownames = FALSE,
        class = "compact stripe hover",
        options = list(
          pageLength = 20,
          dom = "frtip",
          scrollX = TRUE,
          language = list(
            url = "//cdn.datatables.net/plug-ins/1.10.11/i18n/Spanish.json"
          )
        )
      )
    })

  })
}
