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
    ),
    card(full_screen = TRUE, class = "mt-3",
      card_header("Brazadas vs Ritmo por largo (crol)"),
      girafeOutput(ns("scatter_pace_swolf"), height = "420px", width = "100%")
    ),
    card(full_screen = TRUE, class = "mt-3",
      card_header("Calendario de actividad"),
      plotOutput(ns("heatmap"), height = "260px", width = "100%")
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

    output$scatter_pace_swolf <- renderGirafe({
      acts <- activities() |> select(activityId, date)
      df <- laps() |>
        filter(activityId %in% acts$activityId,
               lapType == "active", swimStroke == "freestyle",
               !is.na(pace_100m), !is.na(brazadas), brazadas > 0, pace_100m < 10) |>
        left_join(acts, by = "activityId") |>
        mutate(tip = paste0("Brazadas: ", brazadas,
                            "\nRitmo: ", format_pace(pace_100m), " /100m",
                            "\n", format(date, "%d %b %Y")))
      req(nrow(df) > 0)

      gg <- ggplot(df, aes(x = brazadas, y = pace_100m)) +
        geom_boxplot(aes(group = brazadas), color = "#94a3b8", fill = "#f8fafc",
                     outlier.shape = NA, linewidth = 0.5, width = 0.6) +
        geom_point_interactive(aes(tooltip = tip),
                               color = swim_palette[["primary"]],
                               alpha = 0.5, size = 1.8,
                               position = position_jitter(width = 0.15, seed = 1)) +
        scale_x_continuous(breaks = scales::pretty_breaks()) +
        scale_y_continuous(labels = function(x) sapply(x, format_pace),
                           breaks = scales::pretty_breaks(6)) +
        labs(x = "Brazadas por largo", y = "Ritmo /100m",
             subtitle = paste0(nrow(df), " largos  ·  ",
                               format(min(df$date), "%d %b %Y"), " – ",
                               format(max(df$date), "%d %b %Y"))) +
        theme_swim()

      make_girafe(gg)
    })

    output$heatmap <- renderPlot({
      df_acts <- activities() |> filter(date >= as.Date("2026-01-01"))
      req(nrow(df_acts) > 0)

      day_labels <- c("Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom")

      date_min <- floor_date(min(df_acts$date),   "week", week_start = 1)
      date_max <- ceiling_date(max(df_acts$date), "week", week_start = 1)

      cal <- tibble(date = seq(date_min, date_max, by = "day")) |>
        mutate(
          year       = year(date),
          week_start = floor_date(date, "week", week_start = 1),
          dow        = wday(date, week_start = 1),
          dow_label  = factor(day_labels[dow], levels = rev(day_labels))
        ) |>
        left_join(
          df_acts |> group_by(date) |>
            summarise(dist = sum(distance_m, na.rm = TRUE), .groups = "drop"),
          by = "date"
        ) |>
        replace_na(list(dist = 0))

      ggplot(cal, aes(x = week_start, y = dow_label, fill = dist)) +
        geom_tile(color = "white", linewidth = 0.35) +
        facet_wrap(~year, ncol = 1, scales = "free_x") +
        scale_fill_stepsn(
          colours = c("#ebedf0", "#9be9a8", "#40c463", "#30a14e", "#216e39"),
          breaks  = c(0, 1, 1000, 2000, 3000),
          values  = scales::rescale(c(0, 1, 1000, 2000, 3000)),
          labels  = c("0", "", "1 km", "2 km", "3 km"),
          name    = NULL,
          guide   = guide_colorsteps(barwidth = unit(6, "cm"), barheight = unit(0.4, "cm"))
        ) +
        scale_x_date(date_labels = "%b", date_breaks = "1 month") +
        labs(x = NULL, y = NULL) +
        theme_swim(base_size = 11) +
        theme(
          panel.grid      = element_blank(),
          axis.text.x     = element_text(angle = 0, hjust = 0.5),
          strip.text      = element_text(face = "bold", size = rel(0.9)),
          legend.position = "bottom",
          legend.key.width = unit(2, "cm")
        )
    })

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
