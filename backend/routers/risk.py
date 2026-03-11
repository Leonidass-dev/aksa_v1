from fastapi import APIRouter
from pydantic import BaseModel, Field
from models.risk_model import HealthSnapshot, compute_risk

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


class RiskResponse(BaseModel):
    score: float
    level: str
    level_label: str
    top_factors: list[RiskFactorResponse]
    recommendations: list[str]
    model_version: str


LEVEL_LABELS = {
    "low": "Düşük Risk",
    "medium": "Orta Risk",
    "high": "Yüksek Risk",
}


@router.post("/risk-score", response_model=RiskResponse)
def calculate_risk(req: RiskRequest):
    """
    M3 — Sağlık Risk Skoru Hesaplama

    Kullanıcının günlük sağlık verilerini alıp 0-100 arası risk skoru üretir.
    - 0–33: Düşük risk
    - 34–66: Orta risk
    - 67–100: Yüksek risk
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

    result = compute_risk(snap)

    return RiskResponse(
        score=result.score,
        level=result.level,
        level_label=LEVEL_LABELS.get(result.level, result.level),
        top_factors=[
            RiskFactorResponse(
                name=f.name,
                contribution=f.contribution,
                description=f.description,
            )
            for f in result.top_factors
        ],
        recommendations=result.recommendations,
        model_version=result.model_version,
    )


@router.get("/risk-score/demo", response_model=RiskResponse)
def demo_risk():
    """Demo veriyle risk skoru — bağlantı testi için."""
    from models.risk_model import HealthSnapshot
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
