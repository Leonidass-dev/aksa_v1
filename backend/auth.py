"""
AKSA Backend — Firebase Token Doğrulama
Geliştirme modunda auth devre dışı bırakılabilir.
"""

import os
import logging
from typing import Optional
from fastapi import Header, HTTPException, status
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

    - DEV_MODE=true ise ve token yoksa güvenli geliştirici UID döner.
    - Canlı (production) ortamında DEV_MODE yok sayılır ve katı token doğrulaması zorunludur.
    - Token geçersizse veya auth yoksa → 401 Unauthorized.
    """
    env = os.getenv("ENVIRONMENT", "development").lower()
    is_production = env in ["production", "prod"]
    is_dev_mode = (os.getenv("DEV_MODE", "false").lower() == "true") and not is_production
    
    # Header yoksa
    if not authorization:
        if is_dev_mode:
            logger.debug(f"[DEV_MODE] Auth header eksik, varsayılan test kullanıcısı kullanılıyor: {DEV_MODE_UID}")
            return DEV_MODE_UID
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Yetkilendirme başlığı (Authorization header) eksik.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Bearer token çıkar
    token = authorization.replace("Bearer ", "").strip()
    if not token:
        if is_dev_mode:
            return DEV_MODE_UID
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Yetkilendirme token'ı bulunamadı.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Firebase başlatılmamışsa
    if not _firebase_initialized:
        if is_dev_mode:
            # Geliştirme ortamında imzasız token ayrıştırma yerine güvenli test UID'si kullan
            return DEV_MODE_UID
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Kimlik doğrulama servisi yapılandırılmamış.",
        )

    try:
        decoded = firebase_auth.verify_id_token(token)
        return decoded["uid"]
    except firebase_auth.ExpiredIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token süresi dolmuş. Lütfen tekrar giriş yapın.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except firebase_auth.InvalidIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Geçersiz yetkilendirme token'ı.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except Exception as e:
        logger.error(f"Token doğrulama hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Kimlik doğrulama başarısız.",
            headers={"WWW-Authenticate": "Bearer"},
        )
