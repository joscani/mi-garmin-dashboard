"""Autenticación con Garmin Connect con persistencia de tokens."""

import os
import time
from pathlib import Path

from garminconnect import (
    Garmin,
    GarminConnectAuthenticationError,
    GarminConnectTooManyRequestsError,
)

TOKEN_DIR = Path(__file__).parent.parent / ".garminconnect"

MAX_RETRIES = 5
INITIAL_WAIT = 30  # segundos


def _refresh_with_backoff(client: Garmin) -> bool:
    """Refresca el oauth2 token con reintentos y backoff exponencial."""
    for attempt in range(MAX_RETRIES):
        try:
            client.garth.refresh_oauth2()
            client.garth.dump(str(TOKEN_DIR))
            print("Token oauth2 refrescado correctamente.")
            return True
        except Exception as e:
            if "429" not in str(e):
                raise
            wait = INITIAL_WAIT * (2 ** attempt)
            print(f"Rate limit en refresco, esperando {wait}s (intento {attempt + 1}/{MAX_RETRIES})...")
            time.sleep(wait)
    return False


def get_client() -> Garmin:
    """Devuelve un cliente autenticado de Garmin Connect.

    Intenta reusar tokens guardados. Si el oauth2 ha expirado,
    lo refresca con reintentos y backoff exponencial.
    Como último recurso, hace login fresco con email/password.
    """
    email = os.environ.get("GARMIN_EMAIL")
    password = os.environ.get("GARMIN_PASSWORD")

    if TOKEN_DIR.exists():
        try:
            client = Garmin()
            client.garth.load(str(TOKEN_DIR))

            # Si el oauth2 está expirado, refrescarlo con reintentos
            if client.garth.oauth2_token.expired:
                print("Token oauth2 expirado, refrescando...")
                if _refresh_with_backoff(client):
                    return client
                print("No se pudo refrescar tras reintentos.")
            else:
                return client
        except Exception as e:
            print(f"Error cargando tokens: {e}")

    # Login fresco como último recurso
    if not email or not password:
        raise RuntimeError(
            "No hay tokens guardados y faltan GARMIN_EMAIL/GARMIN_PASSWORD en .env"
        )

    print("Haciendo login fresco con email/password...")
    client = Garmin(email, password)
    client.login()
    client.garth.dump(str(TOKEN_DIR))
    return client
