"""
M7 — Anomali Tespiti
LSTM-AE varsa kullanır, yoksa sadece Z-Skor tabanlı fallback.
"""

from dataclasses import dataclass, field
import math
import logging
import numpy as np
import os
import sys

logger = logging.getLogger(__name__)

# ── ML Import (Opsiyonel) ──────────────────────────────────────────
_HAS_ML = False
try:
    import torch
    import joblib
    sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from ml_models.lstm_ae_model import LSTMAutoencoder
    _HAS_ML = True
    logger.info("✅ Anomali modeli: LSTM-AE yüklendi")
except ImportError as e:
    logger.warning(f"⚠️  LSTM-AE yüklenemedi ({e}) — Z-Skor fallback aktif")

_ae_model = None
_ae_scaler = None
_ae_threshold = 0.5


def _load_ae():
    global _ae_model, _ae_scaler, _ae_threshold
    if not _HAS_ML or _ae_model is not None:
        return
    try:
        base_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        _ae_scaler = joblib.load(os.path.join(base_path, 'ml_models', 'ae_scaler.pkl'))
        with open(os.path.join(base_path, 'ml_models', 'ae_threshold.txt'), 'r') as f:
            _ae_threshold = float(f.read().strip())
        _ae_model = LSTMAutoencoder(input_size=9, hidden_size=16)
        state_dict = torch.load(os.path.join(base_path, 'ml_models', 'lstm_ae.pt'), map_location=torch.device('cpu'))
        _ae_model.load_state_dict(state_dict)
        _ae_model.eval()
        logger.info("✅ LSTM-AE modeli belleğe yüklendi")
    except Exception as e:
        logger.warning(f"⚠️  LSTM-AE model dosyaları yüklenemedi: {e}")


@dataclass
class DailySnapshot:
    date: str = ""
    steps: float = 0.0
    sleep_hours: float = 0.0
    heart_rate: float = 0.0
    systolic: float = 0.0
    diastolic: float = 0.0
    spo2: float = 0.0
    weight: float = 0.0


@dataclass
class AnomalyItem:
    metric: str
    metric_label: str
    z_score: float
    today_value: float
    avg_value: float
    unit: str
    severity: str
    description: str
    recommendation: str


@dataclass
class AnomalyResult:
    has_anomaly: bool
    anomalies: list[AnomalyItem] = field(default_factory=list)
    checked_metrics: int = 0
    model_version: str = "zscore-v1"


_THRESHOLDS = {"high": 2.5, "medium": 1.5}

_METRIC_META = {
    "steps": ("Günlük Adım", "adım"),
    "sleep_hours": ("Uyku Süresi", "saat"),
    "heart_rate": ("Nabız", "bpm"),
    "systolic": ("Sistolik Tansiyon", "mmHg"),
    "diastolic": ("Diastolik Tansiyon", "mmHg"),
    "spo2": ("SpO₂", "%"),
    "weight": ("Kilo", "kg"),
}


def _mean(values: list[float]) -> float:
    return sum(values) / len(values) if values else 0.0


def _std(values: list[float], mean: float) -> float:
    if len(values) < 2:
        return 0.0
    variance = sum((v - mean) ** 2 for v in values) / len(values)
    return math.sqrt(variance)


def _severity(z: float) -> str:
    if z >= _THRESHOLDS["high"]:
        return "high"
    if z >= _THRESHOLDS["medium"]:
        return "medium"
    return "low"


def _describe(metric: str, z: float, today: float, avg: float, label: str, unit: str) -> tuple[str, str]:
    direction = "yüksek" if today > avg else "düşük"
    diff = abs(today - avg)

    descriptions = {
        "steps": (
            f"Bugün {int(today)} adım attınız, 7 günlük ortalamanız {int(avg)}. "
            f"Normal seviyenizin {direction} tarafındasınız.",
            "Kısa yürüyüşler yaparak adım sayınızı artırın." if today < avg
            else "Aktif kaldınız, bu tempoya devam edin!"
        ),
        "sleep_hours": (
            f"Bu gece {today:.1f} saat uyudunuz, ortalamanız {avg:.1f} saat. "
            f"Normalden {diff:.1f} saat {direction}.",
            "Düzenli uyku saatleri belirleyin ve yatak odasını karanlık tutun." if today < avg
            else "Fazla uyku yorgunluk belirtisi olabilir."
        ),
        "heart_rate": (
            f"Ortalama nabzınız {today:.0f} bpm, 7 günlük ortalamanız {avg:.0f} bpm.",
            "Stres veya kafein alımını gözden geçirin." if today > avg
            else "Nabzınız düşük seyretmiş, iyi dinlenmişsinizdir."
        ),
        "systolic": (
            f"Sistolik tansiyonunuz {today:.0f} mmHg, ortalamanız {avg:.0f} mmHg.",
            "Tuz alımını azaltın ve doktora danışın." if today > avg
            else "Düşük sinyali; bol sıvı tüketin."
        ),
        "diastolic": (
            f"Diastolik tansiyonunuz {today:.0f} mmHg, ortalamanız {avg:.0f} mmHg.",
            "Dinlenin ve gerekirse doktora başvurun." if today > avg
            else "Sıvı alımınıza dikkat edin."
        ),
        "spo2": (
            f"Oksijen saturasyonunuz %{today:.0f}, ortalamanız %{avg:.0f}.",
            "SpO₂ düşük. Derin nefes egzersizleri yapın veya doktora danışın."
        ),
        "weight": (
            f"Kilonuz {today:.1f} kg, ortalamanız {avg:.1f} kg. {diff:.1f} kg fark var.",
            "Kilo dalgalanmaları normal olabilir; büyük farklar beslenmeyi gözden geçirin."
        ),
    }

    desc, rec = descriptions.get(metric, (f"{label} değerinizde sapma var.", "Değerlerinizi takip edin."))
    if isinstance(rec, tuple):
        rec = rec[0]
    return desc, rec


def _check_ae_anomaly(today: DailySnapshot) -> tuple[bool, float]:
    """LSTM-AE ile anomali kontrolü. ML yoksa (False, 0) döner."""
    if not _HAS_ML:
        return False, 0.0
    try:
        _load_ae()
        if _ae_model is None:
            return False, 0.0

        hr_mean = today.heart_rate if today.heart_rate else 75
        features = np.array([[
            hr_mean, hr_mean, hr_mean - 10, hr_mean + 30, 10.0,
            today.steps if today.steps else 500,
            max(1, int(today.steps / 100)) if today.steps else 5,
            50, 0.05
        ]])
        features_scaled = _ae_scaler.transform(features)
        x_t = torch.tensor(features_scaled, dtype=torch.float32).unsqueeze(1)
        with torch.no_grad():
            reconstructed = _ae_model(x_t)
            mse = torch.mean((reconstructed - x_t) ** 2).item()
        return bool(mse > _ae_threshold), mse
    except Exception as e:
        logger.warning(f"LSTM-AE hatası: {e}")
        return False, 0.0


def detect_anomalies(history: list[DailySnapshot], today: DailySnapshot) -> AnomalyResult:
    """Ana fonksiyon — LSTM-AE + Z-skor veya sadece Z-skor."""

    has_anomaly_ml, mse = _check_ae_anomaly(today)

    # Z-Skor tabanlı kontrol (her zaman çalışır)
    anomalies: list[AnomalyItem] = []

    if len(history) >= 3:
        metrics = ["steps", "sleep_hours", "heart_rate", "systolic", "diastolic", "spo2", "weight"]

        for metric in metrics:
            historical_vals = [getattr(s, metric) for s in history if getattr(s, metric) > 0]
            today_val = getattr(today, metric)

            if len(historical_vals) < 3 or today_val <= 0:
                continue

            avg = _mean(historical_vals)
            std = _std(historical_vals, avg)

            if std < 0.001:
                continue

            z = abs(today_val - avg) / std
            label, unit = _METRIC_META.get(metric, (metric, ""))

            if z >= _THRESHOLDS["medium"]:
                desc, rec = _describe(metric, z, today_val, avg, label, unit)
                anomalies.append(AnomalyItem(
                    metric=metric, metric_label=label,
                    z_score=round(z, 2), today_value=round(today_val, 1),
                    avg_value=round(avg, 1), unit=unit,
                    severity=_severity(z), description=desc, recommendation=rec,
                ))

        anomalies.sort(key=lambda a: a.z_score, reverse=True)

    # ML anomali bulmuş ama kurallar bulamadıysa
    if has_anomaly_ml and len(anomalies) == 0:
        anomalies.append(AnomalyItem(
            metric="general_health", metric_label="Genel Sağlık Örüntüsü",
            z_score=2.0, today_value=0, avg_value=0, unit="",
            severity="medium",
            description=f"AI modelimiz günlük verilerinizde bir düzensizlik fark etti. (Hata: {mse:.2f})",
            recommendation="Gün içinde kendinizi nasıl hissettiğinizi dinleyin.",
        ))

    model_ver = f"lstm-ae-v1 (mse:{mse:.2f})" if _HAS_ML and mse > 0 else "zscore-v1"

    return AnomalyResult(
        has_anomaly=has_anomaly_ml or len(anomalies) > 0,
        anomalies=anomalies[:5],
        checked_metrics=7,
        model_version=model_ver,
    )
