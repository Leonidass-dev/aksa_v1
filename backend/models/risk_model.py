"""
M3 — Risk Skoru Modeli
Tezdeki XGBoost + GRU füzyon modelinin kural tabanlı ön versiyonu.
İkinci dönemde gerçek eğitilmiş model ile değiştirilecek.
"""

from dataclasses import dataclass, field


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
    Kural tabanlı risk skoru hesaplama.
    Her faktör 0-25 puan arasında risk katkısı sağlar.
    Toplam 0-100 arası skor üretilir.
    """
    score = 0.0
    factors: list[RiskFactor] = []

    # ── Adım sayısı (hedef: 10000, < 5000 kötü) ─────────────────
    if snap.steps > 0:
        step_contrib = _normalize(10000 - snap.steps, 0, 10000) * 20
        score += step_contrib
        factors.append(RiskFactor(
            name="Günlük Adım",
            contribution=round(step_contrib - 10, 1),
            description=f"{int(snap.steps)} adım — hedef 10.000"
        ))

    # ── Uyku süresi (hedef: 7-9 saat) ────────────────────────────
    if snap.sleep_hours > 0:
        if snap.sleep_hours < 6:
            sleep_contrib = _normalize(6 - snap.sleep_hours, 0, 6) * 18
        elif snap.sleep_hours > 9:
            sleep_contrib = _normalize(snap.sleep_hours - 9, 0, 3) * 10
        else:
            sleep_contrib = 0.0
        score += sleep_contrib
        factors.append(RiskFactor(
            name="Uyku Süresi",
            contribution=round(sleep_contrib - 5, 1),
            description=f"{snap.sleep_hours:.1f} saat — ideal 7-9 saat"
        ))

    # ── Dinlenik nabız (60-80 ideal, >100 kötü) ──────────────────
    if snap.heart_rate_resting > 0:
        hr_contrib = _normalize(snap.heart_rate_resting, 60, 110) * 20
        score += hr_contrib
        factors.append(RiskFactor(
            name="Dinlenik Nabız",
            contribution=round(hr_contrib - 10, 1),
            description=f"{int(snap.heart_rate_resting)} bpm"
        ))

    # ── Tansiyon (120/80 ideal) ───────────────────────────────────
    if snap.systolic > 0:
        bp_contrib = _normalize(snap.systolic, 110, 160) * 15
        bp_contrib += _normalize(snap.diastolic, 70, 100) * 5
        score += bp_contrib
        factors.append(RiskFactor(
            name="Tansiyon",
            contribution=round(bp_contrib - 10, 1),
            description=f"{int(snap.systolic)}/{int(snap.diastolic)} mmHg"
        ))

    # ── SpO2 (>95 normal, <90 kritik) ────────────────────────────
    if snap.spo2 > 0:
        spo2_contrib = _normalize(100 - snap.spo2, 0, 10) * 15
        score += spo2_contrib
        factors.append(RiskFactor(
            name="Oksijen Saturasyonu",
            contribution=round(spo2_contrib - 5, 1),
            description=f"%{snap.spo2:.0f} SpO₂"
        ))

    # ── Stres ─────────────────────────────────────────────────────
    if snap.stress_level > 0:
        stress_contrib = _normalize(snap.stress_level, 0, 100) * 12
        score += stress_contrib
        factors.append(RiskFactor(
            name="Stres Seviyesi",
            contribution=round(stress_contrib - 6, 1),
            description=f"{int(snap.stress_level)}/100"
        ))

    # Faktörleri katkıya göre sırala
    factors.sort(key=lambda f: abs(f.contribution), reverse=True)

    score = round(min(score, 100.0), 1)

    # Seviye belirle (tezdeki eşikler: 0-33 düşük, 34-66 orta, 67-100 yüksek)
    if score < 34:
        level = "low"
    elif score < 67:
        level = "medium"
    else:
        level = "high"

    # Öneriler
    recommendations = _generate_recommendations(factors, level)

    return RiskResult(
        score=score,
        level=level,
        top_factors=factors[:5],
        recommendations=recommendations,
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
