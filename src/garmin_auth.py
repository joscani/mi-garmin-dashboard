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

RETRY_WAIT = 120  # segundos de espera antes del único reintento por 429


class GarminRateLimitError(RuntimeError):
    """Garmin SSO está bloqueando por rate limit (429)."""


def _refresh_oauth2(client: Garmin) -> None:
    """Refresca el oauth2 usando el oauth1 token (no pasa por SSO).

    Si Garmin devuelve 429, espera RETRY_WAIT segundos y lo intenta una vez más.
    Si vuelve a fallar, lanza GarminRateLimitError.
    """
    for attempt in (1, 2):
        try:
            client.garth.refresh_oauth2()
            client.garth.dump(str(TOKEN_DIR))
            print("Token oauth2 refrescado correctamente.")
            return
        except Exception as e:
            if "429" in str(e):
                if attempt == 1:
                    print(f"Rate limit (429), esperando {RETRY_WAIT}s antes de reintentar...")
                    time.sleep(RETRY_WAIT)
                else:
                    raise GarminRateLimitError("Rate limit en refresh_oauth2 (429) tras reintento") from e
            else:
                raise


def get_client() -> Garmin:
    """Devuelve un cliente autenticado de Garmin Connect.

    Estrategia:
    1. Cargar tokens guardados.
    2. Si oauth2 expirado, refrescar via oauth1 (sin SSO).
    3. Si el refresh falla por 429, abortar — no intentar login SSO.
    4. Solo si no hay tokens en absoluto, hacer login fresco con email/password.
    """
    email = os.environ.get("GARMIN_EMAIL")
    password = os.environ.get("GARMIN_PASSWORD")

    if TOKEN_DIR.exists():
        client = Garmin()
        client.garth.load(str(TOKEN_DIR))

        if client.garth.oauth2_token.expired:
            print("Token oauth2 expirado, refrescando via oauth1...")
            _refresh_oauth2(client)  # lanza GarminRateLimitError si 429

        return client

    # Sin tokens guardados: login fresco
    if not email or not password:
        raise RuntimeError(
            "No hay tokens guardados y faltan GARMIN_EMAIL/GARMIN_PASSWORD"
        )

    print("Sin tokens guardados, haciendo login fresco...")
    client = Garmin(email, password)
    client.login()
    client.garth.dump(str(TOKEN_DIR))
    return client
