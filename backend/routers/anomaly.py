from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from models.anomaly_model import DailySnapshot, detect_anomalies
from auth import get_current_user

router = APIRouter()


class DailySnapshotRequest(BaseModel):
    date: str = ""
    steps: float = Field(default=0, ge=0)
    sleep_hours: float = Field(default=0, ge=0, le=24)
    heart_rate: float = Field(default=0, ge=0, le=250)
    systolic: float = Field(default=0, ge=0, le=300)
    diastolic: float = Field(default=0, ge=0, le=200)
    spo2: float = Field(default=0, ge=0, le=100)
    weight: float = Field(default=0, ge=0, le=500)


class AnomalyCheckRequest(BaseModel):
    history: list[DailySnapshotRequest] = Field(
        description="Son 3-7 günün verisi (eskiden yeniye)"
    )
    today: DailySnapshotRequest


class AnomalyItemResponse(BaseModel):
    metric: str
    metric_label: str
    z_score: float
    today_value: float
    avg_value: float
    unit: str
    severity: str
    description: str
    recommendation: str


class AnomalyCheckResponse(BaseModel):
    has_anomaly: bool
    anomalies: list[AnomalyItemResponse]
    checked_metrics: int
    model_version: str


def _to_snapshot(r: DailySnapshotRequest) -> DailySnapshot:
    return DailySnapshot(
        date=r.date,
        steps=r.steps,
        sleep_hours=r.sleep_hours,
        heart_rate=r.heart_rate,
        systolic=r.systolic,
        diastolic=r.diastolic,
        spo2=r.spo2,
        weight=r.weight,
    )


from sqlalchemy.ext.asyncio import AsyncSession
from database import get_db
import crud

@router.post("/anomaly-check", response_model=AnomalyCheckResponse)
async def check_anomaly(
    req: AnomalyCheckRequest,
    uid: str = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    M7 — Anomali Tespiti (Z-Skor ve LSTM-AE)
    M2 (Data Pipeline) tarafından veritabanına kaydedilen "ml_features" array'ı bulunursa,
    sahte özellik matrisi yerine doğrudan M2'den gelen %100 temiz veriyi LSTM modeline besler.
    """
    history = [_to_snapshot(s) for s in req.history]
    today = _to_snapshot(req.today)

    # Veritabanından bugünün M2 pipeline temizlik sonuçlarını çek
    user = await crud.get_or_create_user(db, uid)
    today_record = await crud.get_today_health(db, user)
    ml_features = today_record.ml_features if today_record and hasattr(today_record, 'ml_features') else None

    # Modelle gönder
    result = detect_anomalies(history, today, ml_features=ml_features)

    return AnomalyCheckResponse(
        has_anomaly=result.has_anomaly,
        anomalies=[
            AnomalyItemResponse(
                metric=a.metric,
                metric_label=a.metric_label,
                z_score=a.z_score,
                today_value=a.today_value,
                avg_value=a.avg_value,
                unit=a.unit,
                severity=a.severity,
                description=a.description,
                recommendation=a.recommendation,
            )
            for a in result.anomalies
        ],
        checked_metrics=result.checked_metrics,
        model_version=result.model_version,
    )
