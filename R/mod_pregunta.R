#' Módulo: preguntar al panel en lenguaje natural (Jev)
#'
#' Jev no calcula nada: solo elige entre opciones que genera el código
#' (periodos, agrupación, estilo, pestaña, sesiones a comparar) y la app
#' aplica esos cambios con los filtros y pestañas existentes.
#' Protegido con contraseña (TYPESAFE_APP_PASSWORD) y límites de uso (utils_jev.R).

MESES_ES <- c("enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
              "agosto", "septiembre", "octubre", "noviembre", "diciembre")
DIAS_ES  <- c("lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo")

# ── Opciones que Jev puede elegir ────────────────────────────────────────────

# Periodos candidatos: relativos a hoy + cada mes con datos
periodos_candidatos <- function(fechas, hoy = Sys.Date()) {
  rel <- list(
    ultimas_4_semanas = list(desc = "Las últimas 4 semanas",
                             rango = c(hoy - 27, hoy)),
    ultimos_3_meses   = list(desc = "Los últimos 3 meses",
                             rango = c(hoy %m-% months(3), hoy)),
    ultimos_6_meses   = list(desc = "Los últimos 6 meses",
                             rango = c(hoy %m-% months(6), hoy)),
    ultimo_ano        = list(desc = "El último año (12 meses)",
                             rango = c(hoy - 365, hoy)),
    este_ano          = list(desc = paste("Este año,", format(hoy, "%Y"), "desde el 1 de enero"),
                             rango = c(floor_date(hoy, "year"), hoy)),
    todo              = list(desc = "Todo el historial, desde la primera sesión",
                             rango = c(min(fechas, na.rm = TRUE), hoy))
  )
  meses <- sort(unique(floor_date(fechas, "month")), decreasing = TRUE)
  por_mes <- lapply(meses, function(m) list(
    desc  = paste(MESES_ES[month(m)], "de", year(m)),
    rango = c(m, ceiling_date(m, "month") - 1)
  ))
  names(por_mes) <- format(meses, "mes_%Y_%m")
  c(rel, por_mes)
}

AGRUPACIONES <- c(week = "Por semanas", month = "Por meses")

ESTILOS <- c(
  all          = "Todos los estilos",
  freestyle    = "Crol (estilo libre)",
  backstroke   = "Espalda",
  breaststroke = "Braza",
  butterfly    = "Mariposa"
)

PESTANAS <- c(
  Evolución = "Evolución en el tiempo: brazadas, ritmo, SWOLF y distancia por sesión",
  Sesiones  = "Detalle largo a largo de una sesión",
  Resumen   = "Resumen por semanas o meses y calidad de las sesiones",
  Comparar  = "Comparar dos sesiones lado a lado",
  Datos     = "Tabla con los datos de todas las sesiones",
  ninguna   = "No pide abrir ninguna pestaña concreta"
)

# Papeles de sesión: Jev elige el papel, el código resuelve cuál es
ROLES_SESION <- c(
  ultima        = "La última sesión (la más reciente)",
  penultima     = "La penúltima sesión",
  menos_brazadas = "La de menos brazadas por largo (mejor técnica)",
  mas_brazadas  = "La de más brazadas por largo",
  mejor_swolf   = "La de mejor SWOLF (el más bajo)",
  peor_swolf    = "La de peor SWOLF (el más alto)",
  mas_rapida    = "La más rápida (mejor ritmo por 100 m)",
  mas_lenta     = "La más lenta (peor ritmo por 100 m)",
  mas_larga     = "La de más distancia",
  mas_corta     = "La de menos distancia"
)

resolver_rol <- function(acts, rol) {
  acts <- acts |> arrange(desc(date))
  pick <- function(x, fn) acts$activityId[fn(x)]
  id <- switch(rol,
    ultima         = acts$activityId[1],
    penultima      = acts$activityId[2],
    menos_brazadas = pick(acts$med_brazadas, which.min),
    mas_brazadas   = pick(acts$med_brazadas, which.max),
    mejor_swolf    = pick(acts$averageSwolf, which.min),
    peor_swolf     = pick(acts$averageSwolf, which.max),
    mas_rapida     = pick(acts$pace_100m, which.min),
    mas_lenta      = pick(acts$pace_100m, which.max),
    mas_larga      = pick(acts$distance_m, which.max),
    mas_corta      = pick(acts$distance_m, which.min)
  )
  if (length(id) == 0 || is.na(id[1])) NULL else id[1]
}

# ── Preguntas a Jev ──────────────────────────────────────────────────────────

construir_preguntas <- function(periodos) {
  list(
    periodo_pedido = jev_noul(paste(
      "¿La `peticion` menciona un periodo de tiempo (un mes, semanas, meses, este año,",
      "todo el historial...)? Mencionar solo 'la última sesión' no es un periodo.")),
    periodo = jev_choice(
      "¿Qué periodo de fechas pide la `peticion`? La fecha de hoy está en `hoy`.",
      vapply(periodos, `[[`, "", "desc")),
    agrupar_pedido = jev_noul(paste(
      "¿La `peticion` pide explícitamente agrupar o resumir los datos por semanas o",
      "por meses? Mencionar un mes o un periodo concreto ('de marzo', 'este año')",
      "no es pedir agrupar.")),
    agrupar = jev_choice(
      "¿Cómo pide la `peticion` agrupar los datos?", AGRUPACIONES),
    estilo_pedido = jev_noul(paste(
      "¿La `peticion` menciona un estilo de nado (crol, libre, espalda, braza,",
      "mariposa) o pide ver todos los estilos? Ojo: 'brazadas' es el número de",
      "movimientos de brazo por largo, no el estilo braza.")),
    estilo = jev_choice(
      "¿Qué estilo de nado pide la `peticion`?", ESTILOS),
    pestana = jev_choice(
      "¿Qué parte del panel quiere ver la `peticion`?", PESTANAS),
    comparar = jev_noul(
      "¿La `peticion` pide comparar dos cosas entre sí ('compara X con Y', 'X frente a Y', 'X vs Y')?"),
    sesion_a = jev_choice(paste(
      "Si la `peticion` compara dos sesiones, ¿cuál es la primera que menciona?",
      "Si no la concreta, es la última sesión."), ROLES_SESION),
    sesion_b = jev_choice(paste(
      "Si la `peticion` compara dos sesiones, ¿cuál es la segunda que menciona?",
      "Si no la concreta, es la penúltima sesión."), ROLES_SESION),
    # El periodo puede acotar solo una de las dos: en «la de hoy frente a la
    # más rápida de enero», «de enero» solo acota la segunda.
    periodo_alcance = jev_choice(paste(
      "La `peticion` compara dos sesiones y menciona un periodo de tiempo.",
      "¿A qué sesiones se refiere ese periodo? En español, un periodo escrito junto",
      "a una sola de las sesiones ('la de mejor SWOLF de enero') acota solo esa."),
      c(ambas   = "El periodo acota las dos sesiones que se comparan",
        primera = "El periodo acota solo la primera sesión que se menciona",
        segunda = "El periodo acota solo la segunda sesión que se menciona"))
  )
}

# ── UI ───────────────────────────────────────────────────────────────────────

PREGUNTA_CSS <- "
  .pregunta-card { font-size: 1.15rem; }
  .pregunta-card .card-header { font-size: 1.25rem; }
  .pregunta-card textarea, .pregunta-card input[type=password] {
    font-size: 1.2rem; padding: 10px 14px; border-radius: 10px;
  }
  .pregunta-card textarea { resize: vertical; min-height: 3.4em; }
  .pregunta-card .btn { font-size: 1.1rem; padding: 10px 26px; border-radius: 10px; }
  .pregunta-card .pregunta-fila { display: flex; gap: 12px; align-items: flex-start; flex-wrap: wrap; }
  .pregunta-card .pregunta-fila .form-group { margin-bottom: 0; }
  .pregunta-card .pregunta-respuesta { margin-top: 12px; padding: 10px 14px; border-radius: 10px; }
  .pregunta-card .pregunta-quedan { font-size: 0.95rem; margin-top: 6px; }
"

mod_pregunta_ui <- function(id) {
  ns <- NS(id)
  card(
    class = "mb-3 pregunta-card",
    # Sin esto page_sidebar encoge la tarjeta para que todo quepa en pantalla
    fill = FALSE,
    tags$head(tags$style(HTML(PREGUNTA_CSS))),
    card_header("\U0001F4AC Pregúntale al panel"),
    div(style = "padding:12px 16px 16px;", uiOutput(ns("contenido")))
  )
}

# ── Server ───────────────────────────────────────────────────────────────────

#' @param activities_all reactive con todas las actividades (sin filtrar por fecha)
#' @param date_range     reactive con el rango de fechas actual
#' @param filters        lista de setters de mod_filters_server()$set
#' @param set_tab        función(nombre_pestaña)
#' @param set_compare    función(id_a, id_b)
mod_pregunta_server <- function(id, activities_all, date_range, filters, set_tab, set_compare) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    desbloqueado <- reactiveVal(FALSE)
    intentos     <- reactiveVal(0L)
    usadas       <- reactiveVal(0L)
    mensaje      <- reactiveVal(NULL)
    max_sesion   <- jev_limite("TYPESAFE_MAX_POR_SESION", 10L)

    output$contenido <- renderUI({
      if (!desbloqueado()) {
        if (intentos() >= JEV_MAX_INTENTOS_PASSWORD) {
          return(tags$p(class = "text-muted mb-0", "Demasiados intentos. Recarga la página."))
        }
        return(div(class = "pregunta-fila",
          passwordInput(ns("password"), NULL, placeholder = "Contraseña", width = "280px"),
          actionButton(ns("desbloquear"), "Desbloquear", class = "btn-outline-primary"),
          if (intentos() > 0) tags$span(class = "text-danger align-self-center", "Contraseña incorrecta")
        ))
      }
      tagList(
        div(class = "pregunta-fila",
          div(style = "flex:1; min-width:260px;",
            textAreaInput(ns("texto"), NULL, width = "100%", rows = 2,
              placeholder = "p. ej. «compara la última con la de menos brazadas de marzo» o «crol de los últimos 3 meses por semanas»")),
          actionButton(ns("preguntar"), "Preguntar", class = "btn-primary")
        ),
        # Enter envía la pregunta; Mayús+Enter hace salto de línea
        tags$script(HTML(sprintf(
          "$(document).on('keydown', '#%s', function(e) {
             if (e.key === 'Enter' && !e.shiftKey) {
               e.preventDefault();
               Shiny.setInputValue('%s', this.value);
               $('#%s').click();
             }
           });", ns("texto"), ns("texto"), ns("preguntar")))),
        uiOutput(ns("respuesta"))
      )
    })

    observeEvent(input$desbloquear, {
      if (intentos() >= JEV_MAX_INTENTOS_PASSWORD) return()
      if (identical(input$password, Sys.getenv("TYPESAFE_APP_PASSWORD"))) {
        desbloqueado(TRUE)
      } else {
        intentos(intentos() + 1L)
      }
    })

    output$respuesta <- renderUI({
      m <- mensaje()
      quedan <- max_sesion - usadas()
      tagList(
        if (!is.null(m)) tags$div(class = paste0("pregunta-respuesta alert alert-", m$tipo, " mb-0"), m$texto),
        tags$div(class = "pregunta-quedan text-muted", sprintf("Te quedan %d preguntas en esta sesión.", quedan))
      )
    })

    observeEvent(input$preguntar, {
      req(desbloqueado())
      texto <- trimws(input$texto %||% "")
      if (nchar(texto) == 0) return()
      if (nchar(texto) > JEV_MAX_CHARS) {
        return(mensaje(list(tipo = "danger",
          texto = sprintf("Máximo %d caracteres.", JEV_MAX_CHARS))))
      }
      if (usadas() >= max_sesion) {
        return(mensaje(list(tipo = "danger", texto = "Has llegado al límite de preguntas de esta sesión.")))
      }
      if (jev_quedan_hoy() <= 0) {
        return(mensaje(list(tipo = "danger", texto = "Se ha llegado al límite diario de preguntas.")))
      }

      acts <- activities_all()
      hoy  <- Sys.Date()
      periodos <- periodos_candidatos(acts$date, hoy)
      state <- list(
        peticion = texto,
        hoy = paste0(DIAS_ES[wday(hoy, week_start = 1)], " ", day(hoy), " de ",
                     MESES_ES[month(hoy)], " de ", year(hoy))
      )

      usadas(usadas() + 1L)
      jev_registrar_uso()
      r <- tryCatch(jev_ask(state, construir_preguntas(periodos)), error = function(e) e)
      if (inherits(r, "error")) {
        return(mensaje(list(tipo = "danger", texto = paste("Error al consultar Jev:", conditionMessage(r)))))
      }

      hecho <- character(0)
      comparar <- r$comparar$noul >= 0.5
      periodo  <- if (r$periodo_pedido$noul >= 0.5) periodos[[r$periodo$choice]] else NULL

      # Al comparar, el periodo solo sirve para elegir las sesiones
      if (!is.null(periodo) && !comparar) {
        filters$date_range(periodo$rango)
        hecho <- c(hecho, paste("Periodo:", periodo$desc))
      }
      if (r$agrupar_pedido$noul >= 0.5) {
        filters$aggregation(r$agrupar$choice)
        hecho <- c(hecho, paste("Agrupar:", tolower(AGRUPACIONES[[r$agrupar$choice]])))
      }
      if (r$estilo_pedido$noul >= 0.5) {
        filters$stroke(r$estilo$choice)
        hecho <- c(hecho, paste("Estilo:", ESTILOS[[r$estilo$choice]]))
      }

      if (comparar) {
        # Cada sesión se busca en el periodo solo si Jev dice que la acota;
        # si no, entre todas las sesiones
        candidatas <- function(aplica) {
          if (is.null(periodo) || !aplica) return(acts)
          acts |> filter(date >= periodo$rango[1], date <= periodo$rango[2])
        }
        alcance <- r$periodo_alcance$choice
        id_a <- resolver_rol(candidatas(alcance %in% c("ambas", "primera")), r$sesion_a$choice)
        id_b <- resolver_rol(candidatas(alcance %in% c("ambas", "segunda")), r$sesion_b$choice)
        if (is.null(id_a) || is.null(id_b)) {
          hecho <- c(hecho, "No hay suficientes sesiones en el periodo para comparar")
        } else {
          fechas <- acts$date[match(c(id_a, id_b), acts$activityId)]
          # Ampliar el filtro de fechas si alguna sesión queda fuera del selector
          rango <- date_range()
          nuevo <- c(min(rango[1], fechas), max(rango[2], fechas))
          if (!identical(as.Date(nuevo), as.Date(rango))) filters$date_range(nuevo)
          set_compare(id_a, id_b)
          set_tab("Comparar")
          etiqueta <- function(rol, f) paste0(tolower(ROLES_SESION[[rol]]),
            " (", day(f), " ", MESES_ES[month(f)], " ", year(f), ")")
          hecho <- c(hecho, paste0("Comparar: ", etiqueta(r$sesion_a$choice, fechas[1]),
                                   " vs ", etiqueta(r$sesion_b$choice, fechas[2]),
                                   if (id_a == id_b) " — es la misma sesión" else ""))
        }
      } else if (r$pestana$choice != "ninguna") {
        set_tab(r$pestana$choice)
        hecho <- c(hecho, paste("Pestaña:", r$pestana$choice))
      }

      if (length(hecho) == 0) {
        mensaje(list(tipo = "warning", texto = "No sé hacer eso. Puedo cambiar el periodo, la agrupación, el estilo, abrir una pestaña o comparar sesiones."))
      } else {
        mensaje(list(tipo = "success", texto = paste(hecho, collapse = "  ·  ")))
      }
    })
  })
}
