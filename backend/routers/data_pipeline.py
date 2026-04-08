from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from typing import List, Dict, Any
import pandas as pd

from auth import get_current_user
from ml_pipeline.preprocessing import PreprocessorPipeline

router = APIRouter()

# --- İstek (Request) Modelleri ---
class SensorDataPoint(BaseModel):
    timestamp: str = Field(..., description="ISO 8601 formatında zaman damgası")
    value: float = Field(..., description="Sensör okuması (örn: Nabız veya Adım)")

class PreprocessingRequest(BaseModel):
    heart_rate_data: List[SensorDataPoint] = Field(default_factory=list, description="Ham nabız verileri")
    steps_data: List[SensorDataPoint] = Field(default_factory=list, description="Ham adım verileri")

# --- Yanıt (Response) Modelleri ---
class PreprocessingResponse(BaseModel):
    status: str
    message: str
    processed_windows: int
    features: List[Dict[str, Any]]

@router.post("/preprocess-sensor-data", response_model=PreprocessingResponse)
def preprocess_sensor_data(
    req: PreprocessingRequest,
    uid: str = Depends(get_current_user)
):
    """
    Tez Modül 2: Zaman Serisi Sensör Verilerinin Temizlenmesi.
    Hampel Filtresi, Aykırı Değer Kırpma, Eksik Veri Enterpolasyonu ve
    Kayan Pencere (Sliding Window) Özellik Çıkarımı uygular.
    """
    try:
        # Pydantic modellerini Pandas DataFrame'ine çevir
        hr_df = pd.DataFrame([{"timestamp": d.timestamp, "value": d.value} for d in req.heart_rate_data])
        steps_df = pd.DataFrame([{"timestamp": d.timestamp, "value": d.value} for d in req.steps_data])

        # Eğer data boş ise hata fırlat
        if hr_df.empty and steps_df.empty:
            raise HTTPException(status_code=400, detail="Her iki sensör verisi de boş olamaz.")

        # Pipeline Sınıfını Tetikle (Tezdeki konfigürasyon)
        pipeline = PreprocessorPipeline(step_window_size=60, hr_window_size=60, stride=5, min_valid_pct=0.8)

        # 1. Gürültülü HR Verilerini Temizle (Medyan Filtre, Hampel Filtre)
        clean_hr_df = pd.DataFrame()
        if not hr_df.empty:
            clean_hr_df = pipeline.process_heart_rate(hr_df)

        # 2. Gürültülü Adım Verilerini Temizle (Negatif kesme, patlama kırpma)
        clean_steps_df = pd.DataFrame()
        if not steps_df.empty:
            clean_steps_df = pipeline.process_steps(steps_df)

        # 3. Sliding Window Özellik Çıkarımı (Feature Extraction)
        # Sadece ikisi de doluysa pencere çıkarır (Tez mantığı)
        features_list = []
        if not clean_hr_df.empty and not clean_steps_df.empty:
            features_df = pipeline.create_features(clean_hr_df, clean_steps_df)
            
            if not features_df.empty:
                # Geriye dönerken timestamp'leri stringe çevir
                features_df['window_start'] = features_df['window_start'].dt.strftime('%Y-%m-%dT%H:%M:%S')
                features_df['window_end'] = features_df['window_end'].dt.strftime('%Y-%m-%dT%H:%M:%S')
                features_list = features_df.to_dict(orient="records")

        return PreprocessingResponse(
            status="success",
            message="Veri temizleme (Hampel/Interpolation) ve Özellik çıkarımı (Sliding Window) başarıyla tamamlandı.",
            processed_windows=len(features_list),
            features=features_list
        )

    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Veri işleme sırasında hata: {str(e)}")
