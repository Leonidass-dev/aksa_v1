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

_HAS_SHAP = False
try:
    import shap
    _HAS_SHAP = True
    logger.info("✅ SHAP kütüphanesi hazır (Açıklanabilir XAI aktif)")
except ImportError:
    logger.warning("⚠️  SHAP kütüphanesi yok. pip install shap kurarak aktif edebilirsiniz.")

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


from typing import Any
def _get_shap_contributions(x_t: Any) -> list[tuple[str, float]]:
    """SHAP GradientExplainer kullanarak Anomaliye yol açan özellikleri ağırlıklandırır."""
    if not _HAS_SHAP or not _HAS_ML or _ae_model is None:
        return []

    try:
        class MSEWrapper(torch.nn.Module):
            def __init__(self, ae):
                super().__init__()
                self.ae = ae
            def forward(self, x):
                recon = self.ae(x)
                # Batch başına ortalama MSE
                return torch.mean((recon - x)**2, dim=2) 
        
        wrapper = MSEWrapper(_ae_model).eval()
        
        # Referans arkaplan verisi (modeli şaşırtmayacak 0 etrafında ölçeklenmiş boş bir tensör)
        bg_data = torch.zeros((5, 1, 9), dtype=torch.float32)
        explainer = shap.GradientExplainer(wrapper, bg_data)
        
        shap_values = explainer.shap_values(x_t)
        
        if isinstance(shap_values, list):
            sv = shap_values[0]
        else:
            sv = shap_values
            
        sv_abs = np.abs(sv.reshape(-1))
        total = np.sum(sv_abs) + 1e-9
        sv_pct = (sv_abs / total) * 100
        
        feature_names = [
            "Ortalama Nabız", "Medyan Nabız", "Min Nabız", "Maks Nabız", "Nabız Std",
            "Günlük Adım", "Aktif Süre", "Maks Adım Yoğunluğu", "Eksik Veri Oranı"
        ]
        
        importance = list(zip(feature_names, sv_pct))
        importance.sort(key=lambda x: x[1], reverse=True)
        return importance[:3]  # En çok etki eden 3 özelliği dön
    except Exception as e:
        logger.warning(f"SHAP explainer hesaplanırken hata: {e}")
        return []

def _check_ae_anomaly(today: DailySnapshot, ml_features: list[float] | None = None) -> tuple[bool, float, list[tuple[str, float]]]:
    """LSTM-AE ile anomali kontrolü. ML veya M2 verisi yoksa (False, 0, []) döner."""
    if not _HAS_ML:
        return False, 0.0, []
    try:
        _load_ae()
        if _ae_model is None:
            return False, 0.0, []

        if ml_features is None or len(ml_features) != 9:
            # UYARI: Günlük verilerden (örn: 10.000 adım) 1 saatlik model penceresi (max 5000) 
            # için sentetik veri üretmek modeli patlatıyor (MSE > 50).
            # M2 verisi yoksa anomali üretme, Z-Skor fallback'e bırak.
            logger.info("⚠️ M7 Anomali Modeli: M2 verisi bulunamadı. LSTM-AE atlanıyor, Z-skor kullanılacak.")
            return False, 0.0, []

        # M2 Pipeline'dan çoktan temizlenmiş gerçek özellikler aktı!
        features = np.array([ml_features])
        logger.info("🎯 M7 Anomali Modeli: M2(Data Pipeline)'den gelen 100% temiz veri listesi LSTM-AE ağına besleniyor!")
        
        features_scaled = _ae_scaler.transform(features)
        x_t = torch.tensor(features_scaled, dtype=torch.float32).unsqueeze(1)
        with torch.no_grad():
            reconstructed = _ae_model(x_t)
            mse = torch.mean((reconstructed - x_t) ** 2).item()
        is_anomaly = bool(mse > _ae_threshold)
        shap_factors = []
        if is_anomaly:
            shap_factors = _get_shap_contributions(x_t)
            
        return is_anomaly, mse, shap_factors
    except Exception as e:
        logger.warning(f"LSTM-AE hatası: {e}")
        return False, 0.0, []


def detect_anomalies(history: list[DailySnapshot], today: DailySnapshot, ml_features: list[float] | None = None) -> AnomalyResult:
    """Ana fonksiyon — LSTM-AE + Z-skor veya sadece Z-skor."""

    has_anomaly_ml, mse, shap_factors = _check_ae_anomaly(today, ml_features=ml_features)

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

    # ML anomali bulmuş ama kurallar bulamadıysa veya SHAP açıklaması varsa onu ana anomali olarak ekle
    if has_anomaly_ml:
        # Tez M7: K=3 Süreklilik Kuralı (Ardışık günlerde devam ediyor mu?)
        consecutive_anomalies = 1
        if len(history) >= 2:
            for past_day in history[-2:]:
                past_has_anomaly, _, _ = _check_ae_anomaly(past_day)
                if past_has_anomaly:
                    consecutive_anomalies += 1
                    
        severity = "medium"
        if consecutive_anomalies >= 3:
            severity = "high" # 3 gündür devam ediyorsa yüksek risk
            shap_desc = f"LSTM-AE modeli {consecutive_anomalies} gündür ardışık anomali tespit ediyor (Süreklilik İhlali). Hata Oranı: {mse:.2f}."
        else:
            shap_desc = f"LSTM-AE modeli geçici bir sapma tespit etti. Hata Oranı: {mse:.2f}."

        if shap_factors:
            factors_text = ", ".join([f"%{f[1]:.0f} {f[0]}" for f in shap_factors])
            shap_desc += f" En çok etkileyen faktörler: {factors_text}"
            
        anomalies.insert(0, AnomalyItem(
            metric="lstm_ae_fusion", metric_label="Yapay Zeka Anomali Tespiti",
            z_score=round(mse * 10, 2), today_value=0, avg_value=0, unit="",
            severity=severity,
            description=shap_desc,
            recommendation="Farklı seyreden vücut verileriniz yorgunluk belirtisi olabilir. Bugün vücudunuzu dinlemeye özen gösterin.",
        ))

    model_ver = f"lstm-ae-v1 (mse:{mse:.2f})" if _HAS_ML and mse > 0 else "zscore-v1"

    return AnomalyResult(
        has_anomaly=has_anomaly_ml or len(anomalies) > 0,
        anomalies=anomalies[:5],
        checked_metrics=7,
        model_version=model_ver,
    )
