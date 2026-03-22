#' Utilidades de carga y transformación de datos de natación

library(dplyr)
library(lubridate)
library(readr)

GITHUB_DATA_REPO <- "joscani/garmin-data"
GITHUB_DATA_BRANCH <- "main"

# Descarga un CSV del repo privado de datos y devuelve su path temporal
.github_download_csv <- function(filename) {
  token <- Sys.getenv("DATA_GITHUB_PAT", "")
  if (nchar(token) == 0) stop("Falta DATA_GITHUB_PAT para acceder a los datos")
  url <- sprintf("https://%s@raw.githubusercontent.com/%s/%s/%s",
                 token, GITHUB_DATA_REPO, GITHUB_DATA_BRANCH, filename)
  tmp <- tempfile(fileext = ".csv")
  download.file(url, destfile = tmp, quiet = TRUE)
  tmp
}

# Cachear datos para evitar releer CSV en cada reactive
.data_cache <- new.env(parent = emptyenv())

load_activities <- function(path = "data/swimming_activities.csv", bust_cache = FALSE) {
  if (!bust_cache && exists("activities", envir = .data_cache)) return(.data_cache$activities)
  if (!file.exists(path)) {
    message("CSV local no encontrado, descargando de GitHub...")
    path <- .github_download_csv("swimming_activities.csv")
  }
  d <- read_csv(path, show_col_types = FALSE) |>
    mutate(
      date             = as.Date(startTimeLocal),
      week             = floor_date(date, "week", week_start = 1),
      month            = floor_date(date, "month"),
      moving_dur_sec   = movingDuration,
      duration_min     = moving_dur_sec / 60,
      duration_total_min = duration / 60,
      pace_100m        = if_else(
        distance > 0 & !is.na(moving_dur_sec),
        (moving_dur_sec / 60) / (distance / 100),
        NA_real_
      ),
      distance_m       = distance,
      pool_length_m    = poolLengthMeters,
      largos           = numberOfActiveLengths
    )
  .data_cache$activities <- d
  d
}

load_laps <- function(path = "data/swimming_laps.csv", bust_cache = FALSE) {
  if (!bust_cache && exists("laps", envir = .data_cache)) return(.data_cache$laps)
  if (!file.exists(path)) {
    message("CSV local no encontrado, descargando de GitHub...")
    path <- .github_download_csv("swimming_laps.csv")
  }
  d <- read_csv(path, show_col_types = FALSE) |>
    mutate(
      swimStroke = tolower(coalesce(swimStroke, "unknown")),
      brazadas   = totalNumberOfStrokes,
      swolf      = averageSWOLF,
      cadencia   = averageSwimCadence
    )
  .data_cache$laps <- d
  d
}

bust_cache <- function() {
  rm(list = ls(.data_cache), envir = .data_cache)
}

filter_active_laps <- function(laps_df) {
  laps_df |> filter(lapType == "active", distance > 0)
}

stroke_labels <- c(
  freestyle    = "Crol",
  backstroke   = "Espalda",
  breaststroke = "Braza",
  butterfly    = "Mariposa",
  mixed        = "Mixto",
  drill        = "Técnica"
)

#' Calcula brazadas medias por sesión desde laps activos
compute_brazadas_per_session <- function(activities, laps) {
  active <- filter_active_laps(laps)
  braz_by_act <- active |>
    group_by(activityId) |>
    summarise(
      avg_brazadas  = mean(brazadas, na.rm = TRUE),
      min_brazadas  = min(brazadas, na.rm = TRUE),
      max_brazadas  = max(brazadas, na.rm = TRUE),
      med_brazadas  = median(brazadas, na.rm = TRUE),
      avg_swolf_lap = mean(swolf, na.rm = TRUE),
      avg_cadencia  = mean(cadencia, na.rm = TRUE),
      .groups = "drop"
    )
  activities |> left_join(braz_by_act, by = "activityId")
}

summarise_by_period <- function(activities, period = "week") {
  activities |>
    group_by(period_date = .data[[period]]) |>
    summarise(
      sessions           = n(),
      total_distance_m   = sum(distance_m, na.rm = TRUE),
      avg_swolf          = mean(averageSwolf, na.rm = TRUE),
      avg_brazadas       = mean(avg_brazadas, na.rm = TRUE),
      avg_pace_100m      = mean(pace_100m, na.rm = TRUE),
      avg_hr             = mean(averageHR, na.rm = TRUE),
      total_duration_min = sum(duration_min, na.rm = TRUE),
      avg_largos         = mean(largos, na.rm = TRUE),
      .groups = "drop"
    ) |>
    arrange(period_date)
}

format_pace <- function(pace) {
  mins <- floor(pace)
  secs <- round((pace - mins) * 60)
  sprintf("%d:%02d", mins, secs)
}
