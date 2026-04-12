"""Autenticación con Garmin Connect con persistencia de tokens."""

import os
import random
import time
from pathlib import Path

from garminconnect import Garmin
from garth import sso as garth_sso

TOKEN_DIR = Path(__file__).parent.parent / ".garminconnect"

RETRY_WAIT = 180  # segundos de espera antes del único reintento por 429
INITIAL_JITTER_MAX = 120  # jitter aleatorio antes de autenticar (segundos)


class GarminRateLimitError(RuntimeError):
    """Garmin SSO está bloqueando por rate limit (429)."""


def _try_refresh_oauth2(client: Garmin) -> bool:
    """Intenta refrescar oauth2. Devuelve True si lo consigue, False si 429."""
    for attempt in (1, 2):
        try:
            client.garth.refresh_oauth2()
            client.garth.dump(str(TOKEN_DIR))
            print("Token oauth2 refrescado correctamente.")
            return True
        except Exception as e:
            if "429" in str(e):
                if attempt == 1:
                    wait = RETRY_WAIT + random.randint(0, 60)
                    print(f"Rate limit (429), esperando {wait}s antes de reintentar...")
                    time.sleep(wait)
                else:
                    return False
            else:
                raise


def _try_exchange_oauth1(client: Garmin) -> bool:
    """Obtiene un nuevo oauth2 usando el oauth1 (no pasa por SSO, evita 429).
    Devuelve True si lo consigue, False si falla."""
    try:
        print("Intentando exchange oauth1 -> oauth2 (sin SSO)...")
        new_oauth2 = garth_sso.exchange(client.garth.oauth1_token, client.garth)
        client.garth.oauth2_token = new_oauth2
        client.garth.dump(str(TOKEN_DIR))
        remaining_h = (new_oauth2.expires_at - time.time()) / 3600
        print(f"Exchange exitoso. Nuevo token válido por {remaining_h:.1f}h")
        return True
    except Exception as e:
        print(f"Exchange oauth1 falló: {e}")
        return False


def get_client() -> Garmin:
    """Devuelve un cliente autenticado de Garmin Connect.

    Estrategia con cron cada 12h:
    1. Cargar tokens guardados.
    2. Siempre intentar refrescar el token (para renovar las ~21h de vida).
    3. Si el refresh falla por 429 pero el token aún no ha expirado →
       usarlo tal cual (la próxima ejecución en 12h lo reintentará).
    4. Si el token ya expiró Y el refresh falló → intentar exchange oauth1→oauth2.
    5. Si el exchange también falla → login fresco con email/password.
    6. Solo si no hay tokens → login fresco con email/password.
    """
    email = os.environ.get("GARMIN_EMAIL")
    password = os.environ.get("GARMIN_PASSWORD")

    # Jitter aleatorio para evitar que runners de GH Actions golpeen Garmin SSO al mismo tiempo
    if os.environ.get("CI"):
        jitter = random.randint(0, INITIAL_JITTER_MAX)
        print(f"CI detectado, esperando {jitter}s de jitter antes de autenticar...")
        time.sleep(jitter)

    if TOKEN_DIR.exists():
        client = Garmin()
        client.garth.load(str(TOKEN_DIR))

        has_oauth1 = client.garth.oauth1_token is not None
        expired = client.garth.oauth2_token.expired
        remaining_h = (client.garth.oauth2_token.expires_at - int(time.time())) / 3600
        print(f"Token oauth2: {'expirado' if expired else f'válido ({remaining_h:.1f}h restantes)'}")
        print(f"Token oauth1: {'presente' if has_oauth1 else 'NO disponible'}")
        print("Intentando refrescar token...")

        refreshed = _try_refresh_oauth2(client)

        if not refreshed and expired:
            # Fallback 1: exchange oauth1 -> oauth2 sin pasar por SSO
            if client.garth.oauth1_token:
                if _try_exchange_oauth1(client):
                    return client

            # Fallback 2: login fresco con email/password
            if email and password:
                print("Token expirado y exchange fallido, intentando login fresco...")
                try:
                    client = Garmin(email, password)
                    client.login()
                    client.garth.dump(str(TOKEN_DIR))
                    return client
                except Exception as e:
                    if "429" in str(e):
                        raise GarminRateLimitError(
                            "Token expirado, exchange y login fresco bloqueados por 429"
                        ) from e
                    raise
            raise GarminRateLimitError(
                "Token expirado, exchange fallido y sin credenciales para login fresco"
            )
        if not refreshed:
            print("Refresh falló por 429, pero el token aún es válido. Continuando.")

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
