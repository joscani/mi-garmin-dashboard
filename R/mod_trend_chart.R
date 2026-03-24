#' Módulo reutilizable: gráfico de tendencia (línea + puntos)
#'
#' Parámetros:
#'   data        reactive() → data.frame con columnas x_col, y_col (y opcionales min/max)
#'   x_col       nombre de columna para el eje X (fecha)
#'   y_col       nombre de columna para el eje Y
#'   color       nombre de clave en swim_palette o color hex
#'   y_lab       etiqueta del eje Y (también usada en tooltip)
#'   y_min_col   ribbon mínimo (opcional)
#'   y_max_col   ribbon máximo (opcional)
#'   show_smooth añadir curva loess (default FALSE)
#'   smooth_se   mostrar banda de confianza del smooth (default FALSE)
#'   show_area   añadir relleno de área bajo la línea (default FALSE)
#'   selectable  los puntos son clicables → devuelve activityId seleccionado
#'   y_formatter función para formatear etiquetas del eje Y (opcional)
#'   tooltip_fn  función(df) → character; si NULL usa tooltip por defecto

mod_trend_chart_ui <- function(id, height = "480px") {
  ns <- NS(id)
  girafeOutput(ns("plot"), height = height, width = "100%")
}

mod_trend_chart_server <- function(
    id,
    data,
    x_col,
    y_col,
    color,
    y_lab       = NULL,
    y_min_col   = NULL,
    y_max_col   = NULL,
    show_smooth = FALSE,
    smooth_se   = FALSE,
    show_area   = FALSE,
    selectable  = FALSE,
    y_formatter = NULL,
    tooltip_fn  = NULL
) {
  moduleServer(id, function(input, output, session) {

    output$plot <- renderGirafe({
      df <- data()
      req(nrow(df) > 0)

      col <- if (color %in% names(swim_palette)) swim_palette[[color]] else color

      # Tooltip por defecto
      tip <- if (!is.null(tooltip_fn)) {
        tooltip_fn(df)
      } else {
        label_prefix <- if (!is.null(y_lab)) paste0(y_lab, ": ") else ""
        val_str <- if (!is.null(y_formatter)) {
          sapply(df[[y_col]], y_formatter)
        } else {
          as.character(round(df[[y_col]], 1))
        }
        base <- paste0(format(df[[x_col]], "%d %b %y"), "\n", label_prefix, val_str)
        if (!is.null(y_min_col)) {
          base <- paste0(base,
                         "\nMin: ", round(df[[y_min_col]], 1),
                         "\nMáx: ", round(df[[y_max_col]], 1))
        }
        if (selectable) base <- paste0(base, "\n\U0001F4CC Clic para ver detalle")
        base
      }
      df[["..tip.."]] <- tip

      gg <- ggplot(df, aes(x = .data[[x_col]]))

      if (!is.null(y_min_col)) {
        gg <- gg + geom_ribbon(
          aes(ymin = .data[[y_min_col]], ymax = .data[[y_max_col]]),
          fill = col, alpha = 0.15
        )
      }

      if (show_area) {
        gg <- gg + geom_area(aes(y = .data[[y_col]]), fill = col, alpha = 0.2)
      }

      gg <- gg + geom_line(aes(y = .data[[y_col]]), color = col, linewidth = 1.3)

      if (show_smooth) {
        gg <- gg + geom_smooth(
          aes(y = .data[[y_col]]),
          method = "loess", formula = y ~ x,
          se = smooth_se,
          color = swim_palette[["primary"]],
          fill  = swim_palette[["lighter"]],
          alpha = 0.2, linewidth = 0.8, linetype = "dashed"
        )
      }

      pt_aes <- if (selectable) {
        aes(y = .data[[y_col]], tooltip = .data[["..tip.."]], data_id = as.character(activityId))
      } else {
        aes(y = .data[[y_col]], tooltip = .data[["..tip.."]])
      }
      gg <- gg + geom_point_interactive(pt_aes, color = col, size = 3)

      gg <- gg + scale_x_date(date_labels = "%d %b", date_breaks = "2 weeks")

      if (!is.null(y_formatter)) {
        gg <- gg + scale_y_continuous(labels = y_formatter)
      }

      gg <- gg +
        labs(x = NULL, y = y_lab) +
        theme_swim() +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))

      make_girafe(gg, selectable = selectable)
    })

    # Devuelve reactive con el activityId seleccionado (NULL si no hay selección)
    reactive({
      if (!selectable) return(NULL)
      sel <- input$plot_selected
      if (!is.null(sel) && nchar(sel) > 0) sel else NULL
    })
  })
}
