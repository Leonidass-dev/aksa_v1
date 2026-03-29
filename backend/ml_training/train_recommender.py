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
from ml_models.rnn_recommender import ExerciseRNN

def generate_recommender_data(n_users=500):
    """
    Kullanıcı bazlı 14 günlük geçmiș simülasyonu.
    Girdi: 14 * [adim_sayisi, aktif_dk, uyku_saati, günlük_risk] = (14, 4)
    Çıktı: 5 farklı egzersiz tipi için tamamlama etiketi (1 veya 0)
    Egzersiz Tipleri:
    0: Yürüyüş (Düşük Şiddet)
    1: Yoga/Esneme (Düşük Şiddet)
    2: Tempolu Koşu (Orta Şiddet)
    3: Bisiklet (Orta Şiddet)
    4: HIIT / Ağırlık (Yüksek Şiddet)
    """
    np.random.seed(42)
    X_data = []
    Y_data = []
    
    for _ in range(n_users):
        # 14 günlük zaman serisi
        steps = np.random.normal(5000, 2000, 14)
        active = np.random.normal(30, 15, 14)
        sleep = np.random.normal(7, 1.5, 14)
        risk = np.random.randint(0, 3, 14)
        
        user_x = np.column_stack([steps, active, sleep, risk])
        X_data.append(user_x)
        
        # Etiket üretimi: Eğer risk yüksekse yürüyüş sever, fit ise HIIT sever
        avg_risk = np.mean(risk)
        avg_steps = np.mean(steps)
        
        labels = [0, 0, 0, 0, 0]
        if avg_risk > 1.5:
            # Sağlık riski var, yürüyüş/yoga (0, 1) iyi gelir
            labels[0] = np.random.choice([0, 1], p=[0.2, 0.8])
            labels[1] = np.random.choice([0, 1], p=[0.3, 0.7])
            labels[4] = np.random.choice([0, 1], p=[0.9, 0.1])
        elif avg_steps > 6000:
            # Fit insan, koşu, HIIT (2, 4) sever
            labels[2] = np.random.choice([0, 1], p=[0.2, 0.8])
            labels[4] = np.random.choice([0, 1], p=[0.3, 0.7])
            labels[0] = np.random.choice([0, 1], p=[0.8, 0.2])
        else:
            # Ortalama
            labels = np.random.randint(0, 2, 5).tolist()
            
        Y_data.append(labels)
        
    X_arr = np.array(X_data) # (500, 14, 4)
    Y_arr = np.array(Y_data) # (500, 5)
    
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
    Y_t = torch.tensor(Y, dtype=torch.float32) # BCE Loss için float
    
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
            
        print(f"Epoch {epoch+1}/{epochs} - Train BCE Loss: {running_loss/len(dataset):.4f}")
        
    os.makedirs('ml_models', exist_ok=True)
    torch.save(model.state_dict(), 'ml_models/exercise_rnn.pt')
    joblib.dump(scaler, 'ml_models/rnn_scaler.pkl')
    print("Modül 6 dosyaları (Model, Scaler) ml_models/ klasörüne kaydedildi.")

if __name__ == "__main__":
    train_exercise_rnn()
