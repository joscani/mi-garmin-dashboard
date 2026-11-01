# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An R/Shiny dashboard for visualising swimming activities pulled from Garmin Connect. Two languages, one pipeline:

- **Python** (`src/`) downloads activities + individual lengths from Garmin Connect and writes CSVs.
- **R/Shiny** (`app.R`, `R/`) reads those CSVs and renders the interactive dashboard.

Code, comments and UI strings are in **Spanish**. Keep Garmin's own terminology: *brazadas* = strokes, *largos* = pool lengths, *SWOLF*, *crol* = freestyle.

## Common commands

```bash
# R dependencies (renv, pulls precompiled binaries from Posit PPM via .Rprofile)
R -e 'renv::restore()'

# Run the app locally
R -e 'shiny::runApp(port = 8080, launch.browser = FALSE)'

# Python dependencies
uv sync

# Fetch data from Garmin Connect (writes data/swimming_activities.csv + data/swimming_laps.csv)
uv run python src/fetch_swimming.py

# Local update: fetch + sync tokens/CSVs to the private data repo (used from crontab)
./scripts/update_garmin.sh   # logs to scripts/update_garmin.log

# Deploy to shinyapps.io
R -e 'rsconnect::deployApp(appName = "mi-garmin-dashboard", account = "canadasreche")'
```

There is **no test suite, linter, or build step**. Verify changes by running the app; `Rscript mejoras/verificar.R` runs ad-hoc data/module checks (quality consistency, m:ss formatting, modal re-open, KPI deltas).

## Data flow

```
Garmin Connect
  └─ src/fetch_swimming.py (auth via src/garmin_auth.py)
       └─ data/*.csv  →  pushed to private repo joscani/garmin-data (+ Garmin OAuth tokens)
            └─ Shiny app: R/utils_data.R loads CSVs
                 · local data/*.csv if present
                 · else downloads from raw.githubusercontent.com using DATA_GITHUB_PAT
                   (sent as an Authorization header via curl, never in the URL)
```

The CSVs and Garmin tokens live in the **separate private repo `joscani/garmin-data`**, never in this repo. Two independent updaters keep it fresh, both syncing tokens *and* CSVs back to that repo:

- `.github/workflows/update_data.yml` — GitHub Actions, twice daily.
- `scripts/update_garmin.sh` — local crontab alternative; expects the data repo checked out at `~/Proyectos/2026/garmin-data`.

### Secrets / env

- `TYPESAFE_API_KEY` / `TYPESAFE_APP_PASSWORD` (+ optional `TYPESAFE_MAX_POR_SESION`, `TYPESAFE_MAX_POR_DIA`) — enable the Jev card; bundled in `.Renviron` like the PAT.
- `DATA_GITHUB_PAT` — PAT with `repo` scope; read by `R/utils_data.R` to fetch CSVs, and by the updaters to push. In deployment it is supplied via a bundled `.Renviron` (shinyapps.io free tier has no env-var support). `.Renviron` and `.env` are gitignored.
- `GARMIN_EMAIL` / `GARMIN_PASSWORD` — only needed for a fresh login when no valid token exists.

## Garmin auth (`src/garmin_auth.py`)

Garmin's SSO rate-limits aggressively (HTTP 429). `get_client()` avoids SSO whenever possible: load saved tokens → try `refresh_oauth2` → if 429 but token still valid, use it as-is → if expired, try `oauth1→oauth2` exchange (no SSO) → last resort, fresh email/password login. On unrecoverable 429 the script exits **75** (`EX_TEMPFAIL`); both updaters treat 75 as "try again next run", not a failure.

## Shiny architecture

`app.R` is a plain script (not a package) that `source()`s every file in `R/`. Module naming: `mod_*` = Shiny modules (paired `_ui`/`_server`), `utils_*` = plain helpers.

- **`app.R` server** owns the reactive graph: `raw_data` (reactiveVal) → `activities_filtered` / `laps_filtered` (by date range) → `summary_data` (by week/month). These reactives are passed *as functions* into the module servers.
- **`R/mod_charts.R`** is an orchestrator only. It builds shared reactives (`active_laps`, `session_quality`, `sessions_ordered`) and delegates each dashboard tab to its own file: `mod_charts_evolucion.R`, `mod_charts_sesiones.R`, `mod_charts_resumen.R`, `mod_charts_comparar.R`. `mod_trend_chart.R` / `mod_lap_chart.R` are reusable chart sub-modules.
- **Interactivity** is ggplot2 + **ggiraph**. Use the `make_girafe()` helper and the shared `gi_*` option objects in `mod_charts.R`; clicking a point sets a girafe selection that drives the session-detail views.
- **Theming**: `bslib` (Bootstrap 5, flatly) + inline CSS in `app.R`; ggplot theme/palette in `R/utils_charts.R` (`theme_swim()`, `swim_palette`). Quality/stroke colours (`calidad_colors`, `calidad_bg`, `calidad_icon`, `stroke_colors`, `color_calidad()`), `format_duration()` and the range-aware date axis `scale_x_fecha()` also live there — use them instead of re-declaring colours or `"2 weeks"` breaks.
- **Layout**: `page_sidebar(fillable = FALSE)` so the page scrolls naturally (fillable squeezed charts into a strip under the KPIs). The date-range filter goes through `date_range_ok()` in `app.R`, which waits until both dates are picked.

## «Pregúntale al panel» (Jev, `R/mod_pregunta.R` + `R/utils_jev.R`)

Optional natural-language card: the user's text goes to TypeSafe's Jev (`POST https://api.typesafe.ai/v1/systemone`, via `curl` + `jsonlite`) as one request with ~10 Noul/Choice questions (`construir_preguntas()`). Jev only *selects* among options generated in code (candidate periods, session roles like `menos_brazadas`); R applies them through setters returned by `mod_filters_server()$set`, `nav_select("main_tabs", …)` and the `compare_request` reactiveVal passed down to `mod_comparar_server()`. Each Noul gates its Choice at 0.5.

- Shown only when `TYPESAFE_API_KEY` and `TYPESAFE_APP_PASSWORD` are set; password + per-session/daily limits guard the cost (daily counter is in-memory).
- Question wording was tuned against real calls (e.g. "brazadas" ≠ braza, "de marzo" ≠ group by month, period scope per compared session). Re-test representative phrases with real calls after editing questions.

## Data model (`R/utils_data.R`)

- **activities** = one row per swim session. **laps** = one row per individual length (`lapType == "active"` for real lengths, `"rest"` otherwise). Per-length stroke analysis always comes from **laps**, then joins back to activities.
- `compute_brazadas_per_session()` aggregates laps → per-session stroke stats (avg/min/max/median/IQR, `consistencia`) and left-joins onto activities. `app.R` does this enrichment right after loading.
- `compute_session_quality()` classifies each session **Muy buena / Buena / Regular / Mala** from the distribution of freestyle-length stroke counts (bands: ≤11 "buenos", 12–13 "normales", ≥14 "caros"). Thresholds live only in `resumir_calidad()`, which the Sesiones tab also calls after skipping the first lengths — adjust in one place.
- `format_pace()` rounds to whole seconds before splitting m:ss (also used for durations in the table).
- `load_laps()` pins `averageSwimCadence` to double; it is mostly empty and readr would otherwise guess logical and drop values.
- **Caching**: loaders memoise into the `.data_cache` environment. The sidebar "Recargar datos" button calls `bust_cache()` to force a re-read/re-download.
- **Column-name casing is inconsistent across the two CSVs** (Garmin's own field names): activities has `averageSwolf`, `averageHR`; laps has `averageSWOLF`, `averageSwimCadence`. `summarise_by_period()` reads the activities-side names. Check the actual CSV header when adding fields.

## Deploy notes

`rsconnect` deploys to shinyapps.io. `.rscignore` keeps the Python side (`src/`, `data/`, `pyproject.toml`, `uv.lock`, `.github`, tokens) out of the bundle. The app then loads data over the network via `DATA_GITHUB_PAT`.
