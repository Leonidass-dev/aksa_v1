import pandas as pd
import numpy as np
import os
import argparse

def generate_synthetic_data(n_samples=5000):
    """
    Modül 3 ve Modül 7 eğitimleri için sentetik zaman serisi/pencere verisi üretir.
    WESAD ve MMASH veri setlerine benzer hipotetik 60 dakikalık pencere özellikleri.
    """
    np.random.seed(42)
    
    # Zaman serisi özellikleri
    data = {
        'hr_mean': np.random.normal(70, 10, n_samples),
        'hr_median': np.random.normal(69, 10, n_samples),
        'hr_min': np.random.normal(55, 5, n_samples),
        'hr_max': np.random.normal(110, 15, n_samples),
        'hr_std': np.random.normal(8, 3, n_samples),
        'steps_sum': np.random.exponential(500, n_samples),
        'steps_active_mins': np.random.randint(0, 30, n_samples),
        'steps_max': np.random.randint(20, 120, n_samples),
        'missing_pct': np.random.uniform(0, 0.2, n_samples)
    }
    
    df = pd.DataFrame(data)
    
    # Mantıksal düzeltmeler
    df['hr_max'] = df[['hr_max', 'hr_mean']].max(axis=1) + 5
    df['hr_min'] = df[['hr_min', 'hr_mean']].min(axis=1) - 5
    
    # Sentetik Risk Skoru formülü (Hedef değişken)
    # Yüksek kalp atışı, yüksek std, düşük adım -> Risk artar
    risk_score_continuous = (
        0.5 * ((df['hr_mean'] - 70) / 10) +
        0.3 * (df['hr_std'] / 8) -
        0.2 * (df['steps_sum'] / 500)
    )
    
    # Sigmoid benzeri olasılık değerine (0-1) çek
    risk_prob = 1 / (1 + np.exp(-risk_score_continuous))
    
    # Gürültü ekle
    risk_prob += np.random.normal(0, 0.05, n_samples)
    risk_prob = np.clip(risk_prob, 0, 1)
    
    # 3 Sınıflı Risk Etiketi: 0 (Düşük), 1 (Orta), 2 (Yüksek)
    df['risk_prob'] = risk_prob
    df['risk_label'] = np.where(risk_prob < 0.33, 0, np.where(risk_prob < 0.66, 1, 2))
    
    # Anomali Etiketi (Modül 7 için)
    # Risk 2 olanların %20'sine ve rastgele noktalara anomali ver
    df['anomaly_label'] = 0
    anomaly_idx = np.random.choice(df[df['risk_label'] == 2].index, size=int((df['risk_label'] == 2).sum() * 0.2), replace=False)
    df.loc[anomaly_idx, 'anomaly_label'] = 1
    
    return df

if __name__ == "__main__":
    os.makedirs('ml_training/data', exist_ok=True)
    df = generate_synthetic_data(10000)
    df.to_csv('ml_training/data/synthetic_health_windows.csv', index=False)
    print("Sentetik veri seti oluşturuldu: ml_training/data/synthetic_health_windows.csv")
    print(df['risk_label'].value_counts())
