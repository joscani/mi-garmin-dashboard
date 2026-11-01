#' Módulo de tabla de sesiones

library(DT)

DT_ES <- list(
  search = "Buscar:", zeroRecords = "No hay sesiones", emptyTable = "No hay sesiones",
  info = "Sesiones _START_ a _END_ de _TOTAL_", infoEmpty = "0 sesiones",
  infoFiltered = "(de _MAX_ en total)", lengthMenu = "Mostrar _MENU_",
  paginate = list(first = "Primera", last = "Última", `next` = "Siguiente", previous = "Anterior")
)

mod_table_ui <- function(id) {
  ns <- NS(id)
  tagList(
    div(class = "d-flex justify-content-end mb-2",
      downloadButton(ns("descargar"), "Descargar CSV", class = "btn-outline-primary btn-sm")),
    DTOutput(ns("table"), width = "100%")
  )
}

mod_table_server <- function(id, activities) {
  moduleServer(id, function(input, output, session) {

    table_data <- reactive({
      activities() |>
        transmute(
          Fecha            = date,
          Nombre           = activityName,
          `Dist. (m)`      = round(distance_m),
          `T. activo`      = if_else(!is.na(duration_min), format_pace(duration_min), "\u2014"),
          `T. total`       = if_else(!is.na(duration_total_min), format_pace(duration_total_min), "\u2014"),
          SWOLF            = averageSwolf,
          `Braz/largo`     = round(avg_brazadas, 1),
          Largos           = largos,
          `Piscina`        = paste0(pool_length_m, "m"),
          `FC med`         = averageHR,
          `Ritmo /100m`    = if_else(!is.na(pace_100m), format_pace(pace_100m), "\u2014")
        ) |>
        arrange(desc(Fecha))
    })

    # Exporta las columnas originales (sin formatear) del periodo filtrado
    output$descargar <- downloadHandler(
      filename = function() paste0("natacion_", format(Sys.Date(), "%Y%m%d"), ".csv"),
      content  = function(file) {
        activities() |>
          arrange(desc(date)) |>
          select(date, activityName, distance_m, duration_min, duration_total_min,
                 averageSwolf, avg_brazadas, med_brazadas, largos, pool_length_m,
                 averageHR, maxHR, pace_100m) |>
          readr::write_csv(file)
      }
    )

    output$table <- renderDT({
      datatable(
        table_data(),
        rownames = FALSE,
        class = "compact stripe hover",
        options = list(
          pageLength = 20,
          dom = "frtip",
          scrollX = TRUE,
          # Textos en línea: el fichero de idioma remoto retrasaba la inicialización
          # y un resize durante la espera lanzaba un TypeError en DataTables
          language = DT_ES
        )
      )
    })

  })
}
