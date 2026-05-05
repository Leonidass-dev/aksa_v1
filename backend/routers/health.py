"""
AKSA Backend — Sağlık Verisi Endpoint'leri
Redmi Watch 4 → Mi Fitness → Health Connect → Flutter → Backend → PostgreSQL
"""

from datetime import date
from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from auth import get_current_user
import crud

router = APIRouter()


# ── Request / Response Modelleri ───────────────────────────────────

class HealthRecordRequest(BaseModel):
    record_date: str = Field(
        default_factory=lambda: date.today().isoformat(),
        description="Tarih (YYYY-MM-DD)",
    )
    # Aktivite
    steps: float = Field(default=0, ge=0, description="Günlük adım sayısı")
    active_calories: float = Field(default=0, ge=0, description="Aktif yakılan kalori (kcal)")
    total_calories: float = Field(default=0, ge=0, description="Toplam yakılan kalori (kcal)")
    distance_m: float = Field(default=0, ge=0, description="Yürüme/koşma mesafesi (metre)")

    # Kardiyovasküler
    heart_rate: float = Field(default=0, ge=0, le=250, description="Ortalama nabız (bpm)")
    resting_heart_rate: float = Field(default=0, ge=0, le=250, description="Dinlenik nabız (bpm)")
    spo2: float = Field(default=0, ge=0, le=100, description="Kan oksijeni (%)")

    # Tansiyon
    systolic: float = Field(default=0, ge=0, le=300, description="Sistolik (mmHg)")
    diastolic: float = Field(default=0, ge=0, le=200, description="Diastolik (mmHg)")

    # Uyku (detaylı)
    sleep_hours: float = Field(default=0, ge=0, le=24, description="Toplam uyku süresi (saat)")
    sleep_deep_min: float = Field(default=0, ge=0, description="Derin uyku (dk)")
    sleep_light_min: float = Field(default=0, ge=0, description="Hafif uyku (dk)")
    sleep_rem_min: float = Field(default=0, ge=0, description="REM uyku (dk)")
    sleep_awake_min: float = Field(default=0, ge=0, description="Uyanıklık süresi (dk)")

    # Stres & Vücut
    stress_level: float = Field(default=0, ge=0, le=100, description="Stres seviyesi (0-100)")
    weight: float = Field(default=0, ge=0, le=500, description="Kilo (kg)")

    # Yeni Özellikler
    water_ml: float = Field(default=0, ge=0, description="Su içme (ml)")
    mood: str = Field(default="neutral", description="Ruh hali")

    # Meta
    source: str = Field(default="manual", description="Veri kaynağı: manual | health_connect")


class HealthRecordResponse(BaseModel):
    id: int
    record_date: str
    steps: float
    heart_rate: float
    resting_heart_rate: float
    spo2: float
    systolic: float
    diastolic: float
    sleep_hours: float
    sleep_deep_min: float
    sleep_light_min: float
    sleep_rem_min: float
    sleep_awake_min: float
    active_calories: float
    total_calories: float
    distance_m: float
    stress_level: float
    weight: float
    water_ml: float
    mood: str
    source: str

    class Config:
        from_attributes = True


def _record_to_response(r) -> HealthRecordResponse:
    return HealthRecordResponse(
        id=r.id,
        record_date=r.record_date.isoformat(),
        steps=r.steps or 0,
        heart_rate=r.heart_rate or 0,
        resting_heart_rate=r.resting_heart_rate or 0,
        spo2=r.spo2 or 0,
        systolic=r.systolic or 0,
        diastolic=r.diastolic or 0,
        sleep_hours=r.sleep_hours or 0,
        sleep_deep_min=r.sleep_deep_min or 0,
        sleep_light_min=r.sleep_light_min or 0,
        sleep_rem_min=r.sleep_rem_min or 0,
        sleep_awake_min=r.sleep_awake_min or 0,
        active_calories=r.active_calories or 0,
        total_calories=r.total_calories or 0,
        distance_m=r.distance_m or 0,
        stress_level=r.stress_level or 0,
        weight=r.weight or 0,
        water_ml=r.water_ml or 0,
        mood=r.mood or "neutral",
        source=r.source or "manual",
    )


# ── Endpoint'ler ──────────────────────────────────────────────────

@router.post("/health", response_model=HealthRecordResponse)
async def save_health(
    req: HealthRecordRequest,
    uid: str = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Günlük sağlık verisini kaydet.
    Aynı gün için tekrar çağrılırsa mevcut kaydı günceller (upsert).
    """
    user = await crud.get_or_create_user(db, uid)
    record = await crud.save_health_record(db, user, req.model_dump())
    return _record_to_response(record)


@router.get("/health", response_model=list[HealthRecordResponse])
async def get_health_history(
    days: int = Query(default=7, ge=1, le=365, description="Son kaç gün"),
    uid: str = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Son N günün sağlık kayıtlarını getir."""
    user = await crud.get_or_create_user(db, uid)
    records = await crud.get_health_records(db, user, days)
    return [_record_to_response(r) for r in records]


@router.get("/health/today", response_model=Optional[HealthRecordResponse])
async def get_today_health(
    uid: str = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Bugünün sağlık kaydını getir."""
    user = await crud.get_or_create_user(db, uid)
    record = await crud.get_today_health(db, user)
    if record is None:
        return None
    return _record_to_response(record)
