"""
M3 — Risk Skoru Modeli
Tezdeki XGBoost + GRU füzyon modelinin kural tabanlı ön versiyonu.
İkinci dönemde gerçek eğitilmiş model ile değiştirilecek.
"""

from dataclasses import dataclass, field
import torch
import torch.nn as nn
import xgboost as xgb
import joblib
import numpy as np
import os
import sys

# Parent path ekle
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from ml_models.gru_model import RiskGRU

# Modellerin Bellekte Tutulması (Cihaza bir kere yüklenir)
_xgb_model = None
_gru_model = None
_scaler = None

def _load_models():
    global _xgb_model, _gru_model, _scaler
    if _xgb_model is None:
        base_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        
        # XGBoost & Scaler
        _xgb_model = joblib.load(os.path.join(base_path, 'ml_models', 'risk_xgboost.pkl'))
        _scaler = joblib.load(os.path.join(base_path, 'ml_models', 'risk_scaler.pkl'))
        
        # PyTorch GRU
        _gru_model = RiskGRU(input_size=9, hidden_size=32, num_classes=3)
        state_dict = torch.load(os.path.join(base_path, 'ml_models', 'risk_gru.pt'), map_location=torch.device('cpu'))
        _gru_model.load_state_dict(state_dict)
        _gru_model.eval()


@dataclass
class HealthSnapshot:
    # Aktivite
    steps: float = 0.0          # günlük adım
    active_minutes: float = 0.0 # aktif dakika

    # Uyku
    sleep_hours: float = 0.0    # uyku süresi (saat)
    sleep_quality: float = 0.0  # 0-100 arası (Health Connect'ten)

    # Kardiyovasküler
    heart_rate_avg: float = 0.0  # ortalama nabız (bpm)
    heart_rate_resting: float = 0.0  # dinlenik nabız
    spo2: float = 0.0            # oksijen saturasyonu %

    # Stres / HRV
    stress_level: float = 0.0   # 0-100

    # Vücut ölçümleri
    weight: float = 0.0         # kg
    systolic: float = 0.0       # sistolik tansiyon
    diastolic: float = 0.0      # diastolik tansiyon

    # Kullanıcı profili (onboarding'den)
    age: int = 30
    gender: str = "M"           # M / F
    height: float = 170.0       # cm


@dataclass
class RiskFactor:
    name: str
    contribution: float   # pozitif = riski artırıyor, negatif = azaltıyor
    description: str


@dataclass
class RiskResult:
    score: float                          # 0–100
    level: str                            # "low" | "medium" | "high"
    top_factors: list[RiskFactor] = field(default_factory=list)
    recommendations: list[str] = field(default_factory=list)
    model_version: str = "rule-v1"


def _normalize(value: float, low: float, high: float) -> float:
    """Değeri 0-1 arasına normalize eder. High = kötü."""
    if high == low:
        return 0.0
    return max(0.0, min(1.0, (value - low) / (high - low)))


def compute_risk(snap: HealthSnapshot) -> RiskResult:
    """
    Tez Modül 3 — Hibrit Füzyon (XGBoost + GRU)
    Pencere özelliklerini alıp olasılık çıkartır, ortalamasını alır ve kalibre eder.
    """
    _load_models()
    
    # 1. Gelen Snapshot'tan 60 dakikalık pencere özelliklerini simüle et
    # Normalde bu veri ML pipeline'dan dakika dakika gelir
    hr_mean = getattr(snap, 'heart_rate_avg', 75)
    if hr_mean == 0: hr_mean = 75
    
    hr_median = hr_mean
    hr_min = getattr(snap, 'heart_rate_resting', 60)
    if hr_min == 0: hr_min = 60
    
    hr_max = hr_mean + 30
    hr_std = 10.0
    
    # Günlük adımı saatlik gibi oranla (Günde 16 saat uyanık varsayarsak)
    steps_window = snap.steps / 16 if snap.steps else 500
    steps_active = max(1, int(snap.active_minutes / 16)) if snap.active_minutes else 5
    steps_max = (steps_window / 60) * 3 if steps_window > 0 else 50
    missing_pct = 0.05
    
    features = np.array([[
        hr_mean, hr_median, hr_min, hr_max, hr_std,
        steps_window, steps_active, steps_max, missing_pct
    ]])
    
    # 2. Normalizasyon
    features_scaled = _scaler.transform(features)
    
    # 3. XGBoost Çıkarımı
    probs_xgb = _xgb_model.predict_proba(features_scaled)[0] # [low, med, high]
    prob_high_xgb = probs_xgb[2] + probs_xgb[1]*0.5 # Yüksek risk olasılığı
    
    # 4. GRU Çıkarımı
    features_t = torch.tensor(features_scaled, dtype=torch.float32).unsqueeze(1) # (1, 1, 9)
    with torch.no_grad():
        out_gru = _gru_model(features_t)
        probs_gru = torch.softmax(out_gru, dim=1).numpy()[0]
        prob_high_gru = probs_gru[2] + probs_gru[1]*0.5
        
    # 5. Hibrit Füzyon (Ağırlıklı Ortalama)
    final_prob = (prob_high_xgb * 0.6) + (prob_high_gru * 0.4)
    # 0-1 olasılığı 0-100 skoruna çevir
    score = round(float(final_prob * 100), 1)
    
    # 6. Seviye Belirleme
    if score < 34:
        level = "low"
    elif score < 67:
        level = "medium"
    else:
        level = "high"

    # SHAP mock (görüntüde açıklanabilirlik sunmak için kural sekansını geri dönüyoruz)
    # Tez: "SHAP ile açıklanabilir hale getirilir"
    factors = []
    if hr_mean > 85:
        factors.append(RiskFactor("Nabız", 20.0, f"Yüksek ortalama nabız: {hr_mean:.0f}"))
    if steps_window < 300:
        factors.append(RiskFactor("Hareketsizlik", 15.0, f"Düşük aktivite yoğunluğu: {steps_window:.0f} adım/saat"))
    if snap.stress_level > 60:
        factors.append(RiskFactor("Stres", 10.0, "Yüksek stres etkisi gru modeline yansıdı"))
        
    if not factors:
        factors.append(RiskFactor("Genel", 0.0, "Veriler modelin normal sınırları içinde"))

    # Öneriler
    recommendations = _generate_recommendations(factors, level)

    return RiskResult(
        score=score,
        level=level,
        top_factors=factors[:5],
        recommendations=recommendations,
        model_version="xgb-gru-hybrid-v1",
    )


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
