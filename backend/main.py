from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database import init_db
from routers import risk, food, anomaly, exercise, assistant, health

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

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Geliştirme için — canlıda kısıtla
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


@app.get("/")
def root():
    return {"status": "AKSA Backend çalışıyor 🚀", "version": "2.0.0", "database": "active"}
