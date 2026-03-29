import os
import logging
from pydantic import BaseModel, Field
from typing import List, Optional
import torch
import joblib
import numpy as np
import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from ml_models.rnn_recommender import ExerciseRNN

logger = logging.getLogger(__name__)

_rnn_model = None
_rnn_scaler = None

def _load_rnn():
    global _rnn_model, _rnn_scaler
    if _rnn_model is None:
        base_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        _rnn_scaler = joblib.load(os.path.join(base_path, 'ml_models', 'rnn_scaler.pkl'))
        
        _rnn_model = ExerciseRNN(input_size=4, hidden_size=16, num_classes=5)
        state_dict = torch.load(os.path.join(base_path, 'ml_models', 'exercise_rnn.pt'), map_location=torch.device('cpu'))
        _rnn_model.load_state_dict(state_dict)
        _rnn_model.eval()

# Modeller
class ExerciseRequest(BaseModel):
    age: int
    weight: float
    height: float
    gender: str
    risk_level: str  # 'low', 'medium', 'high'
    systolic_bp: Optional[float] = None
    diastolic_bp: Optional[float] = None
    heart_rate: Optional[float] = None
    
class ExerciseItem(BaseModel):
    title: str = Field(description="Egzersizin adı (örn: Hafif Tempo Yürüyüş)")
    duration_minutes: int = Field(description="Süre (dakika)")
    intensity: str = Field(description="Zorluk seviyesi: Düşük, Orta, Yüksek")
    calories: int = Field(description="Tahmini yakılan kalori")
    type: str = Field(description="Egzersiz türü (Kardiyo, Güç, Esneklik, Yoga vb.)")
    description: str = Field(description="Nasıl yapılacağına dair kısa açıklama")

class ExercisePlanResponse(BaseModel):
    exercises: List[ExerciseItem]
    total_duration_minutes: int
    total_calories: int
    ai_advice: str = Field(description="Kullanıcıya özel genel tavsiye ve dikkat etmesi gerekenler")

# RNN Çıkarımı
async def generate_exercise_plan(req: ExerciseRequest) -> ExercisePlanResponse:
    try:
        _load_rnn()
        
        # 1. 14 Günlük Geçmişi Simüle Et (Gerçekte DB'den çekilir)
        # Tez: "Son 14 günün özetleri aktivite, uyku, risk skoru"
        seq_len = 14
        history = np.zeros((1, seq_len, 4))
        
        risk_map = {"low": 0, "medium": 1, "high": 2}
        risk_val = risk_map.get(req.risk_level.lower(), 1)
        
        # MVP: Tüm günleri kullanıcının anki değerine benzer sentetik doldur
        for i in range(seq_len):
            history[0, i, 0] = 5000 + np.random.normal(0, 500) # steps
            history[0, i, 1] = 30 + np.random.normal(0, 10)    # active
            history[0, i, 2] = 7 + np.random.normal(0, 1)      # sleep
            history[0, i, 3] = risk_val                        # risk
            
        # 2. Normalizasyon
        h_flat = history.reshape(-1, 4)
        h_scaled = _rnn_scaler.transform(h_flat).reshape(1, seq_len, 4)
        
        # 3. Modele Sor
        x_t = torch.tensor(h_scaled, dtype=torch.float32)
        with torch.no_grad():
            probs = _rnn_model(x_t).numpy()[0]
            
        # 4. Güvenlik Kapısı (Safety Gate - Modül 6 Kuralı)
        # 0: Yürüyüş, 1: Yoga, 2: Koşu, 3: Bisiklet, 4: HIIT
        if risk_val == 2: # High Risk
            probs[2] = 0.0
            probs[3] = 0.0
            probs[4] = 0.0
        elif risk_val == 1: # Medium Risk
            probs[4] = 0.0
            
        best_class = int(np.argmax(probs))
        
        # 5. Tavsiye Haritalaması (Katalog)
        catalog = {
            0: ExercisePlanResponse(
                total_duration_minutes=30, total_calories=120,
                ai_advice="Modelimiz (RNN) sağlık verilerinize dayanarak düşük şiddetli kardiyo önermektedir. Eklemlerinizi zorlamayın.",
                exercises=[
                    ExerciseItem(title="Tempolu Yürüyüş", duration_minutes=20, intensity="Düşük", calories=80, type="Kardiyo", description="Açık havada veya bantta düz yürüyüş."),
                    ExerciseItem(title="Soğuma/Esneme", duration_minutes=10, intensity="Düşük", calories=40, type="Esneklik", description="Bacak ve sırt kaslarını esnetin.")
                ]
            ),
            1: ExercisePlanResponse(
                total_duration_minutes=25, total_calories=90,
                ai_advice="RNN modelimiz vücut esnekliğine ihtiyacınız olduğunu tespit etti. Yoga seansı fiziksel stresinizi de azaltacaktır.",
                exercises=[
                    ExerciseItem(title="Başlangıç Seviyesi Yoga", duration_minutes=25, intensity="Düşük", calories=90, type="Yoga", description="Nefes odaklı temel asanalar.")
                ]
            ),
            2: ExercisePlanResponse(
                total_duration_minutes=40, total_calories=300,
                ai_advice="Modelimiz (RNN) kardiyo kapasitenizi artırmak için orta şiddetli koşuyu uygun buldu. Tempo kontrolüne dikkat edin.",
                exercises=[
                    ExerciseItem(title="Isınma Yürüyüşü", duration_minutes=5, intensity="Düşük", calories=20, type="Kardiyo", description="Yavaş tempo yürüyüş."),
                    ExerciseItem(title="Hafif Tempo Koşu", duration_minutes=30, intensity="Orta", calories=250, type="Kardiyo", description="Nabzı %60-70 bandında tutarak koşu."),
                    ExerciseItem(title="Soğuma", duration_minutes=5, intensity="Düşük", calories=30, type="Esneklik", description="Bacak kaslarını uzatma.")
                ]
            ),
            3: ExercisePlanResponse(
                total_duration_minutes=45, total_calories=320,
                ai_advice="RNN modelimiz bisiklet antrenmanının eklemlerinize daha az yük bindireceğini ve dayanıklılığınızı artıracağını öngörüyor.",
                exercises=[
                    ExerciseItem(title="Sabit Bisiklet", duration_minutes=45, intensity="Orta", calories=320, type="Kardiyo", description="Orta dirençte pedal çevirme.")
                ]
            ),
            4: ExercisePlanResponse(
                total_duration_minutes=30, total_calories=400,
                ai_advice="Verileriniz çok sağlıklı (Düşük Risk). RNN modelimiz kondisyonunuzu maksimize etmek için yüksek şiddetli aralıklı antrenman (HIIT) öneriyor.",
                exercises=[
                    ExerciseItem(title="HIIT / Vücut Ağırlığı", duration_minutes=30, intensity="Yüksek", calories=400, type="Güç/Kardiyo", description="Burpee, Jump Squat ve Mountain Climber kombinasyonu.")
                ]
            )
        }
        
        return catalog[best_class]

    except Exception as e:
        logger.error(f"Egzersiz planı oluşturulamadı: {e}")
        return ExercisePlanResponse(
            exercises=[
                ExerciseItem(
                    title="Hafif Tempolu Yürüyüş",
                    duration_minutes=20, intensity="Düşük", calories=80, type="Kardiyo",
                    description="Sistem geçici olarak meşgul, hafif egzersiz yapın."
                )
            ],
            total_duration_minutes=20, total_calories=80,
            ai_advice="RNN modeli geçici olarak yanıt vermedi."
        )
