#' Sub-módulo: pestaña Resumen (agregados por periodo)

mod_resumen_ui <- function(id) {
  ns <- NS(id)
  tagList(
    layout_column_wrap(
      width = 1/2,
      card(full_screen = TRUE,
        card_header("Distancia por periodo"),
        mod_trend_chart_ui(ns("distance"))
      ),
      card(full_screen = TRUE,
        card_header("Brazadas media por periodo"),
        mod_trend_chart_ui(ns("strokes_period"))
      )
    ),
    layout_column_wrap(
      width = 1/2, class = "mt-3",
      card(full_screen = TRUE,
        card_header("Frecuencia cardíaca"),
        girafeOutput(ns("hr"), height = "480px", width = "100%")
      ),
      card(full_screen = TRUE,
        card_header("SWOLF medio por periodo"),
        mod_trend_chart_ui(ns("swolf_trend"))
      )
    ),
    card(full_screen = TRUE, class = "mt-3",
      card_header("Evolución de calidad de sesiones por periodo (% crol)"),
      girafeOutput(ns("quality_period"), height = "380px", width = "100%")
    )
  )
}

mod_resumen_server <- function(id, summary_data, activities, laps, aggregation) {
  moduleServer(id, function(input, output, session) {

    mod_trend_chart_server("distance",
      data       = reactive(summary_data() |>
                     mutate(tip = paste0(format(period_date, "%d %b %y"), "\n",
                                         round(total_distance_m), " m"))),
      x_col      = "period_date", y_col = "total_distance_m",
      color      = "primary", y_lab = "Metros",
      show_area  = TRUE,
      tooltip_fn = function(df) paste0(format(df$period_date, "%d %b %y"), "\n",
                                       round(df$total_distance_m), " m")
    )

    mod_trend_chart_server("strokes_period",
      data        = reactive(summary_data() |> filter(!is.na(avg_brazadas))),
      x_col       = "period_date", y_col = "avg_brazadas",
      color       = "primary", y_lab = "Brazadas media por largo",
      show_smooth = TRUE
    )

    mod_trend_chart_server("swolf_trend",
      data        = reactive(summary_data() |> filter(!is.na(avg_swolf))),
      x_col       = "period_date", y_col = "avg_swolf",
      color       = "success", y_lab = "SWOLF medio",
      show_smooth = TRUE
    )

    # hr: dos series (media + máx) → se queda custom
    output$hr <- renderGirafe({
      df <- activities() |> filter(!is.na(averageHR)) |> arrange(date) |>
        mutate(tip_avg = paste0(format(date, "%d %b %y"), "\nFC media: ", round(averageHR), " bpm"),
               tip_max = paste0(format(date, "%d %b %y"), "\nFC máx: ",  round(maxHR),     " bpm"))
      req(nrow(df) > 0)

      gg <- ggplot(df, aes(x = date)) +
        geom_ribbon(aes(ymin = averageHR, ymax = maxHR),
                    fill = swim_palette["heart_avg"], alpha = 0.08) +
        geom_line(aes(y = averageHR), color = swim_palette["heart_avg"], linewidth = 1.1) +
        geom_point_interactive(aes(y = averageHR, tooltip = tip_avg),
                               color = swim_palette["heart_avg"], size = 2.5) +
        geom_line(aes(y = maxHR), color = swim_palette["heart_max"],
                  linetype = "dashed", linewidth = 0.8) +
        geom_point_interactive(aes(y = maxHR, tooltip = tip_max),
                               color = swim_palette["heart_max"], size = 2) +
        scale_x_date(date_labels = "%d %b", date_breaks = "2 weeks") +
        labs(x = NULL, y = "BPM") +
        theme_swim() +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))

      make_girafe(gg)
    })

    # quality_period: multi-serie por calidad → se queda custom
    quality_colors <- c(
      "Muy buena" = "#06d6a0", "Buena" = "#0077b6",
      "Regular"   = "#ffd166", "Mala"  = "#e63946"
    )

    output$quality_period <- renderGirafe({
      df <- quality_by_period(activities(), laps(), period = aggregation())
      req(nrow(df) > 0)

      gg <- ggplot(df, aes(x = period_date, y = pct, color = calidad, group = calidad)) +
        geom_line(linewidth = 1.2) +
        geom_point_interactive(
          aes(tooltip = paste0(calidad, ": ", pct, "%\n(", n, " sesiones)"),
              data_id = paste0(period_date, "_", calidad)),
          size = 3
        ) +
        scale_color_manual(values = quality_colors) +
        scale_x_date(date_labels = "%d %b", date_breaks = "2 weeks") +
        scale_y_continuous(labels = function(x) paste0(x, "%"), limits = c(0, 100)) +
        labs(x = NULL, y = "% sesiones", color = NULL) +
        theme_swim() +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))

      make_girafe(gg)
    })
  })
}
