#!/usr/bin/env bash
# Descarga datos de natación de Garmin Connect y sincroniza con repo de datos.
# Diseñado para ejecutarse desde crontab local (sin GitHub Actions).

set -euo pipefail

PROJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GARMIN_DATA_DIR="$HOME/Proyectos/2026/garmin-data"
LOG_FILE="$PROJ_DIR/scripts/update_garmin.log"

# Rotar log: conservar solo las últimas 500 líneas
if [[ -f "$LOG_FILE" ]]; then
    tail -500 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi

exec >> "$LOG_FILE" 2>&1
echo "=============================="
echo "$(date '+%Y-%m-%d %H:%M:%S') — Inicio"

cd "$PROJ_DIR"

# Cargar credenciales desde .env
if [[ -f "$PROJ_DIR/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$PROJ_DIR/.env"
    set +a
fi

# ── 1. Clonar/actualizar repo de datos ──────────────────────────────────────
if [[ -d "$GARMIN_DATA_DIR/.git" ]]; then
    echo "Actualizando repo garmin-data existente..."
    git -C "$GARMIN_DATA_DIR" pull --ff-only || true
else
    echo "Clonando repo garmin-data..."
    mkdir -p "$(dirname "$GARMIN_DATA_DIR")"
    git clone "https://github.com/joscani/garmin-data.git" "$GARMIN_DATA_DIR"
fi

# ── 2. Copiar tokens guardados del repo de datos → proyecto ─────────────────
if [[ -d "$GARMIN_DATA_DIR/.garminconnect" ]]; then
    echo "Restaurando tokens desde garmin-data..."
    cp "$GARMIN_DATA_DIR/.garminconnect/"* "$PROJ_DIR/.garminconnect/"
fi

# ── 3. Descargar datos de Garmin Connect ────────────────────────────────────
echo "Ejecutando fetch_swimming.py..."
FETCH_EXIT=0
uv run python src/fetch_swimming.py || FETCH_EXIT=$?

if [[ $FETCH_EXIT -eq 75 ]]; then
    echo "⚠  Rate limit (exit 75): tokens guardados pero sin datos nuevos. Se reintentará en la próxima ejecución."
elif [[ $FETCH_EXIT -ne 0 ]]; then
    echo "✗  Error inesperado (exit $FETCH_EXIT)."
    exit "$FETCH_EXIT"
fi

# ── 4. Guardar tokens actualizados en repo de datos ─────────────────────────
echo "Guardando tokens actualizados en garmin-data..."
cp "$PROJ_DIR/.garminconnect/"* "$GARMIN_DATA_DIR/.garminconnect/"
cd "$GARMIN_DATA_DIR"
git add .garminconnect/
if ! git diff --cached --quiet; then
    git commit -m "Actualizar tokens Garmin $(date '+%Y-%m-%d %H:%M')"
    git push
    echo "Tokens sincronizados con garmin-data."
else
    echo "Tokens sin cambios, nada que hacer."
fi

# ── 5. Subir CSVs si la descarga fue exitosa ─────────────────────────────────
if [[ $FETCH_EXIT -eq 0 ]]; then
    cp "$PROJ_DIR/data/swimming_activities.csv" "$GARMIN_DATA_DIR/"
    cp "$PROJ_DIR/data/swimming_laps.csv" "$GARMIN_DATA_DIR/"
    git add swimming_activities.csv swimming_laps.csv
    if ! git diff --cached --quiet; then
        git commit -m "Actualizar datos $(date '+%Y-%m-%d')"
        git push
        echo "CSVs actualizados en garmin-data."
    else
        echo "CSVs sin cambios."
    fi
fi

cd "$PROJ_DIR"
echo "$(date '+%Y-%m-%d %H:%M:%S') — Fin (exit $FETCH_EXIT)"
