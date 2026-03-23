#' Mi Garmin Dashboard - Natación

library(shiny)
library(bslib)
library(dplyr)

source("R/utils_data.R")
source("R/utils_charts.R")
source("R/mod_filters.R")
source("R/mod_kpis.R")
source("R/mod_charts.R")
source("R/mod_table.R")

custom_css <- "
  body { background-color: #f0f4f8; }
  .card {
    background-color: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 12px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.06);
  }
  .card-header {
    background-color: #ffffff;
    border-bottom: 1px solid #e2e8f0;
    font-weight: 600; color: #1a1a2e;
    padding: 12px 16px;
  }
  .bslib-value-box { border-radius: 12px; }
  .bslib-value-box .value-box-title { font-size: 0.78rem; opacity: 0.75; }
  .bslib-value-box .value-box-value { font-size: 1.4rem; font-weight: 700; }
  .nav-tabs .nav-link.active { font-weight: 600; border-bottom: 3px solid #00b4d8; }
  @media (max-width: 768px) {
    .bslib-value-box .value-box-value { font-size: 1.1rem; }
  }
"

charts_ui <- mod_charts_ui("charts")

ui <- page_sidebar(
  title = tags$span(
    style = "display:flex; align-items:center; gap:8px;",
    tags$span("\U0001F3CA", style = "font-size:22px;"),
    "Mi Garmin \u2013 Natación"
  ),
  theme = bs_theme(
    version = 5, bootswatch = "flatly",
    primary = "#0077b6", success = "#06d6a0",
    info = "#00b4d8", warning = "#ffd166",
    base_font = font_google("Inter"),
    heading_font = font_google("Inter"),
    "navbar-bg" = "#023e8a"
  ),

  sidebar = sidebar(
    open = "desktop", width = 250, bg = "#ffffff",
    mod_filters_ui("filters")
  ),

  tags$head(tags$style(HTML(custom_css))),

  mod_kpis_ui("kpis"),

  navset_card_underline(
    id = "main_tabs",
    nav_panel("Evolución", div(class = "py-2", charts_ui$evolucion)),
    nav_panel("Sesiones", div(class = "py-2", charts_ui$laps)),
    nav_panel("Resumen",   div(class = "py-2", charts_ui$resumen)),
    nav_panel("Datos",     div(class = "py-2", mod_table_ui("table")))
  )
)

server <- function(input, output, session) {
  raw_data <- reactiveVal()

  load_all <- function(bust = FALSE) {
    if (bust) bust_cache()
    acts <- load_activities(bust_cache = bust)
    lps  <- load_laps(bust_cache = bust)
    # Enriquecer actividades con brazadas desde laps
    acts <- compute_brazadas_per_session(acts, lps)
    list(activities = acts, laps = lps)
  }

  observe({ raw_data(load_all()) })

  filters <- mod_filters_server("filters")
  observeEvent(filters$refresh(), { raw_data(load_all(bust = TRUE)) })

  activities_filtered <- reactive({
    req(raw_data())
    dr <- filters$date_range()
    raw_data()$activities |> filter(date >= dr[1], date <= dr[2])
  })

  laps_filtered <- reactive({
    req(raw_data())
    raw_data()$laps |> filter(activityId %in% activities_filtered()$activityId)
  })

  summary_data <- reactive({
    summarise_by_period(activities_filtered(), filters$aggregation())
  })

  mod_kpis_server("kpis", activities_filtered)
  mod_charts_server("charts", summary_data, activities_filtered, laps_filtered, filters$stroke_filter, filters$aggregation)
  mod_table_server("table", activities_filtered)
}

shinyApp(ui, server)
