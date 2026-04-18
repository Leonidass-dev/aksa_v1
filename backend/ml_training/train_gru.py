import pandas as pd
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import TensorDataset, DataLoader
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
import joblib
import os
import sys

# GRU Modelini import edebilmek için parent klasörü path'e ekle
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from ml_models.gru_model import RiskGRU

def train_risk_gru():
    print("PyTorch GRU Modeli Eğitimi Başlıyor (Modül 3)...")
    
    # Veri Yükleme
    df = pd.read_csv('ml_training/data/wesad_processed.csv')
    feature_cols = ['hr_mean', 'hr_median', 'hr_min', 'hr_max', 'hr_std', 
                    'steps_sum', 'steps_active_mins', 'steps_max', 'missing_pct']
    
    X = df[feature_cols].values
    y = df['risk_label'].values
    
    # Train-test split
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)
    
    # Normalizasyon
    scaler = StandardScaler()
    X_train = scaler.fit_transform(X_train)
    X_test = scaler.transform(X_test)
    
    # Scaler'ı XGBoost ile farklı olabileceğinden ayır veya aynı bırak
    # Burada GRU için ayrı kaydetsek de olur. Ancak aynı veri seti, bu yüzden aynısı
    
    # PyTorch Tensorlerine Çevirme
    # GRU girdisi 3 boyutlu olmak zorundadır: (batch, seq_len, features)
    # Burada sequence mantığı simülasyonu için her pencere 1 birimlik bir sequence gibi verilecek
    # Gerçek uygulamada son N pencere içeri sokulur.
    X_train_t = torch.tensor(X_train, dtype=torch.float32).unsqueeze(1) # shape: (8000, 1, 9)
    y_train_t = torch.tensor(y_train, dtype=torch.long)
    X_test_t = torch.tensor(X_test, dtype=torch.float32).unsqueeze(1)
    y_test_t = torch.tensor(y_test, dtype=torch.long)
    
    # Dataloader
    train_data = TensorDataset(X_train_t, y_train_t)
    train_loader = DataLoader(train_data, batch_size=32, shuffle=True)
    
    # Model Tanımlama
    input_size = len(feature_cols)
    model = RiskGRU(input_size=input_size, hidden_size=32, num_classes=3)
    
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=0.005)
    
    # Eğitim Döngüsü
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
            
        print(f"Epoch {epoch+1}/{epochs} - Loss: {epoch_loss:.4f} - Val Accuracy: {acc:.4f}")
        
    # Modeli Kaydetme
    os.makedirs('ml_models', exist_ok=True)
    torch.save(model.state_dict(), 'ml_models/risk_gru.pt')
    print("PyTorch Modeli kaydedildi: ml_models/risk_gru.pt")

if __name__ == "__main__":
    train_risk_gru()
