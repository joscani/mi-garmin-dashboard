#' Módulo reutilizable: gráfico de largos por sesión
#'
#' Parámetros:
#'   data         reactive() → data.frame con columnas largo, y_col, estilo, swimStroke
#'   y_col        nombre de columna para el eje Y ("brazadas" o "swolf")
#'   y_lab        etiqueta del eje Y y tooltip
#'   session_info reactive() → fila de la sesión actual (para título y subtítulo)

mod_lap_chart_ui <- function(id, height = "480px") {
  ns <- NS(id)
  girafeOutput(ns("plot"), height = height, width = "100%")
}

mod_lap_chart_server <- function(id, data, y_col, y_lab, session_info) {
  moduleServer(id, function(input, output, session) {

    output$plot <- renderGirafe({
      df  <- data()
      act <- session_info()
      req(nrow(df) > 0)

      h <- floor(act$duration_min / 60)
      m <- round(act$duration_min %% 60)
      dur_str <- if (h > 0) sprintf("%dh %02dmin", h, m) else sprintf("%d min", m)

      title_str <- paste0(
        format(act$date, "%d %B %Y"), "  ·  ",
        round(act$distance_m), " m  ·  ", dur_str,
        if (!is.na(act$pace_100m)) paste0("  ·  ", format_pace(act$pace_100m), " /100m") else ""
      )

      subtitle_str <- if (!is.na(act$calidad) && !is.null(act$n_crol) && act$n_crol > 0) {
        paste0("Sesión ", act$calidad,
               "  |  Buenos \u226411: ", act$pct_buenos, "%",
               "  Normales 12-13: ", act$pct_normales, "%",
               "  Caros \u226514: ", act$pct_caros, "%  (crol)")
      } else NULL

      gg <- ggplot(df, aes(x = largo, y = .data[[y_col]], color = estilo)) +
        geom_line(linewidth = 1, show.legend = FALSE) +
        geom_point_interactive(
          aes(tooltip = paste0("Largo ", largo,
                               "\n", y_lab, ": ", round(.data[[y_col]], 1),
                               "\nEstilo: ", estilo)),
          size = 3
        ) +
        scale_x_continuous(breaks = scales::pretty_breaks()) +
        scale_color_manual(values = c(
          "Crol"     = swim_palette[["primary"]],
          "Espalda"  = swim_palette[["success"]],
          "Braza"    = swim_palette[["warning"]],
          "Mariposa" = swim_palette[["heart_avg"]],
          "Mixto"    = swim_palette[["lighter"]],
          "Técnica"  = swim_palette[["text_soft"]]
        )) +
        labs(x = "Largo", y = y_lab, title = title_str, subtitle = subtitle_str) +
        theme_swim()

      make_girafe(gg)
    })
  })
}
