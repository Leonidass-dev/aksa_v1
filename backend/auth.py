"""
AKSA Backend — Firebase Token Doğrulama
Geliştirme modunda auth devre dışı bırakılabilir.
"""

import os
import logging
from typing import Optional
from fastapi import Header, HTTPException
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

    - DEV_MODE=true ise ve token yoksa dev mode UID döner.
    - Token geçersizse veya auth yoksa → 401 Unauthorized.
    """
    is_dev_mode = os.getenv("DEV_MODE", "false").lower() == "true"
    
    # Header yoksa
    if not authorization:
        if is_dev_mode:
            return DEV_MODE_UID
        raise HTTPException(status_code=401, detail="Yetkilendirme başlığı (Authorization header) eksik.")

    # Bearer token çıkar
    token = authorization.replace("Bearer ", "").strip()
    if not token:
        if is_dev_mode:
            return DEV_MODE_UID
        raise HTTPException(status_code=401, detail="Token bulunamadı.")

    # Firebase başlatılmamışsa
    if not _firebase_initialized:
        if is_dev_mode:
            # Geliştirme kolaylığı için JWT payload kısmını base64 decode et
            try:
                import base64
                import json
                payload_b64 = token.split(".")[1]
                payload_b64 += "=" * ((4 - len(payload_b64) % 4) % 4)
                payload_json = base64.urlsafe_b64decode(payload_b64).decode("utf-8")
                decoded_unverified = json.loads(payload_json)
                return decoded_unverified.get("user_id", DEV_MODE_UID)
            except Exception:
                return DEV_MODE_UID
        raise HTTPException(status_code=500, detail="Firebase kimlik doğrulama yapılandırılmamış.")

    try:
        decoded = firebase_auth.verify_id_token(token)
        return decoded["uid"]
    except firebase_auth.ExpiredIdTokenError:
        raise HTTPException(
            status_code=401, detail="Token süresi dolmuş. Lütfen tekrar giriş yapın."
        )
    except firebase_auth.InvalidIdTokenError:
        raise HTTPException(status_code=401, detail="Geçersiz token.")
    except Exception as e:
        logger.error(f"Token doğrulama hatası: {e}")
        raise HTTPException(status_code=401, detail="Kimlik doğrulama başarısız.")
