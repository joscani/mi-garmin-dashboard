# Comprobaciones — rama `mejoras-dashboard` (2026-11-01)

Método: `Rscript mejoras/verificar.R` (salida en `mejoras/verificar_salida.txt`), capturas headless con chromote/chromium de las dos versiones (base = commit `9f97476` en worktree aparte) y autorrevisión del diff. No se ha usado un subagente revisor.

| requisito | evidencia | corrección |
|---|---|---|
| 1. Arranca y renderiza las 5 pestañas sin errores JS ni de R | Capturas de las 5 pestañas en escritorio (1400 px) y móvil (400 px): 0 errores JS y 0 avisos/errores en el log de R. La base tenía 1 aviso de parseo y 1 TypeError de DataTables en móvil | Ese TypeError salía también en la rama, provocado por el resize mientras se descargaba el idioma de DT desde la CDN. Ahora los textos van en línea (`DT_ES`) |
| 2a. B1 calidad en Sesiones | `verificar_salida.txt`: «calidad Sesiones == global en 190/190» y «Sesiones puede dar «Mala» (31)». En la base, las 31 «Mala» salían como «Regular» | `resumir_calidad()` única |
| 2b. B2 el modal no se reabría | `verificar.R`, testServer: 3 clics a la misma sesión → 3 aperturas | id + nonce en `selected_click` |
| 2c. B3 iconos de calidad | Revisión de código: `calidad_icon` cubre los 4 niveles | — |
| 2d. B4 calendario con fecha fija | Captura de Resumen: respeta el filtro; años en columnas proporcionales | Primer intento con `facet_wrap`: la semana de 2025 se estiraba a todo el ancho → `facet_grid(space="free_x")` |
| 2e. B5 filtros ocultos en móvil | `movil_filtros.R`: barra con filtros tras pulsar el botón = 0 px en la base, 400 px en la rama | — |
| 2f. B6 rango a medias | Revisión de código: `date_range_ok()` con `req(length==2, !anyNA)`. No probado en el navegador (el script no maneja el datepicker) | — |
| 2g. B7 cadencia perdida | `verificar_salida.txt`: «CSV sin avisos de parseo» | — |
| 2h. B8 token en la URL | Descarga real desde `joscani/garmin-data` con cabecera: 190 filas, mismas columnas. Un 404 da «HTTP 404» sin token en el mensaje | — |
| 2i. «2:60» por redondeo | `verificar_salida.txt`: `format_pace(2.999)=="3:00"`; ningún «:60» en datos reales (la base tenía 1) | — |
| 3. Calidad desde una sola función | `grep case_when` → solo `resumir_calidad()` tiene los umbrales | — |
| 4. Sin paquetes nuevos | `git diff --quiet renv.lock` → sin cambios. chromote solo en una librería del scratchpad | — |
| 5. Capturas antes/después + informe | `mejoras/comparativa.md`; capturas en el scratchpad de la sesión (no se commitean) | — |
| 6. Móvil | Captura de móvil de la rama: la página fluye y los filtros se abren | — |
| KPIs con delta | `verificar_salida.txt`: 3 meses → 60 sesiones en el periodo anterior, «↓ 2.2 SWOLF», «↓ 3" ritmo», «↑ 4% distancia» | Primer intento con 190 px: icono apilado y 6.º KPI en otra fila → `showcase_layout="top right"`, 165 px |
| Selección vacía de ggiraph | La reproducción de B2 destapó un error en `nchar(character(0)) > 0` | `length()>0 && nzchar()` en el trend chart y en Evolución |

## Pendiente / sin verificar
- B6 no se ha probado interactivamente con el datepicker.
- La tarjeta «Pregúntale al panel» no se ha probado con llamadas reales a Jev (no ha cambiado su código, pero ahora recibe la página con scroll).
- Las fechas salen en inglés («24 October 2026», «Jan 26»): depende del locale del servidor. Ya pasaba en la base y no se ha tocado.

## Despliegue (2026-11-01)
- Merge a master (fast-forward, `016ec07`) y deploy a shinyapps.io: la versión publicada carga 190 sesiones y da 0 errores JS.
- `.rscignore` corregido después (`22024aa`, `mejoras` sin barra final). El bundle publicado aún incluye `mejoras/` (solo documentación) hasta el próximo deploy.
- Push a `origin/master` hecho.
