from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession
from models.risk_model import HealthSnapshot, compute_risk
from database import get_db
from auth import get_current_user
import crud

router = APIRouter()


class RiskRequest(BaseModel):
    # Aktivite
    steps: float = Field(default=0, ge=0, description="Günlük adım sayısı")
    active_minutes: float = Field(default=0, ge=0)

    # Uyku
    sleep_hours: float = Field(default=0, ge=0, le=24)
    sleep_quality: float = Field(default=0, ge=0, le=100)

    # Kardiyovasküler
    heart_rate_avg: float = Field(default=0, ge=0, le=250)
    heart_rate_resting: float = Field(default=0, ge=0, le=250)
    spo2: float = Field(default=0, ge=0, le=100)

    # Stres
    stress_level: float = Field(default=0, ge=0, le=100)

    # Vücut
    weight: float = Field(default=0, ge=0, le=500)
    systolic: float = Field(default=0, ge=0, le=300)
    diastolic: float = Field(default=0, ge=0, le=200)

    # Profil
    age: int = Field(default=30, ge=1, le=120)
    gender: str = Field(default="M")
    height: float = Field(default=170.0, ge=50, le=280)


class RiskFactorResponse(BaseModel):
    name: str
    contribution: float
    description: str


from pydantic import BaseModel, ConfigDict

class RiskResponse(BaseModel):
    model_config = ConfigDict(protected_namespaces=())
    
    score: float
    level: str
    level_label: str
    top_factors: list[RiskFactorResponse]
    recommendations: list[str]
    model_version: str


class RiskHistoryItem(BaseModel):
    model_config = ConfigDict(protected_namespaces=())
    
    id: int
    score: float
    level: str
    level_label: str | None
    top_factors: list | None
    recommendations: list | None
    model_version: str
    calculated_at: str


LEVEL_LABELS = {
    "low": "Düşük Risk",
    "medium": "Orta Risk",
    "high": "Yüksek Risk",
}


@router.post("/risk-score", response_model=RiskResponse)
async def calculate_risk(
    req: RiskRequest,
    uid: str = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    M3 — Sağlık Risk Skoru Hesaplama

    Kullanıcının günlük sağlık verilerini alıp 0-100 arası risk skoru üretir.
    Sonucu PostgreSQL'e kaydeder.
    """
    snap = HealthSnapshot(
        steps=req.steps,
        active_minutes=req.active_minutes,
        sleep_hours=req.sleep_hours,
        sleep_quality=req.sleep_quality,
        heart_rate_avg=req.heart_rate_avg,
        heart_rate_resting=req.heart_rate_resting,
        spo2=req.spo2,
        stress_level=req.stress_level,
        weight=req.weight,
        systolic=req.systolic,
        diastolic=req.diastolic,
        age=req.age,
        gender=req.gender,
        height=req.height,
    )

    # Veritabanından bugünün M2 pipeline temizlik sonuçlarını çek
    user = await crud.get_or_create_user(db, uid)
    today_record = await crud.get_today_health(db, user)
    ml_features = today_record.ml_features if today_record and hasattr(today_record, 'ml_features') else None

    result = compute_risk(snap, ml_features=ml_features)
    level_label = LEVEL_LABELS.get(result.level, result.level)

    factors_response = [
        RiskFactorResponse(
            name=f.name,
            contribution=f.contribution,
            description=f.description,
        )
        for f in result.top_factors
    ]

    # DB'ye kaydet (user zaten yukarıda çekildi)
    await crud.save_risk_score(
        db, user,
        score=result.score,
        level=result.level,
        level_label=level_label,
        top_factors=[f.model_dump() for f in factors_response],
        recommendations=result.recommendations,
        model_version=result.model_version,
    )

    return RiskResponse(
        score=result.score,
        level=result.level,
        level_label=level_label,
        top_factors=factors_response,
        recommendations=result.recommendations,
        model_version=result.model_version,
    )


@router.get("/risk-history", response_model=list[RiskHistoryItem])
async def risk_history(
    limit: int = 30,
    uid: str = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Kullanıcının risk skoru geçmişini getirir."""
    user = await crud.get_or_create_user(db, uid)
    records = await crud.get_risk_history(db, user, limit)
    return [
        RiskHistoryItem(
            id=r.id,
            score=r.score,
            level=r.level,
            level_label=r.level_label,
            top_factors=r.top_factors,
            recommendations=r.recommendations,
            model_version=r.model_version,
            calculated_at=r.calculated_at.isoformat(),
        )
        for r in records
    ]


@router.get("/risk-score/demo", response_model=RiskResponse)
def demo_risk():
    """Demo veriyle risk skoru — bağlantı testi için."""
    snap = HealthSnapshot(
        steps=6500, sleep_hours=6.0, heart_rate_resting=78,
        systolic=128, diastolic=84, spo2=97, stress_level=45,
        age=28, gender="M", height=178,
    )
    result = compute_risk(snap)
    return RiskResponse(
        score=result.score,
        level=result.level,
        level_label=LEVEL_LABELS.get(result.level, result.level),
        top_factors=[
            RiskFactorResponse(name=f.name, contribution=f.contribution, description=f.description)
            for f in result.top_factors
        ],
        recommendations=result.recommendations,
        model_version=result.model_version,
    )
