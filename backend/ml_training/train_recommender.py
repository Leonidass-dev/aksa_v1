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
from ml_models.rnn_recommender import ExerciseRNN


def generate_recommender_data(n_users=500):
    """
    Kullanıcı bazlı 14 günlük geçmiș simülasyonu (Tez Modül 6 için).
    Daha gerçekçi davranışsal simülasyon.
    """
    np.random.seed(42)
    X_data = []
    Y_data = []

    for _ in range(n_users):
        # Profil belirleme (0: Sedanter/Riskli, 1: Ortalama, 2: Aktif/Fit)
        profile = np.random.choice([0, 1, 2], p=[0.3, 0.5, 0.2])

        steps, active, sleep, risk = [], [], [], []

        current_fatigue = 0.0

        for day in range(14):
            # Uyku saatleri (profil bazlı)
            base_sleep = np.random.normal(
                6.5 if profile == 0 else (7.0 if profile == 1 else 7.5), 1.0
            )
            sleep_hours = np.clip(base_sleep - (current_fatigue * 0.5), 4, 10)
            sleep.append(sleep_hours)

            # Adım ve aktif süre (uyku azsa ve yorgunsa düşer)
            fatigue_penalty = current_fatigue * 1000
            if profile == 0:
                day_steps = np.clip(
                    np.random.normal(4000, 1000) - fatigue_penalty, 500, 8000
                )
                day_risk = np.random.choice([1, 2], p=[0.4, 0.6])
            elif profile == 1:
                day_steps = np.clip(
                    np.random.normal(7000, 1500) - fatigue_penalty, 2000, 12000
                )
                day_risk = np.random.choice([0, 1], p=[0.7, 0.3])
            else:
                day_steps = np.clip(
                    np.random.normal(12000, 3000) - fatigue_penalty, 5000, 20000
                )
                day_risk = 0

            steps.append(day_steps)
            active.append(day_steps / 150.0)  # Yaklaşık aktif dakika
            risk.append(day_risk)

            # Aşırı yüksek adımdan sonra yorgunluk birikir
            if day_steps > 10000:
                current_fatigue = min(2.0, current_fatigue + 0.5)
            else:
                current_fatigue = max(0.0, current_fatigue - 0.5)

        X_data.append(np.column_stack([steps, active, sleep, risk]))

        # Etiket üretimi (Hangi egzersizleri sever/tamamlar?)
        avg_risk = np.mean(risk)
        avg_steps = np.mean(steps)

        # 0: Yürüyüş, 1: Yoga, 2: Hafif Koşu, 3: Bisiklet, 4: HIIT/Ağırlık
        labels = [0, 0, 0, 0, 0]
        if profile == 0 or avg_risk > 1.5:
            labels[0] = np.random.choice([0, 1], p=[0.1, 0.9])
            labels[1] = np.random.choice([0, 1], p=[0.2, 0.8])
            labels[4] = 0  # Yüksek şiddet riskli
        elif profile == 2 or avg_steps > 9000:
            labels[2] = np.random.choice([0, 1], p=[0.3, 0.7])
            labels[3] = np.random.choice([0, 1], p=[0.4, 0.6])
            labels[4] = np.random.choice([0, 1], p=[0.2, 0.8])
        else:
            labels[0] = np.random.choice([0, 1], p=[0.3, 0.7])
            labels[1] = np.random.choice([0, 1], p=[0.4, 0.6])
            labels[2] = np.random.choice([0, 1], p=[0.5, 0.5])
            labels[3] = np.random.choice([0, 1], p=[0.6, 0.4])
            labels[4] = np.random.choice([0, 1], p=[0.8, 0.2])

        Y_data.append(labels)

    X_arr = np.array(X_data)  # (n_users, 14, 4)
    Y_arr = np.array(Y_data)  # (n_users, 5)

    return X_arr, Y_arr


def train_exercise_rnn():
    print("PyTorch RNN Öneri Modeli Eğitimi Başlıyor (Modül 6)...")
    X, Y = generate_recommender_data(2000)

    # 3D Normalizasyon (batch, seq, features) -> (batch*seq, features)
    batch, seq, feats = X.shape
    X_flat = X.reshape(-1, feats)
    scaler = StandardScaler()
    X_flat_scaled = scaler.fit_transform(X_flat)
    X_scaled = X_flat_scaled.reshape(batch, seq, feats)

    X_t = torch.tensor(X_scaled, dtype=torch.float32)
    Y_t = torch.tensor(Y, dtype=torch.float32)  # BCE Loss için float

    dataset = TensorDataset(X_t, Y_t)
    loader = DataLoader(dataset, batch_size=32, shuffle=True)

    model = ExerciseRNN(input_size=4, hidden_size=16, num_classes=5)

    # Tezde belirtilen BCE (Binary Cross Entropy) kaybı
    criterion = nn.BCELoss()
    optimizer = optim.Adam(model.parameters(), lr=0.01)

    epochs = 20
    for epoch in range(epochs):
        model.train()
        running_loss = 0.0
        for inputs, targets in loader:
            optimizer.zero_grad()
            outputs = model(inputs)
            loss = criterion(outputs, targets)
            loss.backward()
            optimizer.step()
            running_loss += loss.item() * inputs.size(0)

        print(
            f"Epoch {epoch + 1}/{epochs} - Train BCE Loss: {running_loss / len(dataset):.4f}"
        )

    os.makedirs("ml_models", exist_ok=True)
    torch.save(model.state_dict(), "ml_models/exercise_rnn.pt")
    joblib.dump(scaler, "ml_models/rnn_scaler.pkl")
    print("Modül 6 dosyaları (Model, Scaler) ml_models/ klasörüne kaydedildi.")


if __name__ == "__main__":
    train_exercise_rnn()
