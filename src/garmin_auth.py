"""Autenticación con Garmin Connect con persistencia de tokens."""

import os
from pathlib import Path

from garminconnect import (
    Garmin,
    GarminConnectAuthenticationError,
)

TOKEN_DIR = Path(__file__).parent.parent / ".garminconnect"


def get_client() -> Garmin:
    """Devuelve un cliente autenticado de Garmin Connect.

    Intenta reusar tokens guardados. Si no existen o han expirado,
    hace login con email/password del .env y guarda los tokens nuevos.
    """
    email = os.environ.get("GARMIN_EMAIL")
    password = os.environ.get("GARMIN_PASSWORD")

    # Intentar reanudar sesión con tokens guardados
    if TOKEN_DIR.exists():
        try:
            client = Garmin()
            client.login(str(TOKEN_DIR))
            return client
        except GarminConnectAuthenticationError:
            pass  # Tokens expirados, hacer login nuevo

    # Login fresco
    if not email or not password:
        raise RuntimeError(
            "No hay tokens guardados y faltan GARMIN_EMAIL/GARMIN_PASSWORD en .env"
        )

    client = Garmin(email, password)
    client.login()
    client.garth.dump(str(TOKEN_DIR))
    return client
