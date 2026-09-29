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
- **Pregúntale al panel** (opcional): cambia filtros, pestañas y compara sesiones escribiendo en lenguaje natural, con [Jev](https://docs.typesafe.ai) de TypeSafe
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
│   ├── mod_pregunta.R           # Módulo: «Pregúntale al panel» (Jev)
│   ├── utils_jev.R              # Cliente HTTP de TypeSafe y límites de uso
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
# opcional, para «Pregúntale al panel»:
echo "TYPESAFE_API_KEY=tu_clave" >> .Renviron
echo "TYPESAFE_APP_PASSWORD=una_contraseña_larga" >> .Renviron
```

```r
library(rsconnect)

rsconnect::setAccountInfo(
  name   = "tu_usuario",
  token  = "TU_TOKEN",
  secret = "TU_SECRET"
)

# .rscignore deja fuera la parte Python (src/, data/, tokens...)
rsconnect::deployApp(appName = "mi-garmin-dashboard", account = "tu_usuario")
```

> El `.Renviron` está en `.gitignore` — nunca se sube al repo.

## Pregúntale al panel (Jev)

Tarjeta encima de las pestañas donde escribes lo que quieres ver y el panel se ajusta solo. Usa **Jev**, el modelo *System One* de [TypeSafe](https://docs.typesafe.ai), que no genera texto: devuelve respuestas tipadas (sí/no con probabilidad, o una opción de una lista).

### Qué puede hacer

| Acción | Ejemplos |
|---|---|
| Cambiar el periodo | «enséñame marzo», «las últimas 4 semanas», «este año», «todo el historial» |
| Agrupar | «agrupa por meses», «semana a semana» |
| Filtrar por estilo | «solo crol», «los largos de braza» |
| Abrir una pestaña | «llévame al resumen», «quiero ver la tabla de datos», «cómo he evolucionado» |
| Comparar dos sesiones | «compara la última con la penúltima», «la más rápida de marzo frente a la más lenta de marzo» |
| Varias a la vez | «crol de los últimos 3 meses agrupado por semanas» |

Para comparar, cada sesión se describe por su papel: la última, la penúltima, la de menos / más brazadas por largo, la de mejor / peor SWOLF, la más rápida / lenta, la más larga / corta. Un periodo puede acotar las dos o solo una: en «compara la última con la de menos brazadas de marzo», *la última* es la más reciente de todas y *de marzo* solo acota la segunda.

**Ejemplo:** «compara la última con la de menos brazadas de marzo» → abre *Comparar* con la sesión del 27 de septiembre frente a la del 10 de marzo, y lo indica debajo:

> Comparar: la última sesión (27 septiembre 2026) vs la de menos brazadas por largo (10 marzo 2026)

### Qué no hace

- **No responde preguntas con datos** («¿cuántos metros nadé ayer?», «¿estoy mejorando?»): solo cambia lo que se ve. Como mucho te lleva al periodo mencionado.
- No elige un día concreto («la sesión del 12 de marzo») ni filtra por pulso, calorías, etc.
- Si no encuentra nada que hacer, responde «No sé hacer eso».

### Cómo funciona

Cada pregunta es **una sola llamada** a la API de TypeSafe con tu texto y la fecha de hoy, y 10 preguntas que Jev contesta en paralelo (`construir_preguntas()` en `R/mod_pregunta.R`): si menciona un periodo y cuál, si pide agrupar y cómo, estilo, pestaña, si pide comparar, qué dos sesiones y a cuál acota el periodo.

Jev **solo elige entre opciones que genera el código** (periodos candidatos, papeles de sesión…); R decide qué aplicar (umbral 0,5 en cada sí/no), busca qué sesión concreta es «la de menos brazadas» y cambia filtros y pestañas. Jev nunca inventa fechas ni ids.

### Configuración y coste

La tarjeta **solo aparece** si están definidas estas variables (en `.Renviron`, que va en el despliegue y está en `.gitignore`):

| Variable | Uso |
|---|---|
| `TYPESAFE_API_KEY` | Clave de TypeSafe. Solo se usa en el servidor, nunca llega al navegador |
| `TYPESAFE_APP_PASSWORD` | Contraseña para desbloquear la tarjeta (5 intentos por sesión) |
| `TYPESAFE_MAX_POR_SESION` | Preguntas por sesión de navegador (defecto 10) |
| `TYPESAFE_MAX_POR_DIA` | Preguntas al día entre todos los usuarios (defecto 50) |

Cada pregunta cuesta una llamada a TypeSafe. El contador diario vive en memoria: si shinyapps.io reinicia la app, vuelve a cero, así que es una red de seguridad, no un tope exacto. Textos de más de 200 caracteres se rechazan.

## Tecnologías

| Capa | Herramienta |
|------|-------------|
| Descarga de datos | Python + [garminconnect](https://github.com/cyberjunky/python-garminconnect) |
| Automatización | GitHub Actions |
| Almacenamiento datos | Repositorio privado de GitHub |
| App web | R + [Shiny](https://shiny.posit.co/) |
| UI | [bslib](https://rstudio.github.io/bslib/) (Bootstrap 5) |
| Gráficos | [ggplot2](https://ggplot2.tidyverse.org/) + [ggiraph](https://davidgohel.github.io/ggiraph/) |
| Lenguaje natural (opcional) | [TypeSafe](https://docs.typesafe.ai) — modelo Jev |
| Widgets UI | [shinyWidgets](https://dreamrs.github.io/shinyWidgets/) |
| Tablas | [DT](https://rstudio.github.io/DT/) |
| Dependencias R | [renv](https://rstudio.github.io/renv/) |
| Dependencias Python | [uv](https://docs.astral.sh/uv/) |
