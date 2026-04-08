"""
M3 — Risk Skoru Modeli
Hibrit: XGBoost + GRU varsa kullanır, yoksa kural tabanlı fallback.
"""

from dataclasses import dataclass, field
import numpy as np
import os
import sys
import logging

logger = logging.getLogger(__name__)

# ── ML Import (Opsiyonel) ──────────────────────────────────────────
_HAS_ML = False
try:
    import torch
    import torch.nn as nn
    import xgboost as xgb
    import joblib
    sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from ml_models.gru_model import RiskGRU
    _HAS_ML = True
    logger.info("✅ Risk modeli: XGBoost + GRU yüklendi")
except ImportError as e:
    logger.warning(f"⚠️  ML kütüphaneleri yüklenemedi ({e}) — Kural tabanlı fallback aktif")

# Model cache
_xgb_model = None
_gru_model = None
_scaler = None


def _load_models():
    global _xgb_model, _gru_model, _scaler
    if not _HAS_ML or _xgb_model is not None:
        return
    try:
        base_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        _xgb_model = joblib.load(os.path.join(base_path, 'ml_models', 'risk_xgboost.pkl'))
        _scaler = joblib.load(os.path.join(base_path, 'ml_models', 'risk_scaler.pkl'))
        _gru_model = RiskGRU(input_size=9, hidden_size=32, num_classes=3)
        state_dict = torch.load(os.path.join(base_path, 'ml_models', 'risk_gru.pt'), map_location=torch.device('cpu'))
        _gru_model.load_state_dict(state_dict)
        _gru_model.eval()
        logger.info("✅ Risk ML modelleri belleğe yüklendi")
    except Exception as e:
        logger.warning(f"⚠️  ML model dosyaları yüklenemedi: {e}")


@dataclass
class HealthSnapshot:
    steps: float = 0.0
    active_minutes: float = 0.0
    sleep_hours: float = 0.0
    sleep_quality: float = 0.0
    heart_rate_avg: float = 0.0
    heart_rate_resting: float = 0.0
    spo2: float = 0.0
    stress_level: float = 0.0
    weight: float = 0.0
    systolic: float = 0.0
    diastolic: float = 0.0
    age: int = 30
    gender: str = "M"
    height: float = 170.0


@dataclass
class RiskFactor:
    name: str
    contribution: float
    description: str


@dataclass
class RiskResult:
    score: float
    level: str
    top_factors: list[RiskFactor] = field(default_factory=list)
    recommendations: list[str] = field(default_factory=list)
    model_version: str = "rule-v1"


def _normalize(value: float, low: float, high: float) -> float:
    if high == low:
        return 0.0
    return max(0.0, min(1.0, (value - low) / (high - low)))


def _compute_risk_ml(snap: HealthSnapshot) -> RiskResult:
    """Hibrit Füzyon: XGBoost + GRU"""
    _load_models()

    hr_mean = snap.heart_rate_avg if snap.heart_rate_avg else 75
    hr_min = snap.heart_rate_resting if snap.heart_rate_resting else 60
    hr_max = hr_mean + 30
    hr_std = 10.0
    steps_window = snap.steps / 16 if snap.steps else 500
    steps_active = max(1, int(snap.active_minutes / 16)) if snap.active_minutes else 5
    steps_max = (steps_window / 60) * 3 if steps_window > 0 else 50
    missing_pct = 0.05

    features = np.array([[
        hr_mean, hr_mean, hr_min, hr_max, hr_std,
        steps_window, steps_active, steps_max, missing_pct
    ]])

    features_scaled = _scaler.transform(features)

    probs_xgb = _xgb_model.predict_proba(features_scaled)[0]
    prob_high_xgb = probs_xgb[2] + probs_xgb[1] * 0.5

    features_t = torch.tensor(features_scaled, dtype=torch.float32).unsqueeze(1)
    with torch.no_grad():
        out_gru = _gru_model(features_t)
        probs_gru = torch.softmax(out_gru, dim=1).numpy()[0]
        prob_high_gru = probs_gru[2] + probs_gru[1] * 0.5

    final_prob = (prob_high_xgb * 0.6) + (prob_high_gru * 0.4)
    score = round(float(final_prob * 100), 1)

    if score < 34:
        level = "low"
    elif score < 67:
        level = "medium"
    else:
        level = "high"

    factors = []
    if hr_mean > 85:
        factors.append(RiskFactor("Nabız", 20.0, f"Yüksek ortalama nabız: {hr_mean:.0f}"))
    if steps_window < 300:
        factors.append(RiskFactor("Hareketsizlik", 15.0, f"Düşük aktivite: {steps_window:.0f} adım/saat"))
    if snap.stress_level > 60:
        factors.append(RiskFactor("Stres", 10.0, "Yüksek stres"))
    if not factors:
        factors.append(RiskFactor("Genel", 0.0, "Veriler normal sınırlar içinde"))

    return RiskResult(
        score=score, level=level,
        top_factors=factors[:5],
        recommendations=_generate_recommendations(factors, level),
        model_version="xgb-gru-hybrid-v1",
    )


def _compute_risk_rules(snap: HealthSnapshot) -> RiskResult:
    """Kural tabanlı fallback — ML yokken çalışır."""
    score = 25.0  # Başlangıç: düşük risk
    factors = []

    # Adım kontrolü
    if snap.steps > 0:
        step_risk = _normalize(10000 - snap.steps, 0, 10000) * 15
        score += step_risk
        if step_risk > 8:
            factors.append(RiskFactor("Adım", step_risk, f"Günlük {int(snap.steps)} adım — hedef 10.000"))

    # Uyku kontrolü
    if snap.sleep_hours > 0:
        if snap.sleep_hours < 6:
            sleep_risk = _normalize(6 - snap.sleep_hours, 0, 6) * 15
            score += sleep_risk
            factors.append(RiskFactor("Uyku", sleep_risk, f"{snap.sleep_hours:.1f} saat — yetersiz uyku"))
        elif snap.sleep_hours > 9:
            score += 5
            factors.append(RiskFactor("Uyku", 5.0, f"{snap.sleep_hours:.1f} saat — fazla uyku"))

    # Nabız
    if snap.heart_rate_resting > 0:
        if snap.heart_rate_resting > 90:
            hr_risk = _normalize(snap.heart_rate_resting, 90, 120) * 12
            score += hr_risk
            factors.append(RiskFactor("Nabız", hr_risk, f"Dinlenik nabız: {snap.heart_rate_resting:.0f} bpm"))

    # Tansiyon
    if snap.systolic > 0:
        if snap.systolic > 130 or snap.diastolic > 85:
            bp_risk = _normalize(snap.systolic, 130, 180) * 15
            score += bp_risk
            factors.append(RiskFactor("Tansiyon", bp_risk, f"{snap.systolic:.0f}/{snap.diastolic:.0f} mmHg"))

    # SpO2
    if snap.spo2 > 0 and snap.spo2 < 95:
        spo2_risk = _normalize(95 - snap.spo2, 0, 10) * 10
        score += spo2_risk
        factors.append(RiskFactor("Oksijen", spo2_risk, f"SpO₂: %{snap.spo2:.0f}"))

    # Stres
    if snap.stress_level > 60:
        stress_risk = _normalize(snap.stress_level, 60, 100) * 8
        score += stress_risk
        factors.append(RiskFactor("Stres", stress_risk, f"Stres: {snap.stress_level:.0f}/100"))

    score = max(0, min(100, score))

    if score < 34:
        level = "low"
    elif score < 67:
        level = "medium"
    else:
        level = "high"

    if not factors:
        factors.append(RiskFactor("Genel", 0.0, "Tüm göstergeler normal"))

    factors.sort(key=lambda f: f.contribution, reverse=True)

    return RiskResult(
        score=round(score, 1), level=level,
        top_factors=factors[:5],
        recommendations=_generate_recommendations(factors, level),
        model_version="rule-v1",
    )


def compute_risk(snap: HealthSnapshot) -> RiskResult:
    """Ana fonksiyon — ML varsa kullan, yoksa kural tabanlı."""
    if _HAS_ML:
        try:
            return _compute_risk_ml(snap)
        except Exception as e:
            logger.warning(f"ML çıkarım hatası, fallback'e geçiliyor: {e}")
    return _compute_risk_rules(snap)


def _generate_recommendations(factors: list[RiskFactor], level: str) -> list[str]:
    recs = []
    for f in factors:
        if f.contribution <= 0:
            continue
        if "Adım" in f.name:
            recs.append("Günlük 10.000 adım hedefine ulaşmak için kısa yürüyüşler planlayın.")
        elif "Uyku" in f.name:
            recs.append("Her gece 7-8 saat uyumayı hedefleyin. Düzenli uyku saatleri belirleyin.")
        elif "Nabız" in f.name:
            recs.append("Nabız değerlerinizi izlemeye devam edin. Yüksekse doktora danışın.")
        elif "Tansiyon" in f.name:
            recs.append("Tuz tüketiminizi azaltın ve düzenli ölçüm yapın.")
        elif "Oksijen" in f.name:
            recs.append("SpO₂ değeriniz düşük. Derin nefes egzersizleri deneyin.")
        elif "Stres" in f.name:
            recs.append("Stres yönetimi için meditasyon veya nefes egzersizleri deneyin.")
    if not recs:
        recs.append("Tüm göstergeleriniz iyi durumda. Mevcut rutininizi sürdürün.")
    return recs[:4]
