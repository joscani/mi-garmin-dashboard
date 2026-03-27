# Mi Garmin Dashboard 🏊

Dashboard interactivo en R/Shiny para visualizar tus actividades de natación descargadas de Garmin Connect.

**Demo en vivo:** https://canadasreche.shinyapps.io/mi-garmin-dashboard/

---

## ¿Qué hace?

- Descarga tus actividades de natación de Garmin Connect via Python, separando cada largo individual
- Visualiza KPIs (distancia, SWOLF, ritmo, brazadas, tiempo activo)
- Gráficos de evolución temporal interactivos (clicables para ver detalle de sesión)
- Análisis largo a largo de cada sesión con bandas de calidad (≤11, 12-13, ≥14 brazadas)
- Clasificación automática de sesiones: Muy buena / Buena / Regular / Mala (basada en % de largos de crol por franja de brazadas)
- Scatter interactivo brazadas vs ritmo /100m con boxplot por valor, vinculado a los filtros
- Calendario de actividad tipo GitHub (metros por día, verde escalonado)
- Selector de fechas moderno con navegación año → mes → día
- Filtros por rango de fechas y tipo de brazada
- Actualización automática de datos via GitHub Actions (dos veces al día)

## Arquitectura

```
Garmin Connect
      ↓  GitHub Actions (12:00 y 23:00 hora española)
Python fetch_swimming.py
      ↓
Repo privado GitHub (datos + tokens Garmin)
      ↓  DATA_GITHUB_PAT
Shiny app en shinyapps.io
```

Los datos CSV y los tokens de Garmin se guardan en un **repositorio privado separado** — no están en este repo.

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
│   └── garmin_auth.py           # Autenticación con Garmin Connect (tokens OAuth)
├── .github/
│   └── workflows/
│       └── update_data.yml      # GitHub Action: descarga y actualiza datos
├── data/                        # CSVs generados localmente (no en repo)
│   ├── swimming_activities.csv
│   └── swimming_laps.csv
├── .env.example                 # Plantilla de variables de entorno
├── renv.lock                    # Dependencias R (reproducible con renv)
└── pyproject.toml               # Dependencias Python (reproducible con uv)
```

## Cómo usarlo (fork)

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

## Configurar actualización automática (GitHub Actions)

El workflow `.github/workflows/update_data.yml` descarga los datos de Garmin y los sube a un repo privado dos veces al día.

### Repo privado de datos

Crea un repositorio privado en GitHub (ej: `garmin-data`) y sube los CSVs y los tokens:

```bash
mkdir garmin-data && cd garmin-data
git init
cp ../data/*.csv .
cp -r ../.garminconnect .
git add . && git commit -m "Initial data"
git remote add origin https://github.com/TU_USUARIO/garmin-data.git
git push -u origin main
```

### Secrets necesarios en el repo público

En **Settings → Secrets and variables → Actions** añade:

| Secret | Valor |
|--------|-------|
| `GARMIN_EMAIL` | Tu email de Garmin Connect |
| `GARMIN_PASSWORD` | Tu contraseña de Garmin Connect |
| `DATA_GITHUB_PAT` | Personal Access Token con permiso `repo` |

### Desplegar en shinyapps.io

El token `DATA_GITHUB_PAT` también debe estar disponible para la app. Como las cuentas gratuitas de shinyapps.io no soportan variables de entorno, se incluye un `.Renviron` en el despliegue:

```bash
echo "DATA_GITHUB_PAT=tu_token" > .Renviron
```

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
    ".Renviron"
  ),
  appName = "mi-garmin-dashboard",
  account = "tu_usuario"
)
```

> El `.Renviron` está en `.gitignore` — nunca se sube al repo.

## Tecnologías

| Capa | Herramienta |
|------|-------------|
| Descarga de datos | Python + [garminconnect](https://github.com/cyberjunky/python-garminconnect) |
| Automatización | GitHub Actions |
| Almacenamiento datos | Repositorio privado de GitHub |
| App web | R + [Shiny](https://shiny.posit.co/) |
| UI | [bslib](https://rstudio.github.io/bslib/) (Bootstrap 5) |
| Gráficos | [ggplot2](https://ggplot2.tidyverse.org/) + [ggiraph](https://davidgohel.github.io/ggiraph/) |
| Widgets UI | [shinyWidgets](https://dreamrs.github.io/shinyWidgets/) |
| Tablas | [DT](https://rstudio.github.io/DT/) |
| Dependencias R | [renv](https://rstudio.github.io/renv/) |
| Dependencias Python | [uv](https://docs.astral.sh/uv/) |
