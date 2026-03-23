#' Módulo de gráficos - ggplot2 + ggiraph

library(ggplot2)
library(ggiraph)
library(tidyr)
library(DT)

CHART_W <- 10
CHART_H <- 5

gi_opts    <- opts_sizing(rescale = TRUE, width = 1)
gi_hover   <- opts_hover(css = "fill-opacity:0.9; stroke-width:2;")
gi_tooltip <- opts_tooltip(
  css = "background:white; border:1px solid #cbd5e1; border-radius:8px; padding:8px 12px; font-size:12px; color:#1a1a2e; box-shadow:0 2px 8px rgba(0,0,0,0.1);",
  opacity = 1
)

gi_select <- opts_selection(type = "single", css = "fill:#ffd166;stroke:#ffd166;r:5px;")

make_girafe <- function(gg, selectable = FALSE) {
  opts <- list(gi_opts, gi_hover, gi_tooltip)
  if (selectable) opts <- c(opts, list(gi_select))
  girafe(ggobj = gg, width_svg = CHART_W, height_svg = CHART_H, options = opts)
}

# ── UI ──────────────────────────────────────────────────────────────────────

mod_charts_ui <- function(id) {
  ns <- NS(id)
  list(
    evolucion = tagList(
      layout_column_wrap(
        width = 1/2,
        card(full_screen = TRUE,
          card_header("Brazadas por sesión (media, min, máx)"),
          girafeOutput(ns("strokes_evolution"), height = "480px", width = "100%")
        ),
        card(full_screen = TRUE,
          card_header("Ritmo /100m por sesión"),
          girafeOutput(ns("pace_evolution"), height = "480px", width = "100%")
        )
      ),
      layout_column_wrap(
        width = 1/2, class = "mt-3",
        card(full_screen = TRUE,
          card_header("SWOLF por sesión"),
          girafeOutput(ns("swolf_session"), height = "480px", width = "100%")
        ),
        card(full_screen = TRUE,
          card_header("Distancia por sesión"),
          girafeOutput(ns("distance_session"), height = "480px", width = "100%")
        )
      )
    ),

    laps = tagList(
      card(full_screen = FALSE,
        div(
          style = "display:flex; align-items:center; justify-content:space-between; padding:8px 4px;",
          actionButton(ns("prev_session"), label = NULL, icon = icon("chevron-left"),
                       class = "btn btn-outline-secondary btn-sm"),
          uiOutput(ns("session_title")),
          actionButton(ns("next_session"), label = NULL, icon = icon("chevron-right"),
                       class = "btn btn-outline-secondary btn-sm")
        )
      ),
      layout_column_wrap(
        width = 1/2,
        card(full_screen = TRUE,
          card_header("Brazadas por largo"),
          girafeOutput(ns("strokes_range"), height = "480px", width = "100%")
        ),
        card(full_screen = TRUE,
          card_header("SWOLF por largo"),
          girafeOutput(ns("swolf_range"), height = "480px", width = "100%")
        )
      ),
      card(full_screen = TRUE, class = "mt-3",
        card_header("Brazadas vs SWOLF por estilo (sesión seleccionada)"),
        girafeOutput(ns("scatter"), height = "480px", width = "100%")
      )
    ),

    resumen = tagList(
      layout_column_wrap(
        width = 1/2,
        card(full_screen = TRUE,
          card_header("Distancia por periodo"),
          girafeOutput(ns("distance"), height = "480px", width = "100%")
        ),
        card(full_screen = TRUE,
          card_header("Brazadas media por periodo"),
          girafeOutput(ns("strokes_period"), height = "480px", width = "100%")
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
          girafeOutput(ns("swolf_trend"), height = "480px", width = "100%")
        )
      ),
      card(full_screen = TRUE, class = "mt-3",
        card_header("Evolución de calidad de sesiones por periodo (% crol)"),
        girafeOutput(ns("quality_period"), height = "380px", width = "100%")
      )
    )
  )
}

# ── Server ──────────────────────────────────────────────────────────────────

mod_charts_server <- function(id, summary_data, activities, laps, stroke_filter, aggregation) {
  moduleServer(id, function(input, output, session) {

    active_laps <- reactive({
      al <- filter_active_laps(laps())
      sf <- stroke_filter()
      if (!is.null(sf) && sf != "all") al <- al |> filter(swimStroke == sf)
      al
    })

    # Helper: range plot (media + ribbon min/max)
    # Si el df tiene activityId, los puntos son clicables para ver detalle de sesión
    range_plot <- function(df, y_mean, y_min, y_max, y_lab, color, tip_unit = "") {
      has_id <- "activityId" %in% names(df)
      tip_suffix <- if (has_id) "\n\U0001F4CC Clic para ver detalle" else ""

      pt_aes <- if (has_id) {
        aes(y = .data[[y_mean]], data_id = as.character(activityId),
            tooltip = paste0(format(date, "%d %b %y"),
              "\nMedia: ", round(.data[[y_mean]], 1), tip_unit,
              "\nMin: ", round(.data[[y_min]], 1),
              "\nMáx: ", round(.data[[y_max]], 1), tip_suffix))
      } else {
        aes(y = .data[[y_mean]],
            tooltip = paste0(format(date, "%d %b %y"),
              "\nMedia: ", round(.data[[y_mean]], 1), tip_unit,
              "\nMin: ", round(.data[[y_min]], 1),
              "\nMáx: ", round(.data[[y_max]], 1)))
      }

      gg <- ggplot(df, aes(x = date)) +
        geom_ribbon(aes(ymin = .data[[y_min]], ymax = .data[[y_max]]),
                    fill = color, alpha = 0.15) +
        geom_line(aes(y = .data[[y_mean]]), color = color, linewidth = 1.3) +
        geom_point_interactive(pt_aes, color = color, size = 3) +
        scale_x_date(date_labels = "%d %b", date_breaks = "2 weeks") +
        labs(x = NULL, y = y_lab) +
        theme_swim() +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))
      make_girafe(gg, selectable = has_id)
    }

    # ═══ EVOLUCIÓN ═══

    output$strokes_evolution <- renderGirafe({
      df <- activities() |> filter(!is.na(avg_brazadas)) |> arrange(date)
      req(nrow(df) > 0)
      range_plot(df, "avg_brazadas", "min_brazadas", "max_brazadas",
                 "Brazadas por largo", swim_palette[["primary"]])
    })

    output$pace_evolution <- renderGirafe({
      df <- activities() |> filter(!is.na(pace_100m)) |> arrange(date) |>
        mutate(pace_label = format_pace(pace_100m),
               tip = paste0(format(date, "%d %b %y"), "\n", pace_label, " /100m"))

      req(nrow(df) > 0)

      gg <- ggplot(df, aes(x = date, y = pace_100m)) +
        geom_line(color = swim_palette["accent"], linewidth = 1.3) +
        geom_point_interactive(aes(tooltip = tip, data_id = as.character(activityId)),
                               color = swim_palette["primary"], size = 3) +
        geom_smooth(method = "loess", formula = y ~ x, se = TRUE,
                    color = swim_palette["primary"], fill = swim_palette["lighter"],
                    alpha = 0.2, linewidth = 0.8, linetype = "dashed") +
        scale_x_date(date_labels = "%d %b", date_breaks = "2 weeks") +
        scale_y_continuous(labels = function(x) sapply(x, format_pace)) +
        labs(x = NULL, y = "min /100m") +
        theme_swim() +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))

      make_girafe(gg, selectable = TRUE)
    })

    output$swolf_session <- renderGirafe({
      df <- activities() |> filter(!is.na(averageSwolf)) |> arrange(date) |>
        mutate(tip = paste0(format(date, "%d %b %y"), "\nSWOLF: ", averageSwolf))
      req(nrow(df) > 0)

      gg <- ggplot(df, aes(x = date, y = averageSwolf)) +
        geom_line(color = swim_palette["success"], linewidth = 1.3) +
        geom_point_interactive(aes(tooltip = tip, data_id = as.character(activityId)),
                               color = swim_palette["success"], size = 3) +
        geom_smooth(method = "loess", formula = y ~ x, se = FALSE,
                    color = swim_palette["primary"], linewidth = 0.8, linetype = "dashed") +
        scale_x_date(date_labels = "%d %b", date_breaks = "2 weeks") +
        labs(x = NULL, y = "SWOLF") +
        theme_swim() +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))

      make_girafe(gg, selectable = TRUE)
    })

    output$distance_session <- renderGirafe({
      df <- activities() |> filter(!is.na(distance_m)) |> arrange(date) |>
        mutate(tip = paste0(format(date, "%d %b %y"), "\n", round(distance_m), " m"))
      req(nrow(df) > 0)

      gg <- ggplot(df, aes(x = date, y = distance_m)) +
        geom_area(fill = swim_palette["light"], alpha = 0.2) +
        geom_line(color = swim_palette["primary"], linewidth = 1.3) +
        geom_point_interactive(aes(tooltip = tip, data_id = as.character(activityId)),
                               color = swim_palette["primary"], size = 3) +
        scale_x_date(date_labels = "%d %b", date_breaks = "2 weeks") +
        labs(x = NULL, y = "Metros") +
        theme_swim() +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))

      make_girafe(gg, selectable = TRUE)
    })

    # ═══ POR LARGO ═══

    # Calidad por sesión (solo crol)
    session_quality <- reactive({
      compute_session_quality(laps())
    })

    # Sesiones ordenadas por fecha desc
    sessions_ordered <- reactive({
      activities() |>
        left_join(session_quality(), by = "activityId") |>
        arrange(desc(date))
    })

    # Índice de la sesión actual (1 = más reciente)
    session_idx <- reactiveVal(1)

    # Resetear al índice 1 cuando cambia el filtro de fechas
    observeEvent(activities(), { session_idx(1) })

    observeEvent(input$prev_session, {
      n <- nrow(sessions_ordered())
      session_idx(min(session_idx() + 1, n))
    })

    observeEvent(input$next_session, {
      session_idx(max(session_idx() - 1, 1))
    })

    current_session <- reactive({
      df <- sessions_ordered()
      req(nrow(df) > 0)
      df[session_idx(), ]
    })

    output$session_title <- renderUI({
      act <- current_session()
      n   <- nrow(sessions_ordered())
      idx <- session_idx()
      h <- floor(act$duration_min / 60)
      m <- round(act$duration_min %% 60)
      dur_str <- if (h > 0) sprintf("%dh %02dmin", h, m) else sprintf("%d min", m)

      calidad_color <- switch(coalesce(act$calidad, ""),
        "Muy buena" = "#06d6a0", "Buena" = "#0077b6",
        "Regular"   = "#ffd166", "Mala"  = "#e63946", "#94a3b8"
      )

      has_quality <- !is.na(act$calidad) && !is.null(act$n_crol) && act$n_crol > 0

      tags$div(
        style = "text-align:center;",
        tags$div(style = "font-weight:700; font-size:1rem; color:#0077b6;",
                 format(act$date, "%d %B %Y")),
        tags$div(style = "font-size:0.8rem; color:#64748b;",
          paste0(round(act$distance_m), " m · ", dur_str,
                 if (!is.na(act$averageSwolf)) paste0(" · SWOLF ", act$averageSwolf) else "",
                 if (!is.na(act$pace_100m))    paste0(" · ", format_pace(act$pace_100m), " /100m") else "")
        ),
        if (has_quality) tags$div(
          style = "margin-top:4px; display:flex; justify-content:center; align-items:center; gap:10px; flex-wrap:wrap;",
          tags$span(
            style = paste0("background:", calidad_color, "22; color:", calidad_color,
                           "; font-weight:700; font-size:0.82rem; padding:2px 10px; border-radius:12px; border:1px solid ", calidad_color, ";"),
            act$calidad
          ),
          tags$span(style = "font-size:0.75rem; color:#64748b;",
            paste0("\u226412 braz: ", act$pct_le11, "% · ",
                   "\u226413 braz: ", act$pct_le13, "% · ",
                   "\u226514 braz: ", act$pct_ge15, "%")
          )
        ),
        tags$div(style = "font-size:0.75rem; color:#94a3b8; margin-top:2px;",
                 paste0(idx, " / ", n))
      )
    })

    session_laps <- reactive({
      act <- current_session()
      active_laps() |>
        filter(activityId == act$activityId) |>
        mutate(
          largo  = row_number(),
          estilo = coalesce(stroke_labels[swimStroke], swimStroke)
        )
    })

    lap_plot <- function(df, y_col, y_lab, color_col = "estilo") {
      act <- current_session()
      fecha_str <- format(act$date, "%d %B %Y")
      h <- floor(act$duration_min / 60)
      m <- round(act$duration_min %% 60)
      dur_str <- if (h > 0) sprintf("%dh %02dmin", h, m) else sprintf("%d min", m)

      title_str <- paste0(fecha_str, "  ·  ", round(act$distance_m), " m  ·  ", dur_str,
        if (!is.na(act$pace_100m)) paste0("  ·  ", format_pace(act$pace_100m), " /100m") else "")

      subtitle_str <- if (!is.na(act$calidad) && !is.null(act$n_crol) && act$n_crol > 0) {
        paste0("Sesión ", act$calidad,
               "  |  \u226411: ", act$pct_le11, "%",
               "  \u226413: ", act$pct_le13, "%",
               "  \u226514: ", act$pct_ge15, "%  (crol)")
      } else NULL

      gg <- ggplot(df, aes(x = largo, y = .data[[y_col]], color = .data[[color_col]])) +
        geom_line(linewidth = 1, show.legend = FALSE) +
        geom_point_interactive(
          aes(tooltip = paste0("Largo ", largo, "\n", y_lab, ": ", round(.data[[y_col]], 1),
                               "\nEstilo: ", estilo)),
          size = 3
        ) +
        scale_x_continuous(breaks = scales::pretty_breaks()) +
        scale_color_manual(values = c(
          "Crol" = swim_palette[["primary"]], "Espalda" = swim_palette[["success"]],
          "Braza" = swim_palette[["warning"]], "Mariposa" = swim_palette[["heart_avg"]],
          "Mixto" = swim_palette[["lighter"]], "Técnica" = swim_palette[["text_soft"]]
        )) +
        labs(x = "Largo", y = y_lab, title = title_str, subtitle = subtitle_str) +
        theme_swim()
      make_girafe(gg)
    }

    output$strokes_range <- renderGirafe({
      df <- session_laps() |> filter(!is.na(brazadas))
      req(nrow(df) > 0)
      lap_plot(df, "brazadas", "Brazadas")
    })

    output$swolf_range <- renderGirafe({
      df <- session_laps() |> filter(!is.na(swolf))
      req(nrow(df) > 0)
      lap_plot(df, "swolf", "SWOLF")
    })

    output$scatter <- renderGirafe({
      sd <- session_laps() |>
        filter(!is.na(brazadas), !is.na(swolf)) |>
        mutate(label = coalesce(stroke_labels[swimStroke], swimStroke))
      req(nrow(sd) > 0)

      gg <- ggplot(sd, aes(x = brazadas, y = swolf, color = label)) +
        geom_jitter_interactive(
          aes(tooltip = paste0(label, "\nBrazadas: ", brazadas, "\nSWOLF: ", swolf)),
          alpha = 0.5, size = 2.5, width = 0.3
        ) +
        scale_color_manual(values = c(
          "Crol" = swim_palette[["primary"]], "Espalda" = swim_palette[["success"]],
          "Braza" = swim_palette[["warning"]], "Mariposa" = swim_palette[["heart_avg"]],
          "Mixto" = swim_palette[["lighter"]], "Técnica" = swim_palette[["text_soft"]]
        )) +
        labs(x = "Brazadas por largo", y = "SWOLF") +
        theme_swim()

      make_girafe(gg)
    })


    # ═══ RESUMEN ═══

    quality_colors <- c(
      "Muy buena" = "#06d6a0",
      "Buena"     = "#0077b6",
      "Regular"   = "#ffd166",
      "Mala"      = "#e63946"
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

    output$distance <- renderGirafe({
      df <- summary_data()
      req(nrow(df) > 0)
      df <- df |> mutate(tip = paste0(format(period_date, "%d %b %y"), "\n", round(total_distance_m), " m"))

      gg <- ggplot(df, aes(x = period_date, y = total_distance_m)) +
        geom_area(fill = swim_palette["primary"], alpha = 0.12) +
        geom_line(color = swim_palette["primary"], linewidth = 1.2) +
        geom_point_interactive(aes(tooltip = tip), color = swim_palette["primary"], size = 3.5) +
        scale_x_date(date_labels = "%d %b", date_breaks = "2 weeks") +
        labs(x = NULL, y = "Metros") +
        theme_swim() +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))

      make_girafe(gg)
    })

    output$strokes_period <- renderGirafe({
      df <- summary_data() |> filter(!is.na(avg_brazadas))
      req(nrow(df) > 0)
      df <- df |> mutate(tip = paste0(format(period_date, "%d %b %y"), "\nBrazadas/largo: ", round(avg_brazadas, 1)))

      gg <- ggplot(df, aes(x = period_date, y = avg_brazadas)) +
        geom_line(color = swim_palette["primary"], linewidth = 1.3) +
        geom_point_interactive(aes(tooltip = tip), color = swim_palette["primary"], size = 3.5) +
        geom_smooth(method = "loess", formula = y ~ x, se = FALSE,
                    color = swim_palette["accent"], linewidth = 0.8, linetype = "dashed") +
        scale_x_date(date_labels = "%d %b", date_breaks = "2 weeks") +
        labs(x = NULL, y = "Brazadas media por largo") +
        theme_swim() +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))

      make_girafe(gg)
    })

    output$hr <- renderGirafe({
      df <- activities() |> filter(!is.na(averageHR)) |> arrange(date) |>
        mutate(tip_avg = paste0(format(date, "%d %b %y"), "\nFC media: ", round(averageHR), " bpm"),
               tip_max = paste0(format(date, "%d %b %y"), "\nFC máx: ", round(maxHR), " bpm"))
      req(nrow(df) > 0)

      gg <- ggplot(df, aes(x = date)) +
        geom_ribbon(aes(ymin = averageHR, ymax = maxHR), fill = swim_palette["heart_avg"], alpha = 0.08) +
        geom_line(aes(y = averageHR), color = swim_palette["heart_avg"], linewidth = 1.1) +
        geom_point_interactive(aes(y = averageHR, tooltip = tip_avg), color = swim_palette["heart_avg"], size = 2.5) +
        geom_line(aes(y = maxHR), color = swim_palette["heart_max"], linetype = "dashed", linewidth = 0.8) +
        geom_point_interactive(aes(y = maxHR, tooltip = tip_max), color = swim_palette["heart_max"], size = 2) +
        scale_x_date(date_labels = "%d %b", date_breaks = "2 weeks") +
        labs(x = NULL, y = "BPM") +
        theme_swim() +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))

      make_girafe(gg)
    })

    output$swolf_trend <- renderGirafe({
      df <- summary_data() |> filter(!is.na(avg_swolf)) |>
        mutate(tip = paste0(format(period_date, "%d %b %y"), "\nSWOLF: ", round(avg_swolf, 1)))
      req(nrow(df) > 0)

      gg <- ggplot(df, aes(x = period_date, y = avg_swolf)) +
        geom_line(color = swim_palette["success"], linewidth = 1.3) +
        geom_point_interactive(aes(tooltip = tip), color = swim_palette["success"], size = 3.5) +
        geom_smooth(method = "loess", formula = y ~ x, se = FALSE,
                    color = swim_palette["primary"], linewidth = 0.8, linetype = "dashed") +
        scale_x_date(date_labels = "%d %b", date_breaks = "2 weeks") +
        labs(x = NULL, y = "SWOLF medio") +
        theme_swim() +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))

      make_girafe(gg)
    })

    # ═══ DETALLE DE SESIÓN (modal al clicar punto) ═══

    selected_act_id <- reactiveVal(NULL)

    # Cualquiera de los 4 gráficos de sesión puede disparar el modal
    observe({
      sel <- input$strokes_evolution_selected
      if (!is.null(sel) && nchar(sel) > 0) selected_act_id(sel)
    })
    observe({
      sel <- input$pace_evolution_selected
      if (!is.null(sel) && nchar(sel) > 0) selected_act_id(sel)
    })
    observe({
      sel <- input$swolf_session_selected
      if (!is.null(sel) && nchar(sel) > 0) selected_act_id(sel)
    })
    observe({
      sel <- input$distance_session_selected
      if (!is.null(sel) && nchar(sel) > 0) selected_act_id(sel)
    })

    output$detail_laps <- DT::renderDT({
      req(selected_act_id())
      laps() |>
        filter(activityId == as.numeric(selected_act_id()),
               lapType == "active", distance > 0) |>
        mutate(
          Largo    = row_number(),
          Estilo   = coalesce(stroke_labels[swimStroke], swimStroke),
          Brazadas = brazadas,
          SWOLF    = swolf,
          `Dist (m)` = round(distance)
        ) |>
        select(Largo, Estilo, Brazadas, SWOLF, `Dist (m)`)
    }, options = list(pageLength = 50, dom = "t", ordering = FALSE), rownames = FALSE)

    observeEvent(selected_act_id(), {
      req(selected_act_id())
      act <- activities() |> filter(activityId == as.numeric(selected_act_id()))
      req(nrow(act) > 0)
      act <- act[1, ]

      h <- floor(act$duration_min / 60)
      m <- round(act$duration_min %% 60)
      dur_str <- if (h > 0) sprintf("%dh %02dmin", h, m) else sprintf("%d min", m)

      showModal(modalDialog(
        title = tags$span(
          tags$span("\U0001F3CA", style = "margin-right:8px;"),
          paste("Sesión —", format(act$date, "%d %B %Y"))
        ),
        size = "l",
        easyClose = TRUE,
        footer = modalButton("Cerrar"),

        # KPIs de la sesión
        tags$div(
          style = "display:flex; gap:16px; flex-wrap:wrap; margin-bottom:16px;",
          lapply(
            list(
              list(v = paste0(round(act$distance_m), " m"),       l = "Distancia"),
              list(v = dur_str,                                    l = "Duración"),
              list(v = if (is.na(act$averageSwolf)) "\u2014" else act$averageSwolf, l = "SWOLF"),
              list(v = if (is.na(act$pace_100m))    "\u2014" else format_pace(act$pace_100m), l = "Ritmo /100m"),
              list(v = if (is.na(act$avg_brazadas)) "\u2014" else round(act$avg_brazadas, 1), l = "Brazadas/largo"),
              list(v = if (is.na(act$largos))       "\u2014" else act$largos, l = "Largos"),
              list(v = if (is.null(act$calidad) || is.na(act$calidad)) "\u2014" else act$calidad, l = "Calidad"),
              list(v = if (is.null(act$pct_le11) || is.na(act$pct_le11)) "\u2014" else paste0(act$pct_le11, "%"), l = "\u226412 braz (crol)"),
              list(v = if (is.null(act$pct_le13) || is.na(act$pct_le13)) "\u2014" else paste0(act$pct_le13, "%"), l = "\u226413 braz (crol)"),
              list(v = if (is.null(act$pct_ge15) || is.na(act$pct_ge15)) "\u2014" else paste0(act$pct_ge15, "%"), l = "\u226515 braz (crol)")
            ),
            function(x) tags$div(
              style = "background:#f0f4f8; border-radius:8px; padding:10px 16px; text-align:center; min-width:90px;",
              tags$div(style = "font-size:1.2rem; font-weight:700; color:#0077b6;", x$v),
              tags$div(style = "font-size:0.75rem; color:#64748b;", x$l)
            )
          )
        ),

        tags$hr(),
        tags$h6("Largos", style = "color:#1a1a2e; font-weight:600; margin-bottom:8px;"),
        DT::DTOutput(session$ns("detail_laps"))
      ))
    })
  })
}
