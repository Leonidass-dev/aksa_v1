import os
import sys
import numpy as np
sys.path.append(os.path.abspath('backend'))
from models.risk_model import HealthSnapshot, compute_risk, _load_models

# Yükle
_load_models()

test_cases = [
    {
        'name': 'Çok Sağlıklı', 
        'snap': HealthSnapshot(steps=12000, active_minutes=60, heart_rate_avg=65, heart_rate_resting=55, weight=70, height=175),
        'ml_features': [[65.0, 65.0, 55.0, 110.0, 5.0, 12000.0, 60.0, 100.0, 0.0]]
    },
    {
        'name': 'Sedanter (Hareketsiz)', 
        'snap': HealthSnapshot(steps=1500, active_minutes=5, heart_rate_avg=75, heart_rate_resting=70, weight=90, height=175),
        'ml_features': [[75.0, 75.0, 70.0, 100.0, 2.0, 1500.0, 5.0, 20.0, 0.0]]
    },
    {
        'name': 'Taşikardi / Yüksek Risk', 
        'snap': HealthSnapshot(steps=3000, active_minutes=10, heart_rate_avg=110, heart_rate_resting=95, weight=85, height=170),
        'ml_features': [[110.0, 110.0, 95.0, 160.0, 15.0, 3000.0, 10.0, 50.0, 0.0]]
    }
]

for case in test_cases:
    result = compute_risk(case['snap'], ml_features=case['ml_features'])
    print(f"{case['name']}:")
    print(f"  Risk Skoru: {result.score} / Seviye: {result.level}")
    print(f"  En Çok Etkileyen 2 Faktör:")
    for f in result.top_factors[:2]:
        print(f"    - {f.name}: {f.contribution}%")
    print('-'*30)
