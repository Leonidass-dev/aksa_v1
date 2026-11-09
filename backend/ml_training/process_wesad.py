import os
import sys
import pandas as pd
import numpy as np

WESAD_DIR = os.getenv("WESAD_DIR", os.path.join(os.path.dirname(__file__), "data", "WESAD"))
OUTPUT_FILE = os.path.join(os.path.dirname(__file__), "data", "wesad_processed.csv")

SEQ_LEN = 5  # GRU/LSTM-AE için ardışık pencere dizisi uzunluğu
WINDOW_SEC = 60  # 60 saniye pencere
STEP_SEC = 10  # 10 saniye kayma

if not os.path.exists(WESAD_DIR):
    print(f"Uyarı: WESAD veri seti dizini bulunamadı: {WESAD_DIR}")
    print("Veri setini 'backend/ml_training/data/WESAD' altına yerleştirebilir veya WESAD_DIR ortam değişkeni ile belirtebilirsiniz.")
    sys.exit(0)

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
    hr_start_ts = hr_df.iloc[0, 0]
    hr_fs = hr_df.iloc[1, 0]
    hr_values = hr_df.iloc[2:, 0].values

    # 32Hz ACC data (x, y, z)
    acc_df = pd.read_csv(acc_path, header=None)
    acc_start_ts = acc_df.iloc[0, 0]
    acc_fs = acc_df.iloc[1, 0]
    acc_values = acc_df.iloc[2:, :].values

    # Süre kısıtı (saniye cinsinden ortak süre)
    duration_sec = min(len(hr_values) / hr_fs, len(acc_values) / acc_fs)

    # 60 sn pencere, 10 sn kayma
    for start in range(0, int(duration_sec - WINDOW_SEC), STEP_SEC):
        end = start + WINDOW_SEC

        # HR dilimi (1Hz olduğu için doğrudan index aralığı)
        hr_window = hr_values[int(start * hr_fs):int(end * hr_fs)]
        # ACC dilimi (32Hz)
        acc_window = acc_values[int(start * acc_fs):int(end * acc_fs)]

        if len(hr_window) == 0 or len(acc_window) == 0:
            continue

        # Öznitelik Mühendisliği
        hr_mean = float(np.mean(hr_window))
        hr_min = float(np.min(hr_window))
        hr_max = float(np.max(hr_window))
        hr_std = float(np.std(hr_window))

        # ACC Magnitude hesapla: sqrt(x^2 + y^2 + z^2)
        acc_mag = np.sqrt(np.sum(acc_window**2, axis=1))
        acc_mean = float(np.mean(acc_mag))
        acc_std = float(np.std(acc_mag))

        # Adım kestirimi (peak counting veya ACC standart sapmasından orantılı)
        estimated_steps = int(acc_std * 15)

        # Aktif kalori kestirimi
        estimated_calories = float((hr_mean * 0.05) + (acc_mean * 0.02))

        feature_rows.append({
            "subject": subj,
            "window_start": start,
            "hr_mean": hr_mean,
            "hr_min": hr_min,
            "hr_max": hr_max,
            "hr_std": hr_std,
            "acc_mean": acc_mean,
            "acc_std": acc_std,
            "steps": estimated_steps,
            "calories": estimated_calories
        })

print(f"Toplam çıkarılan pencere sayısı: {len(feature_rows)}")
if feature_rows:
    df_out = pd.DataFrame(feature_rows)
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    df_out.to_csv(OUTPUT_FILE, index=False)
    print(f"İşlenmiş veri seti başarıyla kaydedildi -> {OUTPUT_FILE}")
