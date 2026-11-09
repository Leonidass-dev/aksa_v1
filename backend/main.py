from contextlib import asynccontextmanager
import os
import logging
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from database import init_db
from routers import (
    risk,
    food,
    anomaly,
    exercise,
    assistant,
    health,
    data_pipeline,
    user,
)

# Global Rate Limiter (Dakikada 100 istek sınırı)
limiter = Limiter(key_func=get_remote_address, default_limits=["100/minute"])


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Uygulama başlarken DB tablolarını oluştur."""
    await init_db()
    yield


app = FastAPI(
    title="AKSA Backend",
    description="Akıllı Kişisel Sağlık Asistanı — AI + PostgreSQL Katmanı",
    version="2.0.0",
    lifespan=lifespan,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)


# Canlı ortamda ALLOWED_ORIGINS env var ile kısıtla
_allowed_origins = os.getenv(
    "ALLOWED_ORIGINS",
    "http://localhost:3000,http://10.0.2.2:3000,http://localhost:8000",
).split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(risk.router, prefix="/api", tags=["Risk Skoru"])
app.include_router(food.router, prefix="/api", tags=["Beslenme"])
app.include_router(anomaly.router, prefix="/api", tags=["Anomali"])
app.include_router(exercise.router, prefix="/api", tags=["Egzersiz"])
app.include_router(assistant.router, prefix="/api/assistant", tags=["Asistan"])
app.include_router(health.router, prefix="/api", tags=["Sağlık Verisi"])
app.include_router(data_pipeline.router, prefix="/api", tags=["Tez Veri Temizleme"])
app.include_router(user.router, prefix="/api", tags=["Kullanıcı"])

logger = logging.getLogger(__name__)


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Global unhandled error: {exc}", exc_info=True)
    is_dev_mode = os.getenv("DEV_MODE", "false").lower() == "true"
    # Canlı ortamda hassas iç hata detaylarını (DB/şema/yol) istemciye sızdırma
    detail_msg = (
        str(exc)
        if is_dev_mode
        else "Sunucu kaynaklı geçici bir hata oluştu. Lütfen daha sonra tekrar deneyiniz."
    )
    return JSONResponse(
        status_code=500,
        content={"error": "Sistem Hatası", "detail": detail_msg},
    )


@app.get("/")
def root():
    return {
        "status": "AKSA Backend çalışıyor 🚀",
        "version": "2.0.0",
        "database": "active",
    }
