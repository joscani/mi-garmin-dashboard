#' Módulo de filtros

library(shinyWidgets)

mod_filters_ui <- function(id) {
  ns <- NS(id)
  tagList(
    airDatepickerInput(
      ns("date_range"), "Periodo",
      value    = c(Sys.Date() - 365, Sys.Date()),
      range    = TRUE,
      multiple = TRUE,
      language = "es",
      separator = " – ",
      addon    = "none",
      view     = "days",
      minView  = "days",
      autoClose = TRUE
    ),
    selectInput(
      ns("aggregation"), "Agrupar por",
      choices  = c("Semana" = "week", "Mes" = "month"),
      selected = "week"
    ),
    selectInput(
      ns("stroke_filter"), "Estilo",
      choices  = c("Todos" = "all", "Crol" = "freestyle", "Espalda" = "backstroke",
                   "Braza" = "breaststroke", "Mariposa" = "butterfly"),
      selected = "all"
    ),
    hr(),
    actionButton(ns("refresh"), "Recargar datos", class = "btn-primary btn-sm w-100")
  )
}

mod_filters_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    list(
      date_range   = reactive(input$date_range),
      aggregation  = reactive(input$aggregation),
      stroke_filter = reactive(input$stroke_filter),
      refresh      = reactive(input$refresh)
    )
  })
}
