# Progreso

**Tarea:** analizar el dashboard Shiny, proponer mejoras, implementarlas en la rama `mejoras-dashboard` y compararlas con master. Restricciones: solo R/Shiny, sin paquetes nuevos, sin push ni deploy, sin commitear los cambios previos del usuario (`pyproject.toml`, `uv.lock`, `.dcf`, `ejemplo_jev*.py`).

**Salidas:**
- Rama `mejoras-dashboard` (cambios en `app.R`, `R/*.R`, `CLAUDE.md`, `.rscignore`)
- `mejoras/task.md` (entradas, criterios y hallazgos), `mejoras/checks.md`, `mejoras/comparativa.md`, `mejoras/verificar.R` + `mejoras/verificar_salida.txt`
- Capturas (no commiteadas): `/tmp/claude-1000/-home-jose-Proyectos-2026-mi-garmin-dashboars/13263a86-0b27-485c-b6e4-d65c37440573/scratchpad/shots_{base,new,base_movil,new_movil}/`

**Completado:**
1. Línea base: worktree de 9f97476, capturas y log (1 aviso de parseo, layout comprimido).
2. Revisión: 9 bugs, 8 de usabilidad y 1 de código (en `task.md`).
3. Implementación de todo lo listado.
4. Verificación: 15/15 en `verificar.R`; 0 errores JS y 0 avisos de R en las 5 pestañas, escritorio y móvil; descarga real desde GitHub con cabecera.

**Decisiones:**
- Arreglo de la base con `renv::restore()`: la librería estaba vacía para la plataforma `linux-omarchy-4.0.6`.
- Barras apiladas en vez de líneas de % para la calidad por periodo.
- Calendario en columnas por año (`facet_grid space=free_x`) tras ver que `facet_wrap` deformaba los años parciales.
- KPIs con `showcase_layout = "top right"` tras ver que a 190 px bslib apilaba el icono.
- Autorrevisión del diff en lugar de subagente.

5. Aceptado por el usuario: merge a master (`016ec07`), deploy a shinyapps.io (190 sesiones, 0 errores JS), arreglo de `.rscignore` (`22024aa`) y push. Rama `mejoras-dashboard` y worktree base eliminados.

**Fallos abiertos:** B6 sin prueba interactiva; Jev sin prueba real; fechas en inglés (locale, ya pasaba antes); el bundle publicado incluye `mejoras/` hasta el próximo deploy.

**Siguiente acción:** ninguna obligatoria. En el próximo deploy, comprobar que `mejoras/` ya no entra en el bundle.
