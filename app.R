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
source("R/utils_jev.R")
source("R/mod_pregunta.R")

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
  .bslib-value-box .value-box-area { padding: 12px 14px !important; }
  .kpi-delta { margin-top: 4px; }
  .kpi-delta span {
    display: inline-block; font-size: 0.72rem; font-weight: 600;
    padding: 1px 8px; border-radius: 10px; background: rgba(0,0,0,0.18); color: #fff;
  }
  .kpi-delta span.kpi-mejor { background: rgba(21,128,61,0.9); }
  .kpi-delta span.kpi-peor  { background: rgba(185,28,28,0.85); }
  .bslib-value-box .value-box-title {
    font-size: clamp(0.65rem, 1.5vw, 0.82rem);
    opacity: 0.80;
    white-space: nowrap;
  }
  .bslib-value-box .value-box-value {
    font-size: clamp(1.1rem, 3vw, 1.6rem);
    font-weight: 700;
    line-height: 1.2;
    word-break: break-word;
  }
  .bslib-value-box .value-box-showcase {
    font-size: clamp(1.2rem, 3vw, 1.6rem);
  }
  .nav-underline .nav-link { color: #475569; }
  .nav-underline .nav-link:hover { color: #0077b6; }
  .nav-underline .nav-link.active { color: #023e8a; font-weight: 600; }
  @media (max-width: 576px) {
    .bslib-value-box .value-box-title { font-size: 0.7rem; }
    .bslib-value-box .value-box-value { font-size: 1.1rem; }
  }
"

charts_ui <- mod_charts_ui("charts")

ui <- page_sidebar(
  # Scroll natural de página: en modo «fillable» los KPIs y la tarjeta de Jev se
  # comían la altura y los gráficos quedaban en una franja con scroll interno
  fillable = FALSE,
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

  # Solo aparece si hay TYPESAFE_API_KEY y TYPESAFE_APP_PASSWORD
  if (jev_disponible()) mod_pregunta_ui("pregunta"),

  navset_card_underline(
    id = "main_tabs",
    nav_panel("Evolución", div(class = "py-2", charts_ui$evolucion)),
    nav_panel("Sesiones",  div(class = "py-2", charts_ui$laps)),
    nav_panel("Resumen",   div(class = "py-2", charts_ui$resumen)),
    nav_panel("Comparar",  div(class = "py-2", charts_ui$comparar)),
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

  # Si falla la carga se avisa en pantalla y se conservan los datos que hubiera
  cargar <- function(bust = FALSE) {
    d <- tryCatch(load_all(bust), error = function(e) {
      showNotification(paste("No se pudieron cargar los datos:", conditionMessage(e)),
                       type = "error", duration = NULL)
      NULL
    })
    if (!is.null(d)) {
      raw_data(d)
      if (bust) showNotification("Datos recargados", type = "message", duration = 3)
    }
  }

  observe(cargar())

  filters <- mod_filters_server("filters")
  observeEvent(filters$refresh(), cargar(bust = TRUE), ignoreInit = TRUE)

  # Mientras se elige el rango en el calendario solo hay una fecha: no filtrar aún
  date_range_ok <- reactive({
    dr <- as.Date(filters$date_range())
    req(length(dr) == 2, !anyNA(dr))
    sort(dr)
  })

  activities_filtered <- reactive({
    req(raw_data())
    dr <- date_range_ok()
    raw_data()$activities |> filter(date >= dr[1], date <= dr[2])
  })

  laps_filtered <- reactive({
    req(raw_data())
    raw_data()$laps |> filter(activityId %in% activities_filtered()$activityId)
  })

  summary_data <- reactive({
    summarise_by_period(activities_filtered(), filters$aggregation())
  })

  mod_kpis_server("kpis", activities_filtered,
                  activities_all = reactive({ req(raw_data()); raw_data()$activities }),
                  date_range     = date_range_ok)
  compare_request <- reactiveVal(NULL)
  mod_charts_server("charts", summary_data, activities_filtered, laps_filtered, filters$stroke_filter, filters$aggregation,
                    compare_request)
  mod_table_server("table", activities_filtered)

  if (jev_disponible()) {
    mod_pregunta_server("pregunta",
      activities_all = reactive(raw_data()$activities),
      date_range     = filters$date_range,
      filters        = filters$set,
      set_tab        = function(tab) nav_select("main_tabs", tab, session = session),
      # nonce: que la misma petición repetida vuelva a disparar el observer
      set_compare    = function(a, b) compare_request(list(a = as.character(a), b = as.character(b), nonce = Sys.time()))
    )
  }
}

shinyApp(ui, server)
