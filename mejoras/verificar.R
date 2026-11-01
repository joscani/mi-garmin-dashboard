# Comprobaciones de la rama mejoras-dashboard (no hay suite de tests en el proyecto).
# Uso: Rscript mejoras/verificar.R   (desde la raíz del repo, con data/*.csv local)
suppressMessages({
  library(shiny); library(bslib); library(dplyr)
  for (f in c("R/utils_data.R", "R/utils_charts.R", "R/mod_filters.R", "R/mod_kpis.R",
              "R/mod_charts.R", "R/mod_table.R", "R/utils_jev.R", "R/mod_pregunta.R")) source(f)
})
ok <- function(cond, msg) { cat(if (isTRUE(cond)) "PASA " else "FALLA", msg, "\n"); invisible(cond) }

# Sin avisos de parseo al leer los CSV (B7)
w <- character(0)
withCallingHandlers({ acts <- load_activities(); laps <- load_laps() },
                    warning = function(x) { w <<- c(w, conditionMessage(x)); invokeRestart("muffleWarning") })
ok(length(w) == 0, sprintf("CSV sin avisos de parseo (%d avisos)", length(w)))
ok(sum(!is.na(laps$averageSwimCadence)) > 0 || all(is.na(read.csv("data/swimming_laps.csv")$averageSwimCadence)),
   "averageSwimCadence conserva los valores del CSV")
acts <- compute_brazadas_per_session(acts, laps)

# Calidad: la pestaña Sesiones (sin quitar largos) coincide con compute_session_quality (B1)
global <- compute_session_quality(laps)
por_sesion <- bind_rows(lapply(unique(global$activityId), function(id)
  resumir_calidad(filter_active_laps(laps) |> filter(activityId == id, swimStroke == "freestyle"))))
m <- inner_join(global, por_sesion, by = "activityId", suffix = c("", ".s"))
ok(nrow(m) == nrow(global) && all(m$calidad == m$calidad.s),
   sprintf("calidad Sesiones == global en %d/%d sesiones", sum(m$calidad == m$calidad.s), nrow(global)))
ok("Mala" %in% por_sesion$calidad, sprintf("Sesiones puede dar «Mala» (%d)", sum(por_sesion$calidad == "Mala")))
print(table(global$calidad))

# Formato m:ss sin «:60» (redondeo)
ok(format_pace(2.999) == "3:00" && format_pace(1.5) == "1:30", "format_pace(2.999) == 3:00")
ok(!any(grepl(":60$", c(format_pace(acts$pace_100m), format_pace(acts$duration_min)))), "ningún «:60» en datos reales")
ok(format_duration(NA) == "—" && format_duration(NULL) == "—" && format_duration(65) == "1h 05min",
   "format_duration con NA/NULL/65")
ok(color_calidad("Mala") == "#b91c1c" && color_calidad(NA) == "#64748b", "color_calidad con NA")

# KPIs: delta frente al periodo anterior
ok(is.null(kpi_delta_tag(NA, 3)), "kpi_delta_tag sin datos → NULL")
ok(grepl("kpi-mejor", as.character(kpi_delta_tag(40, 45, lower_is_better = TRUE))), "SWOLF menor = mejor")

# Modal de Evolución: volver a clicar la misma sesión dispara otra vez (B2)
mod_evolucion_server_test <- function() {
  n_modal <- 0
  shiny::testServer(mod_evolucion_server,
    args = list(activities = reactive(acts),
                sessions_ordered = reactive(acts |> left_join(global, by = "activityId") |> arrange(desc(date))),
                laps = reactive(laps)), {
      id <- as.character(acts$activityId[1])
      session$setInputs(`strokes_evolution-plot_selected` = id); session$flushReact()
      v1 <- selected_click()$nonce
      # deseleccionar y volver a seleccionar el mismo punto
      session$setInputs(`strokes_evolution-plot_selected` = character(0)); session$flushReact()
      Sys.sleep(0.01)
      session$setInputs(`strokes_evolution-plot_selected` = id); session$flushReact()
      v2 <- selected_click()$nonce
      # misma sesión desde otro gráfico
      Sys.sleep(0.01)
      session$setInputs(`pace_evolution-plot_selected` = id); session$flushReact()
      v3 <- selected_click()$nonce
      n_modal <<- length(unique(c(v1, v2, v3)))
    })
  n_modal
}
ok(mod_evolucion_server_test() == 3, "modal se reabre al reclicar la misma sesión (3 clics → 3 aperturas)")

# KPIs: con 3 meses hay periodo anterior con datos → aparecen los deltas (U5)
fin <- max(acts$date); dr <- c(fin - 90, fin)
shiny::testServer(mod_kpis_server,
  args = list(activities = reactive(acts |> filter(date >= dr[1], date <= dr[2])),
              activities_all = reactive(acts), date_range = reactive(dr)), {
    ok(!is.null(previo()) && previo()$sessions > 0,
       sprintf("periodo anterior con %d sesiones", previo()$sessions))
    html <- output$swolf_delta$html
    ok(grepl("vs periodo anterior", html), paste("delta SWOLF:", gsub("<[^>]+>", "", html)))
    cat("     ritmo:", gsub("<[^>]+>", "", output$pace_delta$html),
        "| distancia:", gsub("<[^>]+>", "", output$distance_delta$html), "\n")
  })
