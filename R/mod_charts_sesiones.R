#' Sub-módulo: pestaña Sesiones (por largo)

mod_sesiones_ui <- function(id) {
  ns <- NS(id)
  tagList(
    card(full_screen = FALSE,
      div(
        style = "display:flex; align-items:center; justify-content:space-between; padding:8px 4px;",
        actionButton(ns("prev_session"), label = NULL, icon = icon("chevron-left"),
                     class = "btn btn-outline-secondary btn-sm"),
        uiOutput(ns("session_title")),
        actionButton(ns("next_session"), label = NULL, icon = icon("chevron-right"),
                     class = "btn btn-outline-secondary btn-sm")
      ),
      div(
        style = "padding:4px 12px 8px;",
        sliderInput(ns("skip_laps"), "Ignorar primeros largos",
                    min = 0, max = 20, value = 0, step = 1, width = "100%")
      )
    ),
    layout_column_wrap(
      width = 1/2,
      card(full_screen = TRUE,
        card_header("Brazadas por largo"),
        mod_lap_chart_ui(ns("strokes_range"))
      ),
      card(full_screen = TRUE,
        card_header("SWOLF por largo"),
        mod_lap_chart_ui(ns("swolf_range"))
      )
    ),
    card(full_screen = TRUE, class = "mt-3",
      card_header("Brazadas vs SWOLF por estilo (sesión seleccionada)"),
      girafeOutput(ns("scatter"), height = "480px", width = "100%")
    )
  )
}

mod_sesiones_server <- function(id, activities, active_laps, sessions_ordered) {
  moduleServer(id, function(input, output, session) {

    session_idx <- reactiveVal(1)
    observeEvent(activities(), { session_idx(1) })
    observeEvent(input$prev_session, { session_idx(min(session_idx() + 1, nrow(sessions_ordered()))) })
    observeEvent(input$next_session, { session_idx(max(session_idx() - 1, 1)) })

    current_session <- reactive({
      df <- sessions_ordered()
      req(nrow(df) > 0)
      df[session_idx(), ]
    })

    output$session_title <- renderUI({
      act <- session_info_filtered()
      n   <- nrow(sessions_ordered())
      idx <- session_idx()
      h <- floor(act$duration_min / 60)
      m <- round(act$duration_min %% 60)
      dur_str <- if (h > 0) sprintf("%dh %02dmin", h, m) else sprintf("%d min", m)

      calidad_color <- switch(coalesce(act$calidad, ""),
        "Muy buena" = "#06d6a0", "Buena" = "#0077b6",
        "Regular"   = "#ffd166", "Mala"  = "#e63946", "#94a3b8")

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
                           "; font-weight:700; font-size:0.82rem; padding:2px 10px;",
                           " border-radius:12px; border:1px solid ", calidad_color, ";"),
            act$calidad
          ),
          tags$span(style = "font-size:0.75rem; color:#64748b;",
            paste0("Buenos \u226411: ", act$pct_buenos, "% · ",
                   "Normales 12-13: ", act$pct_normales, "% · ",
                   "Caros \u226514: ", act$pct_caros, "%")
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
        ) |>
        filter(largo > input$skip_laps)
    })

    session_info_filtered <- reactive({
      act  <- current_session()
      laps <- session_laps()

      # Recalcular ritmo con los largos filtrados
      dur_sec  <- sum(laps$duration,  na.rm = TRUE)
      dist_m   <- sum(laps$distance,  na.rm = TRUE)
      pace     <- if (dist_m > 0) (dur_sec / 60) / (dist_m / 100) else NA_real_

      # Recalcular calidad sobre crol filtrado
      crol <- laps |> filter(swimStroke == "freestyle", !is.na(brazadas))
      n_crol <- nrow(crol)

      if (n_crol > 0) {
        n_buenos   <- sum(crol$brazadas <= 11)
        n_normales <- sum(crol$brazadas >= 12 & crol$brazadas <= 13)
        n_caros    <- sum(crol$brazadas >= 14)
        pct_buenos   <- round(n_buenos   / n_crol * 100, 1)
        pct_normales <- round(n_normales / n_crol * 100, 1)
        pct_caros    <- round(n_caros    / n_crol * 100, 1)
        pct_le13     <- round((n_buenos + n_normales) / n_crol * 100, 1)
        pct_le14     <- round((n_buenos + n_normales + n_caros) / n_crol * 100, 1)
        calidad <- dplyr::case_when(
          pct_buenos >= 50 ~ "Muy buena",
          pct_le13   >= 40 ~ "Buena",
          pct_le14   >= 50 ~ "Regular",
          TRUE             ~ "Mala"
        )
        act$n_crol      <- n_crol
        act$pct_buenos  <- pct_buenos
        act$pct_normales <- pct_normales
        act$pct_caros   <- pct_caros
        act$calidad     <- calidad
      } else {
        act$n_crol <- 0L
      }

      act$pace_100m <- pace
      act
    })

    mod_lap_chart_server("strokes_range",
      data         = reactive(session_laps() |> filter(!is.na(brazadas))),
      y_col        = "brazadas",
      y_lab        = "Brazadas",
      session_info = session_info_filtered
    )

    mod_lap_chart_server("swolf_range",
      data         = reactive(session_laps() |> filter(!is.na(swolf))),
      y_col        = "swolf",
      y_lab        = "SWOLF",
      session_info = session_info_filtered
    )

    # scatter: único, se queda custom
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
          "Crol"     = swim_palette[["primary"]],
          "Espalda"  = swim_palette[["success"]],
          "Braza"    = swim_palette[["warning"]],
          "Mariposa" = swim_palette[["heart_avg"]],
          "Mixto"    = swim_palette[["lighter"]],
          "Técnica"  = swim_palette[["text_soft"]]
        )) +
        labs(x = "Brazadas por largo", y = "SWOLF") +
        theme_swim()

      make_girafe(gg)
    })
  })
}
