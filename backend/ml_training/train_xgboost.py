import pandas as pd
import numpy as np
import xgboost as xgb
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import accuracy_score, classification_report
import joblib
import os

def train_risk_xgboost():
    print("XGBoost Modeli Eğitimi Başlıyor (Modül 3)...")
    
    # 1. Veri Yükleme
    df = pd.read_csv('ml_training/data/wesad_processed.csv')
    
    # Özellikler (Features) ve Hedef (Target)
    feature_cols = ['hr_mean', 'hr_median', 'hr_min', 'hr_max', 'hr_std', 
                    'steps_sum', 'steps_active_mins', 'steps_max', 'missing_pct']
    
    X = df[feature_cols]
    y = df['risk_label']  # 0: Düşük, 1: Orta, 2: Yüksek
    
    # 2. Train-Test Split (Veri sızıntısını önlemek için)
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)
    
    # 3. Normalizasyon (Z-Score)
    # Tez: "Kalp atışı özellikleri için z-score standardizasyonu kullanılır"
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)
    
    # 4. XGBoost Model Tanımlama ve Eğitim
    model = xgb.XGBClassifier(
        objective='multi:softprob',
        num_class=3,
        eval_metric='mlogloss',
        max_depth=4,
        learning_rate=0.1,
        n_estimators=100,
        random_state=42
    )
    
    model.fit(X_train_scaled, y_train, 
              eval_set=[(X_test_scaled, y_test)], 
              verbose=False)
              
    # 5. Değerlendirme
    preds = model.predict(X_test_scaled)
    acc = accuracy_score(y_test, preds)
    print(f"Test Doğruluğu (Accuracy): {acc:.4f}")
    print("\nSınıflandırma Raporu:")
    print(classification_report(y_test, preds))
    
    # 6. Modeli Kaydetme
    os.makedirs('ml_models', exist_ok=True)
    joblib.dump(scaler, 'ml_models/risk_scaler.pkl')
    joblib.dump(model, 'ml_models/risk_xgboost.pkl')
    print("Model ve Scaler kaydedildi: ml_models/risk_xgboost.pkl")

if __name__ == "__main__":
    train_risk_xgboost()
