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


@router.post("/anomaly-check", response_model=AnomalyCheckResponse)
def check_anomaly(
    req: AnomalyCheckRequest,
    uid: str = Depends(get_current_user),
):
    """
    M7 — Anomali Tespiti (Z-Skor)

    history: son 3-7 günlük veriler,
    today: bugünün verisi.

    |z| >= 1.5 → medium, |z| >= 2.5 → high anomali
    """
    history = [_to_snapshot(s) for s in req.history]
    today = _to_snapshot(req.today)
    result = detect_anomalies(history, today)

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
