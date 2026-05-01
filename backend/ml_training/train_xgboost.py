import pandas as pd
import numpy as np
import xgboost as xgb
from sklearn.model_selection import GroupShuffleSplit
from sklearn.preprocessing import StandardScaler
from sklearn.calibration import CalibratedClassifierCV
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
    
    # 2. Tez M3: Kullanıcı Bazlı Train-Test Split (Veri sızıntısını önlemek için)
    # "Bölme kullanıcı bazlı yapılır; aynı kullanıcının pencereleri birden fazla bölmeye düşmez."
    if 'subject_id' in df.columns:
        groups = df['subject_id']
        gss = GroupShuffleSplit(n_splits=1, test_size=0.2, random_state=42)
        train_idx, test_idx = next(gss.split(X, y, groups))
        X_train, X_test = X.iloc[train_idx], X.iloc[test_idx]
        y_train, y_test = y.iloc[train_idx], y.iloc[test_idx]
        print(f"Kullanıcı bazlı split: Train denekler: {groups.iloc[train_idx].nunique()}, "
              f"Test denekler: {groups.iloc[test_idx].nunique()}")
    else:
        # Eski veri formatı desteği (subject_id yoksa)
        from sklearn.model_selection import train_test_split
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42, stratify=y
        )
        print("⚠️  subject_id bulunamadı, rastgele split kullanılıyor.")
    
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
              
    # 5. Değerlendirme (Kalibrasyon öncesi)
    preds = model.predict(X_test_scaled)
    acc = accuracy_score(y_test, preds)
    print(f"Test Doğruluğu (Kalibrasyon Öncesi): {acc:.4f}")
    print("\nSınıflandırma Raporu:")
    print(classification_report(y_test, preds))
    
    # 6. Tez M3: Platt Scaling (Olasılık Kalibrasyonu)
    # "Ölçümleme adımı olarak Platt scaling uygulanır"
    print("Platt Scaling (Sigmoid Kalibrasyon) uygulanıyor...")
    calibrated_model = CalibratedClassifierCV(
        model, method='sigmoid', cv=3
    )
    calibrated_model.fit(X_train_scaled, y_train)
    
    preds_cal = calibrated_model.predict(X_test_scaled)
    acc_cal = accuracy_score(y_test, preds_cal)
    print(f"Test Doğruluğu (Kalibrasyon Sonrası): {acc_cal:.4f}")
    
    # 7. Modeli Kaydetme
    os.makedirs('ml_models', exist_ok=True)
    joblib.dump(scaler, 'ml_models/risk_scaler.pkl')
    joblib.dump(calibrated_model, 'ml_models/risk_xgboost.pkl')
    print("Kalibre edilmiş model ve Scaler kaydedildi: ml_models/risk_xgboost.pkl")

if __name__ == "__main__":
    train_risk_xgboost()
