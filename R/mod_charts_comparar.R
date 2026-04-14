#' Sub-módulo: pestaña Comparar sesiones

mod_comparar_ui <- function(id) {
  ns <- NS(id)
  tagList(
    # ── Selectores ──────────────────────────────────────────────────────────
    card(
      div(style = "padding:12px 16px;",
        layout_column_wrap(
          width = 1/2,
          div(
            tags$p(style = "font-weight:700; color:#0077b6; margin:0 0 4px;",
                   "\u25CF  Sesi\u00f3n A"),
            selectInput(ns("session_a"), NULL, choices = NULL, width = "100%")
          ),
          div(
            tags$p(style = "font-weight:700; color:#e63946; margin:0 0 4px;",
                   "\u25CF  Sesi\u00f3n B"),
            selectInput(ns("session_b"), NULL, choices = NULL, width = "100%")
          )
        ),
        uiOutput(ns("session_headers"))
      )
    ),
    # ── M\u00e9tricas resumidas ────────────────────────────────────────────────────
    uiOutput(ns("stats_compare")),
    # ── Distribuciones ──────────────────────────────────────────────────────
    layout_column_wrap(
      width = 1/2, class = "mt-3",
      card(full_screen = TRUE,
        card_header("Distribución de brazadas por largo"),
        girafeOutput(ns("dist_strokes"), height = "340px", width = "100%")
      ),
      card(full_screen = TRUE,
        card_header("Distribución de SWOLF por largo"),
        girafeOutput(ns("dist_swolf"), height = "340px", width = "100%")
      )
    )
  )
}

mod_comparar_server <- function(id, sessions_ordered, active_laps) {
  moduleServer(id, function(input, output, session) {

    # Etiqueta compacta para el selector
    make_label <- function(row) {
      cal <- if (!is.null(row$calidad) && !is.na(row$calidad)) paste0(" \u00b7 ", row$calidad) else ""
      pace <- if (!is.null(row$pace_100m) && !is.na(row$pace_100m))
        paste0(" \u00b7 ", format_pace(row$pace_100m), "/100m") else ""
      paste0(format(row$date, "%d %b %Y"), "  \u00b7  ", round(row$distance_m), "m", cal, pace)
    }

    observeEvent(sessions_ordered(), {
      df <- sessions_ordered() |> arrange(desc(date))
      choices <- setNames(
        as.character(df$activityId),
        vapply(seq_len(nrow(df)), function(i) make_label(df[i, ]), character(1))
      )
      updateSelectInput(session, "session_a", choices = choices,
                        selected = if (length(choices) >= 1) choices[[1]] else NULL)
      updateSelectInput(session, "session_b", choices = choices,
                        selected = if (length(choices) >= 2) choices[[2]] else NULL)
    })

    get_session <- function(id_str) {
      sessions_ordered() |> filter(activityId == as.numeric(id_str)) |> head(1)
    }

    get_laps <- function(id_str) {
      active_laps() |>
        filter(activityId == as.numeric(id_str)) |>
        mutate(largo = row_number())
    }

    fmt_dur <- function(x) {
      if (is.na(x) || is.null(x)) return("\u2014")
      h <- floor(x / 60); m <- round(x %% 60)
      if (h > 0) sprintf("%dh %02dmin", h, m) else sprintf("%d min", m)
    }

    # Cabeceras de sesión debajo de los selectores
    output$session_headers <- renderUI({
      req(input$session_a, input$session_b)
      a <- get_session(input$session_a)
      b <- get_session(input$session_b)
      req(nrow(a) > 0, nrow(b) > 0)

      cal_color <- function(cal) switch(coalesce(cal, ""),
        "Muy buena" = "#15803d", "Buena" = "#0077b6",
        "Regular" = "#b45309", "Mala" = "#b91c1c", "#64748b")
      cal_bg <- function(cal) switch(coalesce(cal, ""),
        "Muy buena" = "#dcfce7", "Buena" = "#dbeafe",
        "Regular" = "#fef3c7", "Mala" = "#fee2e2", "#f1f5f9")

      badge <- function(cal) {
        if (is.na(cal) || is.null(cal)) return(tags$span())
        tags$span(
          style = paste0("background:", cal_bg(cal), "; color:", cal_color(cal),
                         "; font-size:0.78rem; font-weight:700; padding:2px 10px;",
                         " border-radius:10px; margin-left:6px;"),
          cal
        )
      }

      tags$div(style = "display:flex; gap:8px; margin-top:10px;",
        tags$div(style = "flex:1; background:#eff6ff; border-radius:8px; padding:8px 12px;",
          tags$span(style = "font-weight:700; color:#0077b6;",
                    format(a$date, "%d %B %Y")),
          badge(a$calidad),
          tags$div(style = "font-size:0.8rem; color:#64748b; margin-top:2px;",
            paste0(round(a$distance_m), " m  \u00b7  ", fmt_dur(a$duration_min), " activo",
                   if (!is.na(a$pace_100m)) paste0("  \u00b7  ", format_pace(a$pace_100m), " /100m") else ""))
        ),
        tags$div(style = "flex:1; background:#fff1f2; border-radius:8px; padding:8px 12px;",
          tags$span(style = "font-weight:700; color:#e63946;",
                    format(b$date, "%d %B %Y")),
          badge(b$calidad),
          tags$div(style = "font-size:0.8rem; color:#64748b; margin-top:2px;",
            paste0(round(b$distance_m), " m  \u00b7  ", fmt_dur(b$duration_min), " activo",
                   if (!is.na(b$pace_100m)) paste0("  \u00b7  ", format_pace(b$pace_100m), " /100m") else ""))
        )
      )
    })

    # ── Tabla comparativa ────────────────────────────────────────────────────
    output$stats_compare <- renderUI({
      req(input$session_a, input$session_b)
      a <- get_session(input$session_a)
      b <- get_session(input$session_b)
      req(nrow(a) > 0, nrow(b) > 0)

      # flechas para indicar quién gana (lower_is_better: TRUE = menor es mejor)
      delta_arrow <- function(va, vb, lower_is_better = FALSE) {
        if (is.na(va) || is.na(vb) || va == vb) return(list(a = "", b = ""))
        a_wins <- if (lower_is_better) va < vb else va > vb
        list(
          a = if (a_wins)  tags$span(style = "color:#15803d; font-size:0.8rem;", " \u2191")
              else         tags$span(style = "color:#b91c1c; font-size:0.8rem;", " \u2193"),
          b = if (!a_wins) tags$span(style = "color:#15803d; font-size:0.8rem;", " \u2191")
              else         tags$span(style = "color:#b91c1c; font-size:0.8rem;", " \u2193")
        )
      }

      row_cmp <- function(label, va_txt, vb_txt, arrow_a = "", arrow_b = "") {
        tags$div(
          style = "display:flex; gap:8px; align-items:center; padding:7px 0; border-bottom:1px solid #f1f5f9;",
          tags$div(style = "width:120px; font-size:0.82rem; color:#64748b; flex-shrink:0;", label),
          tags$div(style = "flex:1; text-align:center; font-weight:700; color:#0077b6; font-size:1rem;",
                   va_txt, arrow_a),
          tags$div(style = "flex:1; text-align:center; font-weight:700; color:#e63946; font-size:1rem;",
                   vb_txt, arrow_b)
        )
      }

      arr_pace  <- delta_arrow(a$pace_100m,    b$pace_100m,    lower_is_better = TRUE)
      arr_swolf <- delta_arrow(a$averageSwolf, b$averageSwolf, lower_is_better = TRUE)
      arr_braz  <- delta_arrow(a$med_brazadas, b$med_brazadas, lower_is_better = TRUE)
      arr_bueno <- delta_arrow(
        if (!is.null(a$pct_buenos)) a$pct_buenos else NA,
        if (!is.null(b$pct_buenos)) b$pct_buenos else NA,
        lower_is_better = FALSE)

      card(class = "mt-3",
        card_header("M\u00e9tricas comparadas"),
        div(style = "padding:4px 16px 12px;",
          tags$div(
            style = "display:flex; gap:8px; padding:8px 0 10px; border-bottom:2px solid #e2e8f0;",
            tags$div(style = "width:120px; flex-shrink:0;"),
            tags$div(style = "flex:1; text-align:center; font-weight:800; color:#0077b6; font-size:0.85rem;", "Sesi\u00f3n A"),
            tags$div(style = "flex:1; text-align:center; font-weight:800; color:#e63946; font-size:0.85rem;", "Sesi\u00f3n B")
          ),
          row_cmp("Distancia",
            if (is.na(a$distance_m)) "\u2014" else paste0(round(a$distance_m), " m"),
            if (is.na(b$distance_m)) "\u2014" else paste0(round(b$distance_m), " m")),
          row_cmp("T. activo",  fmt_dur(a$duration_min),       fmt_dur(b$duration_min)),
          row_cmp("T. total",   fmt_dur(a$duration_total_min), fmt_dur(b$duration_total_min)),
          row_cmp("Ritmo /100m",
            if (is.na(a$pace_100m)) "\u2014" else format_pace(a$pace_100m),
            if (is.na(b$pace_100m)) "\u2014" else format_pace(b$pace_100m),
            arr_pace$a, arr_pace$b),
          row_cmp("SWOLF",
            if (is.na(a$averageSwolf)) "\u2014" else as.character(a$averageSwolf),
            if (is.na(b$averageSwolf)) "\u2014" else as.character(b$averageSwolf),
            arr_swolf$a, arr_swolf$b),
          row_cmp("Braz. medianas",
            if (is.na(a$med_brazadas)) "\u2014" else as.character(round(a$med_brazadas)),
            if (is.na(b$med_brazadas)) "\u2014" else as.character(round(b$med_brazadas)),
            arr_braz$a, arr_braz$b),
          row_cmp("Buenos \u226411",
            if (is.null(a$pct_buenos) || is.na(a$pct_buenos)) "\u2014" else paste0(a$pct_buenos, "%"),
            if (is.null(b$pct_buenos) || is.na(b$pct_buenos)) "\u2014" else paste0(b$pct_buenos, "%"),
            arr_bueno$a, arr_bueno$b),
          row_cmp("Largos",
            if (is.na(a$largos)) "\u2014" else as.character(a$largos),
            if (is.na(b$largos)) "\u2014" else as.character(b$largos)),
          row_cmp("Calidad",
            if (is.null(a$calidad) || is.na(a$calidad)) "\u2014" else a$calidad,
            if (is.null(b$calidad) || is.na(b$calidad)) "\u2014" else b$calidad)
        )
      )
    })

    # ── Datos de largos combinados ────────────────────────────────────────────
    laps_combined <- reactive({
      req(input$session_a, input$session_b)
      a_date <- get_session(input$session_a)$date
      b_date <- get_session(input$session_b)$date
      la <- get_laps(input$session_a) |>
        mutate(sesion = paste0("A \u2014 ", format(a_date, "%d %b %Y")))
      lb <- get_laps(input$session_b) |>
        mutate(sesion = paste0("B \u2014 ", format(b_date, "%d %b %Y")))
      bind_rows(la, lb)
    })

    color_map <- reactive({
      req(input$session_a, input$session_b)
      a_date <- get_session(input$session_a)$date
      b_date <- get_session(input$session_b)$date
      c(
        setNames("#0077b6", paste0("A \u2014 ", format(a_date, "%d %b %Y"))),
        setNames("#e63946", paste0("B \u2014 ", format(b_date, "%d %b %Y")))
      )
    })

    # ── Boxplot brazadas ──────────────────────────────────────────────────────
    output$dist_strokes <- renderGirafe({
      df <- laps_combined() |> filter(!is.na(brazadas))
      req(nrow(df) > 0)
      cm <- color_map()

      gg <- ggplot(df, aes(x = sesion, y = brazadas, fill = sesion, color = sesion)) +
        geom_boxplot(alpha = 0.25, outlier.shape = NA, linewidth = 0.8, width = 0.5) +
        geom_jitter_interactive(
          aes(tooltip = paste0(sesion, "\nLargo ", largo, ": ", brazadas, " braz")),
          width = 0.15, alpha = 0.6, size = 2
        ) +
        scale_fill_manual(values  = cm, guide = "none") +
        scale_color_manual(values = cm, guide = "none") +
        scale_y_continuous(breaks = scales::pretty_breaks()) +
        labs(x = NULL, y = "Brazadas por largo") +
        theme_swim()

      make_girafe(gg)
    })

    # ── Boxplot SWOLF ─────────────────────────────────────────────────────────
    output$dist_swolf <- renderGirafe({
      df <- laps_combined() |> filter(!is.na(swolf))
      req(nrow(df) > 0)
      cm <- color_map()

      gg <- ggplot(df, aes(x = sesion, y = swolf, fill = sesion, color = sesion)) +
        geom_boxplot(alpha = 0.25, outlier.shape = NA, linewidth = 0.8, width = 0.5) +
        geom_jitter_interactive(
          aes(tooltip = paste0(sesion, "\nLargo ", largo, ": ", swolf, " SWOLF")),
          width = 0.15, alpha = 0.6, size = 2
        ) +
        scale_fill_manual(values  = cm, guide = "none") +
        scale_color_manual(values = cm, guide = "none") +
        scale_y_continuous(breaks = scales::pretty_breaks()) +
        labs(x = NULL, y = "SWOLF") +
        theme_swim()

      make_girafe(gg)
    })

  })
}
