#' Cliente mínimo de la API de TypeSafe (Jev) y control de uso
#'
#' La llamada se hace desde el servidor de Shiny: la API key nunca llega al
#' navegador. Variables de entorno (en .Renviron):
#'   TYPESAFE_API_KEY        clave de TypeSafe
#'   TYPESAFE_APP_PASSWORD   contraseña para desbloquear la función en la app
#'   TYPESAFE_MAX_POR_SESION preguntas por sesión de navegador (defecto 10)
#'   TYPESAFE_MAX_POR_DIA    preguntas por día entre todos los usuarios (defecto 50)

JEV_URL        <- "https://api.typesafe.ai/v1/systemone"
JEV_MAX_CHARS  <- 200
JEV_MAX_INTENTOS_PASSWORD <- 5

jev_disponible <- function() {
  nchar(Sys.getenv("TYPESAFE_API_KEY")) > 0 && nchar(Sys.getenv("TYPESAFE_APP_PASSWORD")) > 0
}

jev_limite <- function(var, defecto) {
  v <- suppressWarnings(as.integer(Sys.getenv(var)))
  if (is.na(v)) defecto else v
}

# Contador diario global. Vive en memoria del proceso: se reinicia si
# shinyapps.io reinicia la app, así que es una red de seguridad, no un tope exacto.
.jev_uso <- new.env(parent = emptyenv())
.jev_uso$dia <- Sys.Date()
.jev_uso$n   <- 0L

jev_quedan_hoy <- function() {
  if (.jev_uso$dia != Sys.Date()) { .jev_uso$dia <- Sys.Date(); .jev_uso$n <- 0L }
  jev_limite("TYPESAFE_MAX_POR_DIA", 50L) - .jev_uso$n
}

jev_registrar_uso <- function() {
  jev_quedan_hoy()
  .jev_uso$n <- .jev_uso$n + 1L
}

#' Llama a Jev y devuelve la lista `answers` de la respuesta
jev_ask <- function(state, questions, timeout = 20) {
  body <- jsonlite::toJSON(
    list(model = "jev-latest", state = state, questions = questions),
    auto_unbox = TRUE
  )
  llamar <- function() {
    h <- curl::new_handle()
    curl::handle_setopt(h, customrequest = "POST", postfields = body, timeout = timeout)
    curl::handle_setheaders(h,
      Authorization  = paste("Bearer", Sys.getenv("TYPESAFE_API_KEY")),
      `Content-Type` = "application/json"
    )
    curl::curl_fetch_memory(JEV_URL, handle = h)
  }

  res <- llamar()
  # 429 (límite de peticiones) / 529 (servicio saturado): un reintento
  if (res$status_code %in% c(429, 529)) {
    Sys.sleep(1.5)
    res <- llamar()
  }
  if (res$status_code != 200) {
    stop(sprintf("TypeSafe respondió %d: %s", res$status_code,
                 substr(rawToChar(res$content), 1, 200)))
  }
  jsonlite::fromJSON(rawToChar(res$content), simplifyVector = FALSE)$answers
}

jev_noul <- function(instructions) list(type = "noul", instructions = instructions)

jev_choice <- function(instructions, criteria) {
  list(type = "choice", instructions = instructions, criteria = as.list(criteria))
}
