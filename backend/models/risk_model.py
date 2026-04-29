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
    import shap
    sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from ml_models.gru_model import RiskGRU
    _HAS_ML = True
    logger.info("✅ Risk modeli: XGBoost + GRU (ve SHAP) yüklendi")
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


def _compute_risk_ml(snap: HealthSnapshot, ml_features: list[float] | None = None) -> RiskResult:
    """Hibrit Füzyon: XGBoost + GRU"""
    _load_models()

    if ml_features is not None and len(ml_features) == 9:
        # M2 Pipeline'dan gelen temizlenmiş gerçek özellikler!
        features = np.array([ml_features])
        logger.info("🎯 M3 Risk Modeli: M2(Data Pipeline) temiz verileri XGBoost+GRU'ya besleniyor!")
        hr_mean = ml_features[0]  # Faktör analizi için
        steps_window = ml_features[5]
    else:
        # M2 henüz hazır değilse WESAD sağlıklı dinlenme baseline'ı kullanılır (Düşük Risk)
        hr_mean = snap.heart_rate_avg if snap.heart_rate_avg else 72.0
        hr_min = snap.heart_rate_resting if snap.heart_rate_resting else 60.0
        hr_max = hr_mean + 15.0
        hr_std = 5.0  # Düzenli, sağlıklı kalp değişkenliği
        steps_window = snap.steps / 16 if snap.steps else 200.0
        steps_active = max(1, int(snap.active_minutes / 16)) if snap.active_minutes else 2
        steps_max = 20.0
        missing_pct = 0.0

        features = np.array([[
            hr_mean, hr_mean, hr_min, hr_max, hr_std,
            steps_window, steps_active, steps_max, missing_pct
        ]])
        logger.info("⚠️ M3 Risk Modeli: M2 verisi bulunamadı, fallback özellikler kullanılıyor.")

    features_scaled = _scaler.transform(features)

    probs_xgb = _xgb_model.predict_proba(features_scaled)[0]
    # WESAD Class 2 (Stres/Yüksek Sapma) tam risk (1.0). Class 1 (Günlük Aktivite) düşük risk (0.2).
    prob_high_xgb = probs_xgb[2] * 1.0 + probs_xgb[1] * 0.2

    features_t = torch.tensor(features_scaled, dtype=torch.float32).unsqueeze(1)
    with torch.no_grad():
        out_gru = _gru_model(features_t)
        probs_gru = torch.softmax(out_gru, dim=1).numpy()[0]
        prob_high_gru = probs_gru[2] * 1.0 + probs_gru[1] * 0.2

    # XGBoost ve GRU tahminlerinin ağırlıklı ortalaması
    final_prob = (prob_high_xgb * 0.6) + (prob_high_gru * 0.4)
    # Temel kardiyovasküler baz risk eklenir (Min %5)
    score = max(5.0, round(float(final_prob * 100), 1))

    # Tez: 0–33 düşük, 34–66 orta, 67–100 yüksek
    if score <= 33:
        level = "low"
    elif score <= 66:
        level = "medium"
    else:
        level = "high"

    # Tez M3: SHAP (Açıklanabilir Yapay Zeka - XAI) Entagrasyonu
    factors = []
    try:
        explainer = shap.TreeExplainer(_xgb_model)
        shap_values = explainer.shap_values(features_scaled)
        
        # XGBoost multi-class ise shap_values liste döner. En riskli sınıfın (High Risk) değerlerini alalım.
        sv = shap_values[2] if isinstance(shap_values, list) else shap_values[0]
        
        feature_names = [
            "Ortalama Nabız", "Medyan Nabız", "Min Nabız", "Maks Nabız", "Nabız Std",
            "Günlük Adım", "Aktif Süre", "Maks Adım Yoğunluğu", "Eksik Veri Oranı"
        ]
        
        # Mutlak değerlerle önem oranlarını (%) bul
        sv_abs = np.abs(sv)
        total_sv = np.sum(sv_abs) + 1e-9
        
        for i, val in enumerate(sv):
            pct = (abs(val) / total_sv) * 100
            if pct > 5.0: # Sadece %5'ten fazla etkisi olanları ekle
                direction = "Artırıcı" if val > 0 else "Düşürücü"
                desc = f"Algoritmik SHAP Etkisi ({direction})"
                factors.append(RiskFactor(feature_names[i], round(float(pct), 1), desc))
                
        factors.sort(key=lambda x: x.contribution, reverse=True)
    except Exception as e:
        logger.warning(f"SHAP explainer hesaplanırken hata: {e}. Fallback kurallarına dönülüyor.")
        if hr_mean > 95:
            hr_contribution = min(20.0, (hr_mean - 95) * 2.0 + 5.0)
            factors.append(RiskFactor("Nabız", hr_contribution, f"Yüksek ortalama nabız: {hr_mean:.0f}"))
        if steps_window < 300:
            factors.append(RiskFactor("Hareketsizlik", 15.0, f"Düşük aktivite: {steps_window:.0f} adım/saat"))
            
    if not factors:
        factors.append(RiskFactor("Genel", 0.0, "Veriler normal sınırlar içinde veya risk dağılımı dengeli"))

    return RiskResult(
        score=score, level=level,
        top_factors=factors[:5],
        recommendations=_generate_recommendations(factors, level),
        model_version="xgb-gru-hybrid-v1",
    )


def _compute_risk_rules(snap: HealthSnapshot) -> RiskResult:
    """
    Tez M3: Uzman Sistem (Expert System) Fallback.
    AHA (American Heart Association) ve tıbbi literatür tabanlı kural motoru.
    """
    score = 5.0  # Başlangıç: Minimum baz risk
    factors = []
    
    # 1. BMI (Vücut Kitle Endeksi) Hesaplama (Kilo / Boy^2)
    if snap.weight > 0 and snap.height > 100:
        height_m = snap.height / 100.0
        bmi = snap.weight / (height_m * height_m)
        
        # Yaşlılar için esnetilmiş WESAD/AHA eşiği
        threshold = 27.0 if snap.age > 65 else 25.0
        
        if bmi > threshold:
            bmi_penalty = min(20, (bmi - threshold) * 1.5)
            score += bmi_penalty
            label = "Obezite" if bmi >= (threshold + 5.0) else "Fazla Kilo"
            factors.append(RiskFactor("BMI (VKE)", bmi_penalty, f"{label}: {bmi:.1f}"))

    # 2. Yaş Faktörü (Kardiyovasküler yaşlanma)
    if snap.age > 45:
        age_penalty = (snap.age - 45) * 0.4
        score += age_penalty
        factors.append(RiskFactor("Yaş", age_penalty, f"Yaşa bağlı risk artışı ({snap.age})"))

    # 3. Adım ve Aktivite (Sedanter Yaşam)
    # Tez M3: Zaman duyarlı risk analizi (Sabah saatlerinde düşük adım normaldir)
    import datetime
    current_hour = datetime.datetime.now().hour
    
    if snap.steps > 0:
        # Saat bazlı beklenen adım: sabah düşük, akşam yüksek
        # Saat 8'de 1000, öğlen 12'de 4000, akşam 20'de 8000 beklenir
        expected_steps = min(10000, max(1000, (current_hour - 6) * 600)) if current_hour > 6 else 500
        if snap.steps < expected_steps:
            step_risk = _normalize(expected_steps - snap.steps, 0, expected_steps) * 12
            score += step_risk
            if step_risk > 5:
                factors.append(RiskFactor("Hareketsizlik", step_risk, f"Günlük {int(snap.steps)} adım — beklenen ~{int(expected_steps)}"))
    # Eğer snap.steps == 0 ise, veri çekilememiştir (Eksik veri), buna ceza Puanı VERMİYORUZ.

    # 4. Uyku Hijyeni
    if snap.sleep_hours > 0:
        if snap.sleep_hours < 6:
            sleep_risk = _normalize(6 - snap.sleep_hours, 0, 6) * 15
            score += sleep_risk
            factors.append(RiskFactor("Yetersiz Uyku", sleep_risk, f"{snap.sleep_hours:.1f} saat — dinlenme yetersiz"))
        elif snap.sleep_hours > 9:
            score += 5
            factors.append(RiskFactor("Aşırı Uyku", 5.0, f"{snap.sleep_hours:.1f} saat — metabolik yavaşlama"))

    # 5. Kalp Hızı (Dinlenik Nabız) — AHA: 60-100 Normal
    if snap.heart_rate_resting > 100:
        hr_risk = _normalize(snap.heart_rate_resting, 100, 150) * 15
        score += hr_risk
        factors.append(RiskFactor("Taşikardi Riski", hr_risk, f"Yüksek dinlenik nabız: {snap.heart_rate_resting:.0f} bpm"))

    # 6. Kan Basıncı (Tansiyon) — AHA Standartları
    if snap.systolic > 0 or snap.diastolic > 0:
        sys = snap.systolic
        dia = snap.diastolic
        bp_score = 0
        bp_label = ""
        
        if sys >= 180 or dia >= 120:
            bp_score = 30
            bp_label = "Hipertansif Kriz"
        elif sys >= 140 or dia >= 90:
            bp_score = 20
            bp_label = "Evre 2 Hipertansiyon"
        elif sys >= 130 or dia >= 85:
            bp_score = 12
            bp_label = "Evre 1 Hipertansiyon"
        elif sys > 125 and dia >= 80:
            bp_score = 5
            bp_label = "Yükseliş Eğilimi"
        # 120/80 ve altı = Normal, ceza yok
        
        if bp_score > 0:
            score += bp_score
            factors.append(RiskFactor("Hipertansiyon", bp_score, f"{bp_label}: {sys:.0f}/{dia:.0f} mmHg"))

    # 7. Oksijen Saturasyonu (SpO2)
    if snap.spo2 > 0:
        if snap.spo2 < 95:
            spo2_risk = _normalize(95 - snap.spo2, 0, 10) * 25
            score += spo2_risk
            factors.append(RiskFactor("Hipoksi İşareti", spo2_risk, f"Düşük SpO₂: %{snap.spo2:.0f}"))

    # 8. Stres (HRV Bazlı)
    if snap.stress_level > 65:
        stress_risk = _normalize(snap.stress_level, 65, 100) * 10
        score += stress_risk
        factors.append(RiskFactor("Otonom Stres", stress_risk, f"Yüksek stres: {snap.stress_level:.0f}/100"))

    # 9. SINERJİ (Birden fazla yüksek riskin çarpan etkisi)
    # Tez M3: Kritik vakaların birleşimi daha dengeli hesaplanmalı
    high_risks = len([f for f in factors if f.contribution >= 18])
    if high_risks >= 2:
        synergy_bonus = score * 0.05  # %5 sinerjik bonus (eskisi %10 idi)
        score += synergy_bonus
        factors.append(RiskFactor("Sinerjik Risk", synergy_bonus, f"{high_risks} farklı kritik faktör çakışması"))

    score = max(0, min(100, score))

    # Tez: 0–33 düşük, 34–66 orta, 67–100 yüksek
    if score <= 33:
        level = "low"
    elif score <= 66:
        level = "medium"
    else:
        level = "high"

    if not factors:
        factors.append(RiskFactor("Genel", 0.0, "Tüm vital bulgular normal sınırda"))

    factors.sort(key=lambda f: f.contribution, reverse=True)

    return RiskResult(
        score=round(score, 1), level=level,
        top_factors=factors[:5],
        recommendations=_generate_recommendations(factors, level),
        model_version="expert-v1.2",
    )


def _clean_data(snap: HealthSnapshot) -> HealthSnapshot:
    """
    Tez M2: Canlı Veri Ön İşleme (Preprocessing).
    Gelen verileri analiz öncesi temizler, aykırı değerleri (outliers) kırpar.
    """
    # 1. Kalp Hızı Temizleme [40, 220]
    if snap.heart_rate_avg > 0:
        snap.heart_rate_avg = max(40.0, min(220.0, snap.heart_rate_avg))
    if snap.heart_rate_resting > 0:
        snap.heart_rate_resting = max(35.0, min(150.0, snap.heart_rate_resting))
        
    # 2. SpO2 Temizleme [%70, %100]
    if snap.spo2 > 0:
        snap.spo2 = max(70.0, min(100.0, snap.spo2))
        
    # 3. Adım Sayısı (Günde 50k adımı geçen veri muhtemelen hatalıdır)
    if snap.steps > 0:
        snap.steps = min(50000.0, snap.steps)
        
    # 4. Kilo ve Boy Mantık Kontrolü
    if snap.weight > 0:
        snap.weight = max(30.0, min(250.0, snap.weight))
        
    # 5. Tansiyon Kırpma
    if snap.systolic > 0:
        snap.systolic = max(70.0, min(220.0, snap.systolic))
    if snap.diastolic > 0:
        snap.diastolic = max(40.0, min(130.0, snap.diastolic))
        
    return snap


def compute_risk(snap: HealthSnapshot, ml_features: list[float] | None = None) -> RiskResult:
    """Ana fonksiyon — Önce veriyi temizler (M2), sonra analiz eder (M3)."""
    # M2: Preprocessing adımı
    clean_snap = _clean_data(snap)
    
    if _HAS_ML:
        try:
            return _compute_risk_ml(clean_snap, ml_features=ml_features)
        except Exception as e:
            logger.warning(f"ML çıkarım hatası, fallback'e geçiliyor: {e}")
    return _compute_risk_rules(clean_snap)


def _generate_recommendations(factors: list[RiskFactor], level: str) -> list[str]:
    recs = []
    # Kritikliğe göre öneriler
    for f in factors:
        if f.contribution < 5:
            continue
            
        if "Hipertansiyon" in f.name:
            recs.append("Tansiyonunuz yüksek seyrediyor. Tuz kullanımını azaltın ve doktorunuza danışın.")
        if "Hipoksi" in f.name:
            recs.append("Oksijen seviyeniz düşük. Eğer semptomunuz varsa (nefes darlığı) acil yardım isteyin.")
        if "BMI" in f.name:
            recs.append("Dengeli beslenme ve düzenli kalori kontrolü ile kilonuzu ideal sınıra çekmeye çalışın.")
        if "Taşikardi" in f.name:
            recs.append("Dinlenik nabzınız yüksek. Kahve tüketimini azaltın ve stres yönetimi yapın.")
        if "Adım" in f.name or "Hareketsizlik" in f.name:
            recs.append("Günde en az 30 dakika orta tempolu yürüyüş yapmayı alışkanlık edinin.")
        if "Uyku" in f.name:
            recs.append("Uyku kalitesini artırmak için yatmadan 2 saat önce ekran kullanımını bırakın.")
            
    if not recs:
        recs.append("Tüm göstergeler harika! Mevcut yaşam tarzınızı korumaya devam edin.")
        
    return list(dict.fromkeys(recs))[:4] # Duplicate'leri temizle
