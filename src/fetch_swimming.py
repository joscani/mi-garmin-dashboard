"""Descarga actividades de natación de Garmin Connect y las guarda como CSV para R."""

import csv
import time
from datetime import date
from pathlib import Path

from dotenv import load_dotenv

from garmin_auth import get_client

DATA_DIR = Path(__file__).parent.parent / "data"
ACTIVITIES_CSV = DATA_DIR / "swimming_activities.csv"
LAPS_CSV = DATA_DIR / "swimming_laps.csv"

ACTIVITY_FIELDS = [
    "activityId",
    "activityName",
    "startTimeLocal",
    "distance",
    "duration",
    "elapsedDuration",
    "movingDuration",
    "averageSwolf",
    "averageStrokeCadenceInStrokesPerMinute",
    "poolLengthMeters",
    "numberOfActiveLengths",
    "numberOfLengths",
    "calories",
    "averageHR",
    "maxHR",
]

LAP_FIELDS = [
    "activityId",
    "lapIndex",
    "lapType",
    "distance",
    "duration",
    "averageSWOLF",
    "totalNumberOfStrokes",
    "averageStrokes",
    "averageSwimCadence",
    "swimStroke",
    "averageHR",
    "maxHR",
]


def extract_pool_length_meters(act: dict) -> float | None:
    """Extrae la longitud de la piscina en metros."""
    pool_length = act.get("poolLength")
    if pool_length is None:
        return None
    unit = act.get("unitOfPoolLength")
    # unitOfPoolLength puede ser un dict con unitKey o un string
    if isinstance(unit, dict):
        unit_key = unit.get("unitKey", "meter")
    elif isinstance(unit, str):
        unit_key = unit
    else:
        unit_key = "meter"
    # poolLength de Garmin viene en centímetros
    if pool_length > 100:
        return pool_length / 100.0
    return pool_length


def fetch_activities(client, start_date: str, end_date: str) -> list[dict]:
    """Obtiene todas las actividades de natación en un rango de fechas."""
    print(f"Buscando actividades de natación desde {start_date} hasta {end_date}...")
    activities = client.get_activities_by_date(
        startdate=start_date,
        enddate=end_date,
        activitytype="swimming",
    )
    print(f"  Encontradas {len(activities)} actividades de natación")
    return activities


def fetch_laps(client, activity_id: int) -> list[dict]:
    """Obtiene los laps/splits de una actividad, clasificando activos vs descanso."""
    try:
        splits = client.get_activity_splits(activity_id)
        laps_raw = splits.get("lapDTOs", [])
        laps = []
        for i, lap in enumerate(laps_raw):
            distance = lap.get("distance", 0) or 0
            strokes = lap.get("totalNumberOfStrokes", 0) or 0
            # Lap activo = tiene distancia > 0
            lap_type = "active" if distance > 0 else "rest"
            laps.append(
                {
                    "activityId": activity_id,
                    "lapIndex": i,
                    "lapType": lap_type,
                    "distance": distance,
                    "duration": lap.get("duration"),
                    "averageSWOLF": lap.get("averageSWOLF"),
                    "totalNumberOfStrokes": strokes,
                    "averageStrokes": lap.get("averageStrokes"),
                    "averageSwimCadence": lap.get("averageSwimCadence"),
                    "swimStroke": lap.get("swimStroke"),
                    "averageHR": lap.get("averageHR"),
                    "maxHR": lap.get("maxHR"),
                }
            )
        return laps
    except Exception as e:
        print(f"  Error obteniendo laps para {activity_id}: {e}")
        return []


def save_csv(filepath: Path, rows: list[dict], fields: list[str]):
    """Guarda una lista de dicts como CSV."""
    filepath.parent.mkdir(parents=True, exist_ok=True)
    with open(filepath, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    print(f"Guardado {len(rows)} filas en {filepath}")


def main():
    load_dotenv()
    client = get_client()

    # Descargar últimos 2 años de natación
    end = date.today().isoformat()
    start = date(date.today().year - 2, date.today().month, date.today().day).isoformat()

    activities = fetch_activities(client, start, end)

    # Extraer campos relevantes de cada actividad
    activity_rows = []
    for act in activities:
        row = {}
        for field in ACTIVITY_FIELDS:
            if field == "poolLengthMeters":
                row[field] = extract_pool_length_meters(act)
            else:
                val = act.get(field)
                if val is None:
                    # Buscar en summaryDTO
                    summary = act.get("summaryDTO", {})
                    val = summary.get(field)
                row[field] = val

        # numberOfActiveLengths: calcular si no viene
        if not row.get("numberOfActiveLengths") and row.get("distance") and row.get("poolLengthMeters"):
            pool_m = row["poolLengthMeters"]
            if pool_m and pool_m > 0:
                row["numberOfActiveLengths"] = int(round(row["distance"] / pool_m))

        activity_rows.append(row)

    save_csv(ACTIVITIES_CSV, activity_rows, ACTIVITY_FIELDS)

    # Descargar laps de cada actividad
    all_laps = []
    for i, act in enumerate(activities):
        aid = act["activityId"]
        print(f"  Descargando laps {i + 1}/{len(activities)} (ID: {aid})...")
        laps = fetch_laps(client, aid)
        all_laps.extend(laps)
        time.sleep(0.5)  # Respetar rate limits

    save_csv(LAPS_CSV, all_laps, LAP_FIELDS)
    print("¡Descarga completada!")


if __name__ == "__main__":
    main()
