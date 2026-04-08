"""
M6 — Egzersiz Planı Modeli
RNN varsa kullanır, yoksa kural tabanlı katalog fallback.
"""

import os
import logging
import numpy as np
import sys
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import date, timedelta

logger = logging.getLogger(__name__)

# ── ML Import (Opsiyonel) ──────────────────────────────────────────
_HAS_ML = False
try:
    import torch
    import joblib
    sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from ml_models.rnn_recommender import ExerciseRNN
    _HAS_ML = True
    logger.info("✅ Egzersiz modeli: RNN yüklendi")
except ImportError as e:
    logger.warning(f"⚠️  RNN yüklenemedi ({e}) — Kural tabanlı fallback aktif")

_rnn_model = None
_rnn_scaler = None


def _load_rnn():
    global _rnn_model, _rnn_scaler
    if not _HAS_ML or _rnn_model is not None:
        return
    try:
        base_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        _rnn_scaler = joblib.load(os.path.join(base_path, 'ml_models', 'rnn_scaler.pkl'))
        _rnn_model = ExerciseRNN(input_size=4, hidden_size=16, num_classes=5)
        state_dict = torch.load(os.path.join(base_path, 'ml_models', 'exercise_rnn.pt'), map_location=torch.device('cpu'))
        _rnn_model.load_state_dict(state_dict)
        _rnn_model.eval()
        logger.info("✅ RNN egzersiz modeli belleğe yüklendi")
    except Exception as e:
        logger.warning(f"⚠️  RNN model dosyaları yüklenemedi: {e}")


# ── Pydantic Modelleri ─────────────────────────────────────────────

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
    title: str = Field(description="Egzersizin adı")
    duration_minutes: int = Field(description="Süre (dakika)")
    intensity: str = Field(description="Zorluk: Düşük, Orta, Yüksek")
    calories: int = Field(description="Tahmini yakılan kalori")
    type: str = Field(description="Egzersiz türü")
    description: str = Field(description="Kısa açıklama")


class ExercisePlanResponse(BaseModel):
    exercises: List[ExerciseItem]
    total_duration_minutes: int
    total_calories: int
    ai_advice: str = Field(description="Kullanıcıya özel tavsiye")


# ── Egzersiz Katalogları ───────────────────────────────────────────

_CATALOG = {
    0: ExercisePlanResponse(
        total_duration_minutes=30, total_calories=120,
        ai_advice="Düşük şiddetli kardiyo öneriyoruz. Eklemlerinizi zorlamayın.",
        exercises=[
            ExerciseItem(title="Tempolu Yürüyüş", duration_minutes=20, intensity="Düşük", calories=80, type="Kardiyo", description="Açık havada veya bantta düz yürüyüş."),
            ExerciseItem(title="Soğuma/Esneme", duration_minutes=10, intensity="Düşük", calories=40, type="Esneklik", description="Bacak ve sırt kaslarını esnetin.")
        ]
    ),
    1: ExercisePlanResponse(
        total_duration_minutes=25, total_calories=90,
        ai_advice="Esneklik ve rahatlama seansı öneriyoruz. Yoga stres azaltmaya da yardımcı olur.",
        exercises=[
            ExerciseItem(title="Başlangıç Seviyesi Yoga", duration_minutes=25, intensity="Düşük", calories=90, type="Yoga", description="Nefes odaklı temel asanalar.")
        ]
    ),
    2: ExercisePlanResponse(
        total_duration_minutes=40, total_calories=300,
        ai_advice="Kardiyo kapasitenizi artırmak için orta şiddetli koşu öneriyoruz.",
        exercises=[
            ExerciseItem(title="Isınma Yürüyüşü", duration_minutes=5, intensity="Düşük", calories=20, type="Kardiyo", description="Yavaş tempo yürüyüş."),
            ExerciseItem(title="Hafif Tempo Koşu", duration_minutes=30, intensity="Orta", calories=250, type="Kardiyo", description="Nabzı %60-70 bandında tutarak koşu."),
            ExerciseItem(title="Soğuma", duration_minutes=5, intensity="Düşük", calories=30, type="Esneklik", description="Bacak kaslarını uzatma.")
        ]
    ),
    3: ExercisePlanResponse(
        total_duration_minutes=45, total_calories=320,
        ai_advice="Bisiklet antrenmanı eklemlerinize az yük binerken dayanıklılığınızı artırır.",
        exercises=[
            ExerciseItem(title="Sabit Bisiklet", duration_minutes=45, intensity="Orta", calories=320, type="Kardiyo", description="Orta dirençte pedal çevirme.")
        ]
    ),
    4: ExercisePlanResponse(
        total_duration_minutes=30, total_calories=400,
        ai_advice="Verileriniz çok sağlıklı. HIIT ile kondisyonunuzu maksimize edin!",
        exercises=[
            ExerciseItem(title="HIIT / Vücut Ağırlığı", duration_minutes=30, intensity="Yüksek", calories=400, type="Güç/Kardiyo", description="Burpee, Jump Squat ve Mountain Climber.")
        ]
    ),
}


def _pick_plan_rules(req: ExerciseRequest) -> int:
    """Risk seviyesine göre basit kural tabanlı plan seçimi."""
    risk = req.risk_level.lower()
    if risk == "high":
        return 0  # Sadece yürüyüş
    elif risk == "medium":
        return 1 if req.age > 50 else 0  # Yoga veya yürüyüş
    else:
        # Düşük risk — yaşa göre
        if req.age < 30:
            return 4  # HIIT
        elif req.age < 50:
            return 2  # Koşu
        else:
            return 3  # Bisiklet


def _pick_plan_rnn(req: ExerciseRequest, records: list = None) -> int:
    """RNN ile plan seçimi (Kullanıcının gerçek verileriyle)."""
    _load_rnn()
    if _rnn_model is None:
        return _pick_plan_rules(req)

    risk_map = {"low": 0, "medium": 1, "high": 2}
    risk_val = risk_map.get(req.risk_level.lower(), 1)

    seq_len = 14
    history = np.zeros((1, seq_len, 4))
    
    if records is None:
        records = []
        
    today = date.today()
    record_dict = {r.record_date: r for r in records}

    for i in range(seq_len):
        # Time index: 0 = en eski (13 gün önce), 13 = bugün
        target_date = today - timedelta(days=(seq_len - 1 - i))
        r = record_dict.get(target_date)
        
        if r:
            steps = float(r.steps or 0)
            # Aktif Süreyi aktif kaloriden veya adımdan tahmin et
            active_cals = getattr(r, 'active_calories', 0)
            if active_cals and active_cals > 0:
                active_mins = float(active_cals / 5)
            else:
                active_mins = float(steps / 100)
                
            sleep = float(r.sleep_hours or 0)
            
            # Eğer veri 0 olarak geldiyse modeli şaşırtmamak için taban değerlere çek
            if steps == 0: steps = 1000.0
            if active_mins == 0: active_mins = 10.0
            if sleep == 0: sleep = 5.0
        else:
            # Padding (Kullanıcının eksik gününü sahte uç noktalara çekmek yerine düşük aktif bir profille doldur)
            steps = 2000.0
            active_mins = 15.0
            sleep = 6.0
            
        history[0, i, 0] = steps
        history[0, i, 1] = active_mins
        history[0, i, 2] = sleep
        history[0, i, 3] = risk_val

    h_flat = history.reshape(-1, 4)
    h_scaled = _rnn_scaler.transform(h_flat).reshape(1, seq_len, 4)

    x_t = torch.tensor(h_scaled, dtype=torch.float32)
    with torch.no_grad():
        probs = _rnn_model(x_t).numpy()[0]

    # Güvenlik Kapısı
    if risk_val == 2:
        probs[2] = 0.0; probs[3] = 0.0; probs[4] = 0.0
    elif risk_val == 1:
        probs[4] = 0.0

    return int(np.argmax(probs))


async def get_exercise_class(req: ExerciseRequest, records: list = None) -> int:
    """Yoğunluk seviyesini (0-4) belirleyen ana sınıflandırıcı."""
    try:
        if _HAS_ML:
            return _pick_plan_rnn(req, records)
        else:
            return _pick_plan_rules(req)
    except Exception as e:
        logger.error(f"Egzersiz sınıflandırma hatası: {e}")
        return 0  # Fallback: Yürüyüş sınıfı

def get_fallback_plan(class_id: int) -> ExercisePlanResponse:
    """Gemini başarısız olursa kullanılacak statik plan."""
    return _CATALOG.get(class_id, _CATALOG[0])
