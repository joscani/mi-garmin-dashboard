# Mi Garmin Dashboard 🏊

Dashboard interactivo en R/Shiny para visualizar tus actividades de natación descargadas de Garmin Connect.

**Demo en vivo:** https://canadasreche.shinyapps.io/mi-garmin-dashboard/

---

## ¿Qué hace?

- Descarga tus actividades de natación de Garmin Connect via Python
- Visualiza KPIs (distancia, SWOLF, ritmo, brazadas, tiempo activo)
- Gráficos de evolución temporal interactivos (clicables para ver detalle de sesión)
- Análisis largo a largo de cada sesión (brazadas, SWOLF, estilo)
- Filtros por rango de fechas y tipo de brazada

## Estructura del proyecto

```
├── app.R                        # App Shiny principal
├── R/
│   ├── mod_kpis.R               # Módulo: tarjetas KPI
│   ├── mod_charts.R             # Módulo: gráficos (evolución, por largo, resumen)
│   ├── mod_filters.R            # Módulo: filtros laterales
│   ├── mod_table.R              # Módulo: tabla de actividades
│   ├── utils_data.R             # Carga, caché y transformación de datos
│   └── utils_charts.R           # Tema ggplot2 y paleta de colores
├── src/
│   ├── fetch_swimming.py        # Script de descarga de datos desde Garmin Connect
│   └── garmin_auth.py           # Autenticación con Garmin Connect (tokens)
├── data/                        # CSVs generados por el script Python (no en repo)
│   ├── swimming_activities.csv
│   └── swimming_laps.csv
├── .env.example                 # Plantilla de variables de entorno
├── renv.lock                    # Dependencias R (reproducible con renv)
└── pyproject.toml               # Dependencias Python (reproducible con uv)
```

## Cómo usarlo

### 1. Requisitos

- R >= 4.2
- Python >= 3.11
- [uv](https://docs.astral.sh/uv/) (gestor de paquetes Python)

### 2. Clonar y configurar

```bash
git clone https://github.com/joscani/mi-garmin-dashboard
cd mi-garmin-dashboard
```

Copia el fichero de ejemplo y rellena tus credenciales de Garmin Connect:

```bash
cp .env.example .env
# edita .env con tu email y contraseña de Garmin Connect
```

### 3. Descargar tus datos de Garmin

```bash
# Instalar dependencias Python
uv sync

# Ejecutar la descarga (últimos 2 años de natación)
uv run python src/fetch_swimming.py
```

Esto genera `data/swimming_activities.csv` y `data/swimming_laps.csv`.

> La primera vez pedirá autenticación con Garmin Connect y guardará los tokens en `.garminconnect/` para no volver a pedir credenciales.

### 4. Lanzar la app

```r
# Instalar dependencias R
renv::restore()

# Arrancar
shiny::runApp()
```

## Desplegar en shinyapps.io

```r
library(rsconnect)

rsconnect::setAccountInfo(
  name   = "tu_usuario",
  token  = "TU_TOKEN",
  secret = "TU_SECRET"
)

rsconnect::deployApp(
  appFiles = c(
    "app.R",
    "R/mod_charts.R", "R/mod_filters.R", "R/mod_kpis.R",
    "R/mod_table.R", "R/utils_charts.R", "R/utils_data.R",
    "data/swimming_activities.csv", "data/swimming_laps.csv"
  ),
  appName = "mi-garmin-dashboard",
  account = "tu_usuario"
)
```

> Los CSVs se incluyen en el despliegue pero no están en el repo. Tienes que generarlos localmente primero con el script Python.

## Tecnologías

| Capa | Herramienta |
|------|-------------|
| Descarga de datos | Python + [garminconnect](https://github.com/cyberjunky/python-garminconnect) |
| App web | R + [Shiny](https://shiny.posit.co/) |
| UI | [bslib](https://rstudio.github.io/bslib/) (Bootstrap 5) |
| Gráficos | [ggplot2](https://ggplot2.tidyverse.org/) + [ggiraph](https://davidgohel.github.io/ggiraph/) |
| Tablas | [DT](https://rstudio.github.io/DT/) |
| Dependencias R | [renv](https://rstudio.github.io/renv/) |
| Dependencias Python | [uv](https://docs.astral.sh/uv/) |
