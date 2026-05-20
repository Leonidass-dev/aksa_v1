import pandas as pd
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import TensorDataset, DataLoader
from sklearn.preprocessing import StandardScaler
import joblib
import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from ml_models.lstm_ae_model import LSTMAutoencoder


def create_ae_sequences(df, seq_len=5):
    feature_cols = [
        "hr_mean",
        "hr_median",
        "hr_min",
        "hr_max",
        "hr_std",
        "steps_sum",
        "steps_active_mins",
        "steps_max",
        "missing_pct",
    ]
    X, groups = [], []

    for subj, group in df.groupby("subject_id"):
        group = group.sort_values("window_idx")
        vals = group[feature_cols].values
        anomalies = group["anomaly_label"].values

        for i in range(len(vals) - seq_len + 1):
            seq_anomalies = anomalies[i : i + seq_len]
            # Sadece "Normal" pencerelerden oluşan dizileri al
            if np.sum(seq_anomalies) == 0:
                X.append(vals[i : i + seq_len])
                groups.append(subj)

    return np.array(X), np.array(groups)


def train_anomaly_ae():
    print("PyTorch LSTM-AE Modeli Eğitimi Başlıyor (Modül 7)...")

    # 1. Veri Yükleme
    df = pd.read_csv("ml_training/data/wesad_processed.csv")

    # 2. Sequence Oluşturma (sadece normal verilerden, seq_len=5)
    seq_len = 5
    X_seq, groups = create_ae_sequences(df, seq_len=seq_len)

    print(f"Oluşturulan toplam 'Normal' dizi (sequence) sayısı: {len(X_seq)}")

    # Eğitim için tüm normal verileri kullanacağız, ancak threshold hesabı için
    # train test split yapılabilir. AE genelde hepsiyle eğitilip yine hepsiyle threshold belirlenir.
    # Yine de subject tabanlı validation daha dürüsttür.

    # 3. Normalizasyon
    scaler = StandardScaler()
    batch, seq, feats = X_seq.shape
    X_flat = X_seq.reshape(-1, feats)
    X_scaled_flat = scaler.fit_transform(X_flat)
    X_scaled = X_scaled_flat.reshape(batch, seq, feats)

    X_t = torch.tensor(X_scaled, dtype=torch.float32)

    train_data = TensorDataset(X_t, X_t)  # Hedef kendisi
    train_loader = DataLoader(train_data, batch_size=32, shuffle=True)

    # 4. Model Tanımlama
    input_size = feats
    model = LSTMAutoencoder(input_size=input_size, hidden_size=16)

    criterion = nn.MSELoss()
    optimizer = optim.Adam(model.parameters(), lr=0.01)

    # 5. Eğitim
    epochs = 15
    for epoch in range(epochs):
        model.train()
        running_loss = 0.0
        for inputs, targets in train_loader:
            optimizer.zero_grad()
            outputs = model(inputs)
            loss = criterion(outputs, targets)
            loss.backward()
            optimizer.step()
            running_loss += loss.item() * inputs.size(0)

        epoch_loss = running_loss / len(train_loader.dataset)
        print(f"Epoch {epoch + 1}/{epochs} - Train MSE Loss: {epoch_loss:.4f}")

    # 6. Eşik Değerinin Hesaplanması (Threshold)
    model.eval()
    with torch.no_grad():
        reconstructed = model(X_t)
        mses = torch.mean((reconstructed - X_t) ** 2, dim=[1, 2]).numpy()

    # Normal verinin %95'ini kapsayacak threshold
    threshold = np.percentile(mses, 95)
    print(f"Hesaplanan Anomali Eşiği (Threshold): {threshold:.4f}")

    # 7. Kaydetme
    os.makedirs("ml_models", exist_ok=True)
    torch.save(model.state_dict(), "ml_models/lstm_ae.pt")
    joblib.dump(scaler, "ml_models/ae_scaler.pkl")

    with open("ml_models/ae_threshold.txt", "w") as f:
        f.write(str(threshold))

    print(
        "Modül 7 dosyaları (Model, Scaler, Threshold) ml_models/ klasörüne kaydedildi."
    )


if __name__ == "__main__":
    train_anomaly_ae()
