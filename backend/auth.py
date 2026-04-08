"""
AKSA Backend — Firebase Token Doğrulama
Geliştirme modunda auth devre dışı bırakılabilir.
"""

import os
import logging
from typing import Optional
from fastapi import Header, HTTPException, Depends
from dotenv import load_dotenv

load_dotenv()
logger = logging.getLogger(__name__)

# Firebase Admin SDK — opsiyonel (yoksa dev mode)
_firebase_initialized = False

try:
    import firebase_admin
    from firebase_admin import credentials, auth as firebase_auth

    cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH", "")
    if cred_path and os.path.exists(cred_path):
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
        _firebase_initialized = True
        logger.info("✅ Firebase Admin SDK başlatıldı")
    else:
        logger.warning(
            "⚠️  Firebase credentials bulunamadı — DEV MODE: Auth devre dışı. "
            "Canlıda FIREBASE_CREDENTIALS_PATH ayarlanmalı."
        )
except ImportError:
    logger.warning("⚠️  firebase-admin yüklü değil — DEV MODE: Auth devre dışı.")


# ── Dev Mode Bypass UID ────────────────────────────────────────────
DEV_MODE_UID = os.getenv("DEV_MODE_UID", "dev-user-001")


async def get_current_user(
    authorization: Optional[str] = Header(None),
) -> str:
    """
    Firebase ID token doğrular ve uid döner.
    
    - Token yoksa veya Firebase başlatılmamışsa → dev mode UID döner.
    - Token geçersizse → 401 Unauthorized.
    """
    # Firebase başlatılmamışsa dev mode
    if not _firebase_initialized:
        return DEV_MODE_UID

    # Header yoksa dev mode
    if not authorization:
        return DEV_MODE_UID

    # Bearer token çıkar
    token = authorization.replace("Bearer ", "").strip()
    if not token:
        return DEV_MODE_UID

    try:
        decoded = firebase_auth.verify_id_token(token)
        return decoded["uid"]
    except firebase_auth.ExpiredIdTokenError:
        raise HTTPException(status_code=401, detail="Token süresi dolmuş. Lütfen tekrar giriş yapın.")
    except firebase_auth.InvalidIdTokenError:
        raise HTTPException(status_code=401, detail="Geçersiz token.")
    except Exception as e:
        logger.error(f"Token doğrulama hatası: {e}")
        raise HTTPException(status_code=401, detail="Kimlik doğrulama başarısız.")
