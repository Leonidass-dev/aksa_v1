"""
M3 — Risk Skoru Modeli
Hibrit: XGBoost + GRU varsa kullanır, yoksa kural tabanlı fallback.
"""

import datetime
from dataclasses import dataclass, field, replace
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
_models_loaded = False


def _load_models():
    global _xgb_model, _gru_model, _scaler, _models_loaded
    if not _HAS_ML or _models_loaded:
        return
    _models_loaded = True  # Tekrar denemeyi önle (başarısız yükleme döngüsü)
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
    # Beslenme Entegrasyonu (Tez Modül 5)
    consumed_calories: float = 0.0
    nutrition_score: float = 70.0  # Ortalama sağlıklı beslenme skoru


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

    # ── Guard Clause: Model veya Scaler yüklenemezse fallback ──
    if _xgb_model is None or _scaler is None:
        logger.warning("⚠️ XGBoost veya Scaler yüklenemedi, kural tabanlı fallback'e geçiliyor.")
        return _compute_risk_rules(snap)

    # ── M2 Pipeline verisini işle ──
    is_sequence = ml_features and len(ml_features) > 0 and isinstance(ml_features[0], list)
    
    if is_sequence:
        # Gerçek zaman dizisi geldi! (M2 Düzeltme)
        raw_sequence = ml_features
        latest_vector = np.array([raw_sequence[-1]])
        hr_mean = raw_sequence[-1][0]
        steps_window = raw_sequence[-1][5]
        logger.info(f"🎯 M3 Risk Modeli: {len(raw_sequence)} pencerelik GERÇEK zaman serisi işleniyor.")
    elif ml_features and len(ml_features) == 9:
        # Eski 1D format veya tekil veri
        latest_vector = np.array([ml_features])
        hr_mean = ml_features[0]
        steps_window = ml_features[5]
        raw_sequence = [ml_features]
    else:
        # Fallback (WESAD dinlenme baseline)
        hr_mean = snap.heart_rate_avg if snap.heart_rate_avg else 72.0
        hr_min = snap.heart_rate_resting if snap.heart_rate_resting else 60.0
        hr_max = hr_mean + 15.0
        hr_std = 5.0
        steps_window = snap.steps / 16 if snap.steps else 200.0
        steps_active = max(1, int(snap.active_minutes / 16)) if snap.active_minutes else 2
        steps_max = 20.0
        missing_pct = 0.0

        latest_vector = np.array([[
            hr_mean, hr_mean, hr_min, hr_max, hr_std,
            steps_window, steps_active, steps_max, missing_pct
        ]])
        raw_sequence = latest_vector.tolist()
        logger.info("⚠️ M3 Risk Modeli: M2 verisi bulunamadı, fallback kullanılıyor.")

    features_scaled = _scaler.transform(latest_vector)

    # ── XGBoost Tahmini ──
    probs_xgb = _xgb_model.predict_proba(features_scaled)[0]
    prob_high_xgb = probs_xgb[2] * 1.0 + probs_xgb[1] * 0.2

    # ── GRU Tahmini (seq_len=5 desteği) ──
    prob_high_gru = 0.0
    if _gru_model is not None:
        # Tüm diziyi ölçekle
        seq_scaled = _scaler.transform(raw_sequence)
        
        # Eğer dizi 5'ten kısaysa başını son elemanla pad et (sıcak başlangıç)
        if len(seq_scaled) < 5:
            padding = np.tile(seq_scaled[0], (5 - len(seq_scaled), 1))
            seq_final = np.vstack([padding, seq_scaled])
        else:
            seq_final = seq_scaled[-5:]
            
        features_t = torch.tensor(seq_final, dtype=torch.float32).unsqueeze(0)  # (1, 5, 9)
        with torch.no_grad():
            out_gru = _gru_model(features_t)
            probs_gru = torch.softmax(out_gru, dim=1).numpy()[0]
            prob_high_gru = probs_gru[2] * 1.0 + probs_gru[1] * 0.2

    # XGBoost ve GRU tahminlerinin ağırlıklı ortalaması
    final_prob = (prob_high_xgb * 0.6) + (prob_high_gru * 0.4)

    # Tez M3: Platt-benzeri sigmoid smoothing (kalibrasyon)
    # Ham olasılığı sigmoid ile yumuşat — aşırı uç değerleri merkeze çek
    final_prob = 1.0 / (1.0 + np.exp(-5.0 * (final_prob - 0.5)))

    # Temel kardiyovasküler baz risk eklenir (Min %5)
    score = max(5.0, round(float(final_prob * 100), 1))

    # Tez: 0–33 düşük, 34–66 orta, 67–100 yüksek
    if score <= 33:
        level = "low"
    elif score <= 66:
        level = "medium"
    else:
        level = "high"

    # Tez M3: SHAP (Açıklanabilir Yapay Zeka - XAI) Entegrasyonu
    factors = []
    try:
        explainer = shap.TreeExplainer(_xgb_model)
        shap_values = explainer.shap_values(features_scaled)
        
        # SHAP değerlerini al
        # XGBoost multi-class çıktısı sürüme göre liste veya 3D array dönebilir
        sv = None
        if isinstance(shap_values, list):
            # Liste ise her eleman bir sınıfa aittir. High Risk (index 2) al.
            sv = shap_values[2] if len(shap_values) > 2 else shap_values[-1]
        elif isinstance(shap_values, np.ndarray):
            if shap_values.ndim == 3:
                # (samples, features, classes) -> (1, 9, 3)
                sv = shap_values[0, :, 2]
            elif shap_values.ndim == 2:
                # (samples, features)
                sv = shap_values[0]
            else:
                sv = shap_values

        # sv'nin sayısal olduğundan ve tek boyutlu (features,) olduğundan emin ol
        if sv is not None:
            sv = np.array(sv, dtype=float).flatten()
            if sv.ndim > 1: sv = sv[0]
        
        feature_names = [
            "Ortalama Nabız", "Medyan Nabız", "Min Nabız", "Maks Nabız", "Nabız Std",
            "Günlük Adım", "Aktif Süre", "Maks Adım Yoğunluğu", "Eksik Veri Oranı"
        ]
        
        # Mutlak değerlerle önem oranlarını (%) bul
        sv_abs = np.abs(sv).flatten()
        total_sv = np.sum(sv_abs) + 1e-9
        sv_flat = np.array(sv).flatten()
        
        for i, val in enumerate(sv_flat):
            if i >= len(feature_names):
                break
            pct = (abs(val) / total_sv) * 100
            if pct > 5.0:  # Sadece %5'ten fazla etkisi olanları ekle
                direction = "Artış" if val > 0 else "Azalış"
                desc = f"Sağlık verilerinizdeki {direction} yönlü değişim"
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
        model_version="v1.2",
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
    current_hour = datetime.datetime.now().hour
    
    # Saat bazlı beklenen adım: sabah düşük, akşam yüksek
    # Saat 8'de 1000, öğlen 12'de 4000, akşam 20'de 8000 beklenir
    expected_steps = min(10000, max(1000, (current_hour - 6) * 600)) if current_hour > 6 else 500
    
    if snap.steps < expected_steps:
        step_diff = expected_steps - snap.steps
        step_risk = _normalize(step_diff, 0, expected_steps) * 12
        score += step_risk
        if step_risk > 3:
            factors.append(RiskFactor("Hareketsizlik", step_risk, f"Günlük {int(snap.steps)} adım — beklenen ~{int(expected_steps)}"))
    # Eğer snap.steps == 0 ise, veri hiç gelmemiş olabilir ama akşam saatlerinde bu ciddi bir hareketsizlik göstergesidir.

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
    
    # 9. Beslenme Mantığı (Tez M5 Entegrasyonu)
    if snap.weight > 0 and snap.height > 100:
        # Bazal Metabolizma (Mifflin-St Jeor)
        if snap.gender == 'M':
            bmr = 10 * snap.weight + 6.25 * snap.height - 5 * snap.age + 5
        else:
            bmr = 10 * snap.weight + 6.25 * snap.height - 5 * snap.age - 161
            
        # Dinamik Limit: BMR + Hareket (Dakika başına ~4 kalori varsayımı veya direkt steps/20)
        daily_limit = bmr + (snap.steps / 20.0) 
        
        if snap.consumed_calories > (daily_limit + 300):
            surplus = snap.consumed_calories - daily_limit
            nutrition_penalty = min(15, (surplus / 100) * 2)
            score += nutrition_penalty
            factors.append(RiskFactor("Kalori Aşımı", nutrition_penalty, f"Limitin {int(surplus)} kalori üzerinde tüketim"))
        
        if snap.nutrition_score < 50:
            quality_penalty = (50 - snap.nutrition_score) * 0.2
            score += quality_penalty
            factors.append(RiskFactor("Düşük Besin Kalitesi", quality_penalty, "İşlenmiş veya düşük skorlu gıda tüketimi"))

    # 10. SINERJİ (Birden fazla yüksek riskin çarpan etkisi)
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
        model_version="v1.2",
    )


def _clean_data(snap: HealthSnapshot) -> HealthSnapshot:
    """
    Tez M2: Canlı Veri Ön İşleme (Preprocessing).
    Gelen verileri analiz öncesi temizler, aykırı değerleri (outliers) kırpar.
    Orijinal dataclass'ı değiştirmez — temiz bir kopya döndürür.
    """
    updates = {}
    
    # 1. Kalp Hızı Temizleme [40, 220]
    if snap.heart_rate_avg > 0:
        updates['heart_rate_avg'] = max(40.0, min(220.0, snap.heart_rate_avg))
    if snap.heart_rate_resting > 0:
        updates['heart_rate_resting'] = max(35.0, min(150.0, snap.heart_rate_resting))
        
    # 2. SpO2 Temizleme [%70, %100]
    if snap.spo2 > 0:
        updates['spo2'] = max(70.0, min(100.0, snap.spo2))
        
    # 3. Adım Sayısı (Günde 50k adımı geçen veri muhtemelen hatalıdır)
    if snap.steps > 0:
        updates['steps'] = min(50000.0, snap.steps)
        
    # 4. Kilo ve Boy Mantık Kontrolü
    if snap.weight > 0:
        updates['weight'] = max(30.0, min(250.0, snap.weight))
        
    # 5. Tansiyon Kırpma
    if snap.systolic > 0:
        updates['systolic'] = max(70.0, min(220.0, snap.systolic))
    if snap.diastolic > 0:
        updates['diastolic'] = max(40.0, min(130.0, snap.diastolic))
        
    return replace(snap, **updates)


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
        
    return list(dict.fromkeys(recs))[:4]  # Duplicate'leri temizle
