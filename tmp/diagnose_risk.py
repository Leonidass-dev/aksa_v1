
import sys
import os

# Mevcut çalışma dizinini ve backend dizinini path'e ekle
sys.path.append(os.getcwd())
sys.path.append(os.path.join(os.getcwd(), 'backend'))

try:
    from models.risk_model import compute_risk, HealthSnapshot
except ImportError:
    from backend.models.risk_model import compute_risk, HealthSnapshot

def test_scenarios():
    scenarios = [
        {
            "name": "Süper Atlet (Genç)",
            "snap": HealthSnapshot(steps=15000, sleep_hours=8.5, heart_rate_resting=48, systolic=110, diastolic=70, spo2=99, stress_level=12, age=22, weight=68, height=180)
        },
        {
            "name": "Hafif Kilolu / Hareketsiz",
            "snap": HealthSnapshot(steps=2000, sleep_hours=6.5, heart_rate_resting=75, systolic=125, diastolic=82, spo2=97, stress_level=45, age=38, weight=92, height=175)
        },
        {
            "name": "Kritik Risk (Obez + Hipertansiyon)",
            "snap": HealthSnapshot(steps=500, sleep_hours=4.0, heart_rate_resting=105, systolic=175, diastolic=110, spo2=91, stress_level=88, age=62, weight=115, height=172)
        },
        {
            "name": "Sinerjik Risk (Tansiyon + Hipoksi)",
            "snap": HealthSnapshot(steps=3000, sleep_hours=5.0, heart_rate_resting=85, systolic=145, diastolic=95, spo2=92, stress_level=50, age=50, weight=80, height=175)
        },
        {
            "name": "İleri Yaş Sağlıklı",
            "snap": HealthSnapshot(steps=8000, sleep_hours=7.5, heart_rate_resting=65, systolic=135, diastolic=85, spo2=96, stress_level=30, age=75, weight=75, height=170)
        }
    ]

    print(f"{'Senaryo':<35} | {'Skor':<6} | {'Seviye':<12} | {'En Büyüt Risk Faktörü'}")
    print("-" * 105)
    for s in scenarios:
        res = compute_risk(s["snap"])
        top_f = res.top_factors[0].name if res.top_factors else "Yok"
        print(f"{s['name']:<35} | {res.score:<6} | {res.level:<12} | {top_f}")

if __name__ == "__main__":
    test_scenarios()
