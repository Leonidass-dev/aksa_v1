import os
import pandas as pd
import numpy as np

WESAD_DIR = r"C:\Users\Leonidas\Desktop\dataset\WESAD"
OUTPUT_FILE = "ml_training/data/wesad_processed.csv"

SEQ_LEN = 5  # GRU/LSTM-AE için ardışık pencere dizisi uzunluğu
WINDOW_SEC = 60  # 60 saniye pencere
STEP_SEC = 10  # 10 saniye kayma

feature_rows = []

print("WESAD Klasörü Taranıyor...")
for subj in os.listdir(WESAD_DIR):
    subj_dir = os.path.join(WESAD_DIR, subj, f"{subj}_E4_Data")
    if not os.path.isdir(subj_dir):
        continue

    hr_path = os.path.join(subj_dir, "HR.csv")
    acc_path = os.path.join(subj_dir, "ACC.csv")

    if not os.path.exists(hr_path) or not os.path.exists(acc_path):
        continue

    print(f"{subj} E4 sensör (HR/ACC) verileri işleniyor...")

    # 1Hz HR data
    hr_df = pd.read_csv(hr_path, header=None)
    # The first row is start timestamp, second is freq. Actual data starts at index 2
    hr_values = hr_df.iloc[2:][0].values.astype(float)

    # 32Hz ACC data
    acc_df = pd.read_csv(acc_path, header=None)
    acc_values = acc_df.iloc[2:].values.astype(float)
    # Convert XYZ to magnitude (vector norm) subtracted by gravity (~64 for E4)
    acc_mag = np.linalg.norm(acc_values, axis=1) - 64.0
    acc_mag = np.abs(acc_mag)

    window_idx = 0  # Denek içi pencere sıra numarası

    for i in range(0, len(hr_values) - WINDOW_SEC, STEP_SEC):
        hr_window = hr_values[i : i + WINDOW_SEC]
        # ACC is 32Hz, so indices are * 32
        acc_window = acc_mag[i * 32 : (i + WINDOW_SEC) * 32]

        hr_mean = np.mean(hr_window)
        hr_min = np.min(hr_window)
        hr_max = np.max(hr_window)
        hr_std = np.std(hr_window)

        # NOT: WESAD veri seti adım verisi İÇERMEZ.
        # İvmeölçer büyüklüğünden fiziksel hareket tahmini yapılıyor.
        # Bu değerler gerçek adım sayısı değil, "hareket yoğunluğu" proxy metrikleridir.
        # Production'da Health Connect'ten gelen gerçek adım verileri kullanılır.
        active_samples = np.sum(acc_window > 15)  # E4 ivmeölçer ölçeğinde hareket eşiği
        activity_intensity = active_samples / 10.0  # Hareket yoğunluğu proxy değeri
        active_mins = (active_samples / 32) / 60

        activity_sum = activity_intensity
        activity_active = max(0.0, float(active_mins))
        activity_max = np.max(acc_window) if len(acc_window) > 0 else 0
        missing_pct = np.sum(hr_window == 0) / len(hr_window)

        # ── Etiketleme: Uzman kural tabanlı (Expert System Labeling) ──
        # NOT: Bu etiketler ideal değildir (model kuralları ezberler).
        # İyileştirme: WESAD'ın kendi stres etiketleri kullanılabilir (pickle dosyaları).
        # Mevcut yaklaşım tez kapsamında kabul edilebilir bir baseline'dır.
        score = 0
        if hr_mean > 100:
            score += 40
        elif hr_mean > 85:
            score += 20
        elif hr_mean < 50:
            score += 30

        if activity_sum < 100:
            score += 20

        if hr_std > 20:
            score += 15
        elif hr_std < 2:
            score += 10

        if score > 50:
            label = 2
        elif score > 20:
            label = 1
        else:
            label = 0

        # Anomaly label
        anomaly = 1 if (hr_max > 150 or hr_min < 45 or missing_pct > 0.3) else 0

        feature_rows.append(
            {
                "subject_id": subj,  # Kullanıcı bazlı split için
                "window_idx": window_idx,  # Sequence oluşturmak için sıra numarası
                "hr_mean": hr_mean,
                "hr_median": np.median(hr_window),
                "hr_min": hr_min,
                "hr_max": hr_max,
                "hr_std": hr_std,
                "steps_sum": activity_sum,  # Geriye uyumluluk için alan adı korundu
                "steps_active_mins": activity_active,
                "steps_max": activity_max,
                "missing_pct": missing_pct,
                "risk_prob": min(0.99, score / 100.0),
                "risk_label": label,
                "anomaly_label": anomaly,
            }
        )
        window_idx += 1

os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
df = pd.DataFrame(feature_rows)
df.to_csv(OUTPUT_FILE, index=False)
print(f"Toplam {len(df)} pencere işlendi ve {OUTPUT_FILE} konumuna kaydedildi.")
print(f"Denek sayısı: {df['subject_id'].nunique()}")
print(df["risk_label"].value_counts())
