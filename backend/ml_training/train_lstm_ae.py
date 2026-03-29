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

def train_anomaly_ae():
    print("PyTorch LSTM-AE Modeli Eğitimi Başlıyor (Modül 7)...")
    
    # 1. Veri Yükleme
    df = pd.read_csv('ml_training/data/synthetic_health_windows.csv')
    feature_cols = ['hr_mean', 'hr_median', 'hr_min', 'hr_max', 'hr_std', 
                    'steps_sum', 'steps_active_mins', 'steps_max', 'missing_pct']
    
    # LSTM-AE sadece \"Normal\" veri kullanılarak eğitilir. 
    # Tez: "Normal davranış modellemesi için LSTM tabanlı otokodlayıcı kullanılır."
    df_normal = df[df['anomaly_label'] == 0]
    
    X_normal = df_normal[feature_cols].values
    
    # Normalizasyon
    scaler = StandardScaler()
    X_normal_scaled = scaler.fit_transform(X_normal)
    
    X_t = torch.tensor(X_normal_scaled, dtype=torch.float32).unsqueeze(1) # (batch, 1, features)
    
    train_data = TensorDataset(X_t, X_t) # Hedef kendisi (Autoencoder)
    train_loader = DataLoader(train_data, batch_size=32, shuffle=True)
    
    # Model Tanımlama
    input_size = len(feature_cols)
    model = LSTMAutoencoder(input_size=input_size, hidden_size=16)
    
    criterion = nn.MSELoss()
    optimizer = optim.Adam(model.parameters(), lr=0.01)
    
    # Eğitim
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
        print(f"Epoch {epoch+1}/{epochs} - Train MSE Loss: {epoch_loss:.4f}")
        
    # Eşik Değerinin Hesaplanması (Threshold)
    model.eval()
    with torch.no_grad():
        reconstructed = model(X_t)
        mses = torch.mean((reconstructed - X_t)**2, dim=[1,2]).numpy()
    
    # Normal verinin %95'ini kapsayacak threshold
    threshold = np.percentile(mses, 95)
    print(f"Hesaplanan Anomali Eşiği (Threshold): {threshold:.4f}")
    
    # Kaydetme
    os.makedirs('ml_models', exist_ok=True)
    torch.save(model.state_dict(), 'ml_models/lstm_ae.pt')
    joblib.dump(scaler, 'ml_models/ae_scaler.pkl')
    
    # Eşik değerini de metin veya config olarak kaydedelim
    with open('ml_models/ae_threshold.txt', 'w') as f:
        f.write(str(threshold))
        
    print("Modül 7 dosyaları (Model, Scaler, Threshold) ml_models/ klasörüne kaydedildi.")

if __name__ == "__main__":
    train_anomaly_ae()
