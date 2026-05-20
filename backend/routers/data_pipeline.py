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
    heart_rate_data: List[SensorDataPoint] = Field(
        default_factory=list, description="Ham nabız verileri"
    )
    steps_data: List[SensorDataPoint] = Field(
        default_factory=list, description="Ham adım verileri"
    )


# --- Yanıt (Response) Modelleri ---
class PreprocessingResponse(BaseModel):
    status: str
    message: str
    processed_windows: int
    features: List[Dict[str, Any]]


from sqlalchemy.ext.asyncio import AsyncSession  # noqa: E402
from database import get_db  # noqa: E402
import crud  # noqa: E402


@router.post("/preprocess-sensor-data", response_model=PreprocessingResponse)
async def preprocess_sensor_data(
    req: PreprocessingRequest,
    uid: str = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Tez Modül 2: Zaman Serisi Sensör Verilerinin Temizlenmesi.
    Hampel Filtresi, Aykırı Değer Kırpma, Eksik Veri Enterpolasyonu ve
    Kayan Pencere (Sliding Window) Özellik Çıkarımı uygular.
    """
    try:
        # Pydantic modellerini Pandas DataFrame'ine çevir
        hr_df = pd.DataFrame(
            [{"timestamp": d.timestamp, "value": d.value} for d in req.heart_rate_data]
        )
        steps_df = pd.DataFrame(
            [{"timestamp": d.timestamp, "value": d.value} for d in req.steps_data]
        )

        # Eğer data boş ise hata fırlat
        if hr_df.empty and steps_df.empty:
            raise HTTPException(
                status_code=400, detail="Her iki sensör verisi de boş olamaz."
            )

        # Pipeline Sınıfını Tetikle (Tezdeki konfigürasyon)
        pipeline = PreprocessorPipeline(
            step_window_size=60, hr_window_size=60, stride=5, min_valid_pct=0.8
        )

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
                features_df["window_start"] = features_df["window_start"].dt.strftime(
                    "%Y-%m-%dT%H:%M:%S"
                )
                features_df["window_end"] = features_df["window_end"].dt.strftime(
                    "%Y-%m-%dT%H:%M:%S"
                )
                features_list = features_df.to_dict(orient="records")

                # Son çıkarılan özellikleri direkt olarak Veritabanına "Günlük Özellik" olarak mühürle
                user = await crud.get_or_create_user(db, uid)
                # Özelliklerin ortalamasını alıp kaydetmek M7 LSTM-AE için tutarlı bir data yapısı sağlar
                # features_list icerisindeki son pencerenin degerlerini M7 modeli icin kaydet
                if len(features_list) > 0:
                    # Mevcut kayıtları çek (Sequence oluşturmak için)
                    today_record = await crud.get_today_health(db, user)
                    existing_features = (
                        today_record.ml_features
                        if today_record and today_record.ml_features
                        else []
                    )

                    # Yeni pencereyi hazırla (9 Boyutlu standart WESAD vektörü)
                    latest_window = features_list[-1]
                    new_vector = [
                        latest_window.get("hr_mean", 0),
                        latest_window.get("hr_median", 0),
                        latest_window.get("hr_min", 0),
                        latest_window.get("hr_max", 0),
                        latest_window.get("hr_std", 0),
                        latest_window.get("steps_sum", 0),
                        latest_window.get("steps_active_mins", 0),
                        latest_window.get("steps_max", 0),
                        latest_window.get("missing_pct", 0),
                    ]

                    # Sequence (Zaman Serisi) Mantığı: Son 5 pencereyi biriktir
                    if existing_features and isinstance(existing_features, list):
                        if len(existing_features) > 0 and isinstance(
                            existing_features[0], list
                        ):
                            # Zaten bir matris ise sonuna ekle
                            new_sequence = (existing_features + [new_vector])[-5:]
                        else:
                            # Eski tekil veri formatı kalmışsa matrise çevir
                            new_sequence = [new_vector]
                    else:
                        new_sequence = [new_vector]

                    await crud.save_health_record(
                        db, user, data={"ml_features": new_sequence}
                    )

        return PreprocessingResponse(
            status="success",
            message="Veri temizleme (Hampel/Interpolation) ve Özellik çıkarımı (Sliding Window) başarıyla tamamlandı.",
            processed_windows=len(features_list),
            features=features_list,
        )

    except Exception as e:
        import traceback

        traceback.print_exc()
        raise HTTPException(
            status_code=500, detail=f"Veri işleme sırasında hata: {str(e)}"
        )
