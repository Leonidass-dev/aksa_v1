import pandas as pd
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import TensorDataset, DataLoader
from sklearn.model_selection import GroupShuffleSplit
from sklearn.preprocessing import StandardScaler
import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from ml_models.gru_model import RiskGRU


def create_sequences(df, seq_len=5):
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
    X, y, groups = [], [], []

    for subj, group in df.groupby("subject_id"):
        group = group.sort_values("window_idx")
        vals = group[feature_cols].values
        labels = group["risk_label"].values

        for i in range(len(vals) - seq_len + 1):
            X.append(vals[i : i + seq_len])
            y.append(labels[i + seq_len - 1])  # Target is the label of the last window
            groups.append(subj)

    return np.array(X), np.array(y), np.array(groups)


def train_risk_gru():
    print("PyTorch GRU Modeli Eğitimi Başlıyor (Modül 3)...")

    # 1. Veri Yükleme
    df = pd.read_csv("ml_training/data/wesad_processed.csv")

    # 2. Sequence Oluşturma (seq_len=5)
    seq_len = 5
    X_seq, y_seq, groups = create_sequences(df, seq_len=seq_len)

    print(f"Oluşturulan toplam dizi (sequence) sayısı: {len(X_seq)}")

    # 3. Train-Test Split (Kullanıcı Bazlı - GroupShuffleSplit)
    gss = GroupShuffleSplit(n_splits=1, test_size=0.2, random_state=42)
    train_idx, test_idx = next(gss.split(X_seq, y_seq, groups))

    X_train, X_test = X_seq[train_idx], X_seq[test_idx]
    y_train, y_test = y_seq[train_idx], y_seq[test_idx]

    # 4. Normalizasyon (Ölçekleme 3D tensor -> 2D -> 3D)
    scaler = StandardScaler()

    # Train normalizasyon
    batch_train, seq, feats = X_train.shape
    X_train_flat = X_train.reshape(-1, feats)
    X_train_scaled_flat = scaler.fit_transform(X_train_flat)
    X_train_scaled = X_train_scaled_flat.reshape(batch_train, seq, feats)

    # Test normalizasyon
    batch_test = X_test.shape[0]
    X_test_flat = X_test.reshape(-1, feats)
    X_test_scaled_flat = scaler.transform(X_test_flat)
    X_test_scaled = X_test_scaled_flat.reshape(batch_test, seq, feats)

    # 5. PyTorch Tensorlerine Çevirme
    X_train_t = torch.tensor(X_train_scaled, dtype=torch.float32)
    y_train_t = torch.tensor(y_train, dtype=torch.long)
    X_test_t = torch.tensor(X_test_scaled, dtype=torch.float32)
    y_test_t = torch.tensor(y_test, dtype=torch.long)

    train_data = TensorDataset(X_train_t, y_train_t)
    train_loader = DataLoader(train_data, batch_size=32, shuffle=True)

    # 6. Model Tanımlama
    input_size = feats
    model = RiskGRU(
        input_size=input_size, hidden_size=32, num_layers=1, num_classes=3, dropout=0.2
    )

    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=0.005)

    # 7. Eğitim Döngüsü
    epochs = 15
    for epoch in range(epochs):
        model.train()
        running_loss = 0.0
        for inputs, labels in train_loader:
            optimizer.zero_grad()
            outputs = model(inputs)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()
            running_loss += loss.item() * inputs.size(0)

        epoch_loss = running_loss / len(train_loader.dataset)

        # Doğrulama
        model.eval()
        with torch.no_grad():
            outputs = model(X_test_t)
            _, preds = torch.max(outputs, 1)
            acc = (preds == y_test_t).float().mean()

        print(
            f"Epoch {epoch + 1}/{epochs} - Loss: {epoch_loss:.4f} - Val Accuracy: {acc:.4f}"
        )

    # 8. Modeli Kaydetme
    os.makedirs("ml_models", exist_ok=True)
    torch.save(model.state_dict(), "ml_models/risk_gru.pt")
    print("PyTorch Modeli kaydedildi: ml_models/risk_gru.pt")


if __name__ == "__main__":
    train_risk_gru()
