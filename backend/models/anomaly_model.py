"""
M7 — Anomali Tespiti (Z-Skor Tabanlı)
Tezdeki LSTM-AE modelinin kural & istatistik tabanlı ön versiyonu.
Kullanıcının 7 günlük ortalamasından standart sapma hesaplanır.
|z| > 2.0 → anomali
"""

from dataclasses import dataclass, field
import math


@dataclass
class DailySnapshot:
    """Tek bir günün sağlık verisi."""
    date: str          # YYYY-MM-DD
    steps: float = 0.0
    sleep_hours: float = 0.0
    heart_rate: float = 0.0
    systolic: float = 0.0
    diastolic: float = 0.0
    spo2: float = 0.0
    weight: float = 0.0


@dataclass
class AnomalyItem:
    metric: str          # "steps", "sleep_hours", ...
    metric_label: str    # Türkçe
    z_score: float       # mutlak değer
    today_value: float
    avg_value: float
    unit: str
    severity: str        # "low" | "medium" | "high"
    description: str
    recommendation: str


@dataclass
class AnomalyResult:
    has_anomaly: bool
    anomalies: list[AnomalyItem] = field(default_factory=list)
    checked_metrics: int = 0
    model_version: str = "zscore-v1"


# Eşikler: |z| > high → yüksek risk, |z| > medium → orta
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
            else "Fazla uyku yorgunluk belirtisi olabilir, aktivite düzeynizi kontrol edin."
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
            "Kilo dalgalanmaları normal olabilir; ancak büyük farklar beslenmeyi gözden geçirmenizi gerektirir."
        ),
    }

    desc, rec = descriptions.get(metric, (f"{label} değerinizde sapma var.", "Değerlerinizi takip etmeye devam edin."))
    if isinstance(rec, tuple):
        rec = rec[0]
    return desc, rec


def detect_anomalies(history: list[DailySnapshot], today: DailySnapshot) -> AnomalyResult:
    """
    history: son 7 günün verileri (bugün dahil değil)
    today:   bugünün verisi
    """
    if len(history) < 3:
        # Yeterli veri yok
        return AnomalyResult(has_anomaly=False, checked_metrics=0)

    anomalies: list[AnomalyItem] = []
    metrics = ["steps", "sleep_hours", "heart_rate", "systolic", "diastolic", "spo2", "weight"]

    for metric in metrics:
        historical_vals = [getattr(s, metric) for s in history if getattr(s, metric) > 0]
        today_val = getattr(today, metric)

        if len(historical_vals) < 3 or today_val <= 0:
            continue

        avg = _mean(historical_vals)
        std = _std(historical_vals, avg)

        if std < 0.001:
            continue  # Sıfır varyans → sağlıklı tutarlılık

        z = abs(today_val - avg) / std
        label, unit = _METRIC_META.get(metric, (metric, ""))

        if z >= _THRESHOLDS["medium"]:
            desc, rec = _describe(metric, z, today_val, avg, label, unit)
            anomalies.append(AnomalyItem(
                metric=metric,
                metric_label=label,
                z_score=round(z, 2),
                today_value=round(today_val, 1),
                avg_value=round(avg, 1),
                unit=unit,
                severity=_severity(z),
                description=desc,
                recommendation=rec,
            ))

    anomalies.sort(key=lambda a: a.z_score, reverse=True)

    return AnomalyResult(
        has_anomaly=len(anomalies) > 0,
        anomalies=anomalies[:5],   # en fazla 5 uyarı
        checked_metrics=len(metrics),
    )
