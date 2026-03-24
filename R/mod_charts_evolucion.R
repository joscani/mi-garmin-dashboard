#' Sub-módulo: pestaña Evolución

mod_evolucion_ui <- function(id) {
  ns <- NS(id)
  tagList(
    layout_column_wrap(
      width = 1/2,
      card(full_screen = TRUE,
        card_header("Brazadas por sesión (media, min, máx)"),
        mod_trend_chart_ui(ns("strokes_evolution"))
      ),
      card(full_screen = TRUE,
        card_header("Ritmo /100m por sesión"),
        mod_trend_chart_ui(ns("pace_evolution"))
      )
    ),
    layout_column_wrap(
      width = 1/2, class = "mt-3",
      card(full_screen = TRUE,
        card_header("SWOLF por sesión"),
        mod_trend_chart_ui(ns("swolf_session"))
      ),
      card(full_screen = TRUE,
        card_header("Distancia por sesión"),
        mod_trend_chart_ui(ns("distance_session"))
      )
    ),
    card(full_screen = TRUE, class = "mt-3",
      card_header("Tendencia de mediana de brazadas (crol)"),
      girafeOutput(ns("median_trend"), height = "380px", width = "100%")
    )
  )
}

mod_evolucion_server <- function(id, activities, sessions_ordered, laps) {
  moduleServer(id, function(input, output, session) {

    sel_strokes  <- mod_trend_chart_server("strokes_evolution",
      data        = reactive(activities() |> filter(!is.na(avg_brazadas)) |> arrange(date)),
      x_col       = "date", y_col = "avg_brazadas",
      color       = "primary", y_lab = "Brazadas por largo",
      y_min_col   = "min_brazadas", y_max_col = "max_brazadas",
      selectable  = TRUE
    )

    sel_pace <- mod_trend_chart_server("pace_evolution",
      data        = reactive(activities() |> filter(!is.na(pace_100m)) |> arrange(date)),
      x_col       = "date", y_col = "pace_100m",
      color       = "accent", y_lab = "min /100m",
      show_smooth = TRUE, smooth_se = TRUE,
      selectable  = TRUE,
      y_formatter = function(x) sapply(x, format_pace),
      tooltip_fn  = function(df) paste0(format(df$date, "%d %b %y"), "\n",
                                        sapply(df$pace_100m, format_pace), " /100m",
                                        "\n\U0001F4CC Clic para ver detalle")
    )

    sel_swolf <- mod_trend_chart_server("swolf_session",
      data        = reactive(activities() |> filter(!is.na(averageSwolf)) |> arrange(date)),
      x_col       = "date", y_col = "averageSwolf",
      color       = "success", y_lab = "SWOLF",
      show_smooth = TRUE,
      selectable  = TRUE
    )

    sel_distance <- mod_trend_chart_server("distance_session",
      data       = reactive(activities() |> filter(!is.na(distance_m)) |> arrange(date)),
      x_col      = "date", y_col = "distance_m",
      color      = "primary", y_lab = "Metros",
      show_area  = TRUE,
      selectable = TRUE,
      tooltip_fn = function(df) paste0(format(df$date, "%d %b %y"), "\n",
                                       round(df$distance_m), " m",
                                       "\n\U0001F4CC Clic para ver detalle")
    )

    # median_trend: puntos coloreados por calidad → se queda custom
    output$median_trend <- renderGirafe({
      df <- sessions_ordered() |>
        filter(!is.na(med_brazadas), !is.na(pct_buenos)) |>
        arrange(date) |>
        mutate(tip = paste0(
          format(date, "%d %b %y"),
          "\nMediana: ", round(med_brazadas, 0), " braz",
          "\nBuenos: ", pct_buenos, "%",
          "\nCalidad: ", coalesce(calidad, "—")
        ))
      req(nrow(df) > 0)

      calidad_colors <- c(
        "Muy buena" = "#15803d", "Buena" = "#0077b6",
        "Regular"   = "#b45309", "Mala"  = "#b91c1c"
      )

      gg <- ggplot(df, aes(x = date, y = med_brazadas)) +
        geom_line(color = swim_palette[["light"]], linewidth = 1) +
        geom_smooth(method = "loess", formula = y ~ x, se = TRUE,
                    color = swim_palette[["primary"]], fill = swim_palette[["lighter"]],
                    alpha = 0.2, linewidth = 1.2) +
        geom_point_interactive(
          aes(tooltip = tip, data_id = as.character(activityId),
              color = coalesce(calidad, "—")),
          size = 3.5
        ) +
        scale_color_manual(values = calidad_colors, name = "Calidad", na.value = "#94a3b8") +
        scale_x_date(date_labels = "%d %b", date_breaks = "2 weeks") +
        scale_y_continuous(breaks = scales::pretty_breaks()) +
        labs(x = NULL, y = "Mediana brazadas/largo") +
        theme_swim() +
        theme(axis.text.x = element_text(angle = 45, hjust = 1),
              legend.position = "top")

      make_girafe(gg, selectable = TRUE)
    })

    # ═══ DETALLE DE SESIÓN (modal al clicar cualquier gráfico de sesión) ═══

    selected_act_id <- reactiveVal(NULL)

    observe({ s <- sel_strokes();  if (!is.null(s)) selected_act_id(s) })
    observe({ s <- sel_pace();     if (!is.null(s)) selected_act_id(s) })
    observe({ s <- sel_swolf();    if (!is.null(s)) selected_act_id(s) })
    observe({ s <- sel_distance(); if (!is.null(s)) selected_act_id(s) })
    observe({
      sel <- input$median_trend_selected
      if (!is.null(sel) && nchar(sel) > 0) selected_act_id(sel)
    })

    output$detail_laps <- DT::renderDT({
      req(selected_act_id())
      laps() |>
        filter(activityId == as.numeric(selected_act_id()),
               lapType == "active", distance > 0) |>
        mutate(
          Largo      = row_number(),
          Estilo     = coalesce(stroke_labels[swimStroke], swimStroke),
          Brazadas   = brazadas,
          SWOLF      = swolf,
          `Dist (m)` = round(distance)
        ) |>
        select(Largo, Estilo, Brazadas, SWOLF, `Dist (m)`)
    }, options = list(pageLength = 50, dom = "t", ordering = FALSE), rownames = FALSE)

    observeEvent(selected_act_id(), {
      req(selected_act_id())
      act <- sessions_ordered() |> filter(activityId == as.numeric(selected_act_id()))
      req(nrow(act) > 0)
      act <- act[1, ]

      h <- floor(act$duration_min / 60)
      m <- round(act$duration_min %% 60)
      dur_str <- if (h > 0) sprintf("%dh %02dmin", h, m) else sprintf("%d min", m)

      hist10 <- sessions_ordered() |>
        filter(date < act$date) |> arrange(desc(date)) |> head(10)

      hist_med_braz   <- if (nrow(hist10) > 0 && any(!is.na(hist10$med_brazadas)))
        mean(hist10$med_brazadas, na.rm = TRUE) else NA
      hist_pace       <- if (nrow(hist10) > 0 && any(!is.na(hist10$pace_100m)))
        mean(hist10$pace_100m, na.rm = TRUE) else NA
      hist_pct_buenos <- if (nrow(hist10) > 0 && any(!is.na(hist10$pct_buenos)))
        mean(hist10$pct_buenos, na.rm = TRUE) else NA

      delta_tag <- function(val, ref, invert = FALSE, fmt = function(x) round(x, 1)) {
        if (is.na(val) || is.na(ref)) return(tags$span())
        diff  <- val - ref
        better <- if (invert) diff < 0 else diff > 0
        arrow  <- if (diff > 0) "\u2191" else if (diff < 0) "\u2193" else "\u2013"
        color  <- if (diff == 0) "#94a3b8" else if (better) "#15803d" else "#b91c1c"
        tags$span(
          style = paste0("font-size:0.7rem; font-weight:600; color:", color, "; margin-left:4px;"),
          paste0(arrow, " ", fmt(abs(diff)))
        )
      }

      calidad_val   <- if (is.null(act$calidad) || is.na(act$calidad)) NA else act$calidad
      calidad_color <- switch(as.character(calidad_val),
        "Muy buena" = "#15803d", "Buena" = "#0077b6",
        "Regular"   = "#b45309", "Mala"  = "#b91c1c", "#64748b")
      calidad_bg <- switch(as.character(calidad_val),
        "Muy buena" = "#dcfce7", "Buena" = "#dbeafe",
        "Regular"   = "#fef3c7", "Mala"  = "#fee2e2", "#f1f5f9")

      showModal(modalDialog(
        title = tags$span(tags$span("\U0001F3CA", style = "margin-right:8px;"),
                          paste("Sesión —", format(act$date, "%d %B %Y"))),
        size = "l", easyClose = TRUE, footer = modalButton("Cerrar"),

        tags$div(style = "text-align:center; margin-bottom:14px;",
          tags$div(
            style = paste0("display:inline-block; background:", calidad_bg, "; color:", calidad_color,
                           "; font-size:1.5rem; font-weight:800; border-radius:10px; padding:8px 28px;"),
            if (is.na(calidad_val)) "\u2014" else calidad_val
          )
        ),

        tags$div(style = "display:flex; gap:12px; flex-wrap:wrap; margin-bottom:12px;",
          tags$div(
            style = "background:#f0f4f8; border-radius:8px; padding:10px 16px; text-align:center; min-width:100px; flex:1;",
            tags$div(style = "font-size:1.25rem; font-weight:700; color:#0077b6;",
              if (is.na(act$pace_100m)) "\u2014" else format_pace(act$pace_100m),
              delta_tag(act$pace_100m, hist_pace, invert = TRUE,
                        fmt = function(x) paste0(round(x * 60), "\""))
            ),
            tags$div(style = "font-size:0.75rem; color:#64748b;",
              if (!is.na(hist_pace)) paste0("Ritmo /100m  (ref ", format_pace(hist_pace), ")")
              else "Ritmo /100m")
          ),
          tags$div(
            style = "background:#f0f4f8; border-radius:8px; padding:10px 16px; text-align:center; min-width:100px; flex:1;",
            tags$div(style = "font-size:1.25rem; font-weight:700; color:#0077b6;",
              if (is.na(act$med_brazadas)) "\u2014" else round(act$med_brazadas, 0),
              delta_tag(act$med_brazadas, hist_med_braz, invert = TRUE)
            ),
            tags$div(style = "font-size:0.75rem; color:#64748b;",
              if (!is.na(hist_med_braz)) paste0("Mediana braz  (ref ", round(hist_med_braz, 1), ")")
              else "Mediana braz")
          ),
          tags$div(
            style = "background:#f0f4f8; border-radius:8px; padding:10px 16px; text-align:center; min-width:100px; flex:1;",
            tags$div(style = "font-size:1.25rem; font-weight:700; color:#0077b6;",
              if (is.null(act$pct_buenos) || is.na(act$pct_buenos)) "\u2014"
              else paste0(act$pct_buenos, "%"),
              delta_tag(act$pct_buenos, hist_pct_buenos, invert = FALSE,
                        fmt = function(x) paste0(round(x, 1), "%"))
            ),
            tags$div(style = "font-size:0.75rem; color:#64748b;",
              if (!is.na(hist_pct_buenos)) paste0("Buenos \u226411  (ref ", round(hist_pct_buenos, 1), "%)")
              else "Buenos (\u226411)")
          ),
          tags$div(
            style = "background:#f0f4f8; border-radius:8px; padding:10px 16px; text-align:center; min-width:100px; flex:1;",
            tags$div(style = "font-size:1.25rem; font-weight:700; color:#0077b6;",
              if (is.null(act$consistencia) || is.na(act$consistencia)) "\u2014"
              else act$consistencia),
            tags$div(style = "font-size:0.75rem; color:#64748b;", "Consistencia")
          )
        ),

        {
          has_desglose <- !is.null(act$n_buenos) && !is.na(act$n_buenos)
          if (has_desglose) {
            tags$div(style = "display:flex; gap:10px; flex-wrap:wrap; margin-bottom:12px;",
              tags$div(style = "background:#dcfce7; border-radius:8px; padding:8px 16px; text-align:center; flex:1;",
                tags$div(style = "font-size:1.1rem; font-weight:700; color:#15803d;", paste0(act$n_buenos, " largos")),
                tags$div(style = "font-size:0.7rem; color:#166534;", paste0("Buenos \u226411   ", act$pct_buenos, "%"))
              ),
              tags$div(style = "background:#fef9c3; border-radius:8px; padding:8px 16px; text-align:center; flex:1;",
                tags$div(style = "font-size:1.1rem; font-weight:700; color:#92400e;", paste0(act$n_normales, " largos")),
                tags$div(style = "font-size:0.7rem; color:#78350f;", paste0("Normales 12-13   ", act$pct_normales, "%"))
              ),
              tags$div(style = "background:#fee2e2; border-radius:8px; padding:8px 16px; text-align:center; flex:1;",
                tags$div(style = "font-size:1.1rem; font-weight:700; color:#b91c1c;", paste0(act$n_caros, " largos")),
                tags$div(style = "font-size:0.7rem; color:#991b1b;", paste0("Caros \u226514   ", act$pct_caros, "%"))
              )
            )
          } else tags$div()
        },

        tags$div(style = "display:flex; gap:12px; flex-wrap:wrap; margin-bottom:16px;",
          lapply(list(
            list(v = paste0(round(act$distance_m), " m"), l = "Distancia"),
            list(v = dur_str,                              l = "Duración"),
            list(v = if (is.na(act$largos)) "\u2014" else act$largos, l = "Largos"),
            list(v = if (is.na(act$averageSwolf)) "\u2014" else act$averageSwolf, l = "SWOLF")
          ), function(x) tags$div(
            style = "background:#f8fafc; border:1px solid #e2e8f0; border-radius:8px; padding:8px 16px; text-align:center; flex:1;",
            tags$div(style = "font-size:1.1rem; font-weight:600; color:#334155;", x$v),
            tags$div(style = "font-size:0.75rem; color:#94a3b8;", x$l)
          ))
        ),

        tags$hr(),
        tags$h6("Largos", style = "color:#1a1a2e; font-weight:600; margin-bottom:8px;"),
        DT::DTOutput(session$ns("detail_laps"))
      ))
    })
  })
}
