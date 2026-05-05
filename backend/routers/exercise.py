import logging
import crud
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession
from database import get_db
from auth import get_current_user
from models.exercise_model import (
    ExerciseRequest,
    ExercisePlanResponse,
    ExerciseItem,
    get_exercise_class,
    get_fallback_plan
)
from services.exercise_generator import generate_dynamic_plan

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/exercise-plan",
    tags=["Exercise"]
)

class ExerciseFeedbackRequest(BaseModel):
    feedback: str = Field(description="'too_hard', 'too_easy', 'perfect'")

@router.post("", response_model=ExercisePlanResponse)
async def get_exercise_plan(
    req: ExerciseRequest,
    uid: str = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Hibrit Egzersiz Önerisi:
    1. Classifier (RNN/Kural) ile güvenli yoğunluk seviyesi (0-4) belirlenir.
    2. Gemini AI ile bu yoğunlukta kişiselleştirilmiş içerik üretilir.
    """
    try:
        user = await crud.get_or_create_user(db, uid)
        
        # Son 14 günlük sağlık verilerini çek (Context için)
        records = await crud.get_health_records(db, user, days=14)
        
        # M2 Pipeline'dan bugünün temizlenmiş özellik matrisini çek
        today_record = await crud.get_today_health(db, user)
        ml_features = today_record.ml_features if today_record and hasattr(today_record, 'ml_features') else None
        
        # 1. Klasifikasyon: Güvenlik Sınırı Belirle
        last_plan = await crud.get_last_exercise_plan(db, user)
        last_feedback = last_plan.feedback if last_plan else None
        
        class_id = await get_exercise_class(req, records, ml_features=ml_features, last_feedback=last_feedback)
        
        # 2. Sağlık Özeti (Prompt için)
        health_context = "Son 14 gün özeti:\n"
        if records:
            avg_steps = sum(r.steps for r in records) / len(records)
            health_context += f"- Ortalama Adım: {avg_steps:.0f}\n"
            latest = records[0]
            health_context += f"- Son Tansiyon: {latest.systolic}/{latest.diastolic}\n"
            health_context += f"- Son Nabız: {latest.heart_rate} bpm\n"
        else:
            health_context += "Veri henüz yok."

        # 2.5 SMART CACHE: Eğer son 24 saatte üretilmiş bir plan varsa onu kullan (force_refresh değilse)
        from db_models import get_turkey_time
        if not req.force_refresh and last_plan and last_plan.created_at > (get_turkey_time() - timedelta(hours=24)):
            logger.info(f"♻️ SMART CACHE: Son 24 saat içinde üretilmiş plan bulundu (ID: {last_plan.id}), Gemini atlanıyor.")
            return ExercisePlanResponse(
                exercises=[ExerciseItem(**e) for e in last_plan.exercises],
                total_duration_minutes=last_plan.total_duration_minutes,
                total_calories=last_plan.total_calories,
                ai_advice=last_plan.ai_advice or ""
            )

        # 3. Dinamik İçerik Üretimi (Gemini)
        plan = await generate_dynamic_plan(req, class_id, health_context)

        # 4. Fallback: Gemini başarısız olursa statik plan kullan
        if not plan:
            logger.warning("Gemini planı üretilemedi, statik plana dönülüyor.")
            plan = get_fallback_plan(class_id)

        # DB'ye kaydet
        exercises_data = [
            {
                "title": e.title,
                "duration_minutes": e.duration_minutes,
                "intensity": e.intensity,
                "calories": e.calories,
                "type": e.type,
                "description": e.description,
            }
            for e in plan.exercises
        ]

        await crud.save_exercise_plan(
            db, user,
            exercises=exercises_data,
            total_duration=plan.total_duration_minutes,
            total_calories=plan.total_calories,
            ai_advice=plan.ai_advice or "",
        )

        return plan
    except Exception as e:
        logger.exception("Egzersiz planı router hatası")
        return get_fallback_plan(0)  # En güvenli fallback


@router.post("/feedback")
async def submit_exercise_feedback(
    req: ExerciseFeedbackRequest,
    uid: str = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Kullanıcının idman sonrası geri bildirimini kaydeder."""
    try:
        user = await crud.get_or_create_user(db, uid)
        
        # Kullanıcının en sonki egzersiz planını çek ve feedback'ini kaydet
        # Tez M6: "Kullanıcı geri bildirimi ile güncelleme" sağlandı.
        await crud.save_exercise_feedback(db, user, req.feedback)
        
        return {"status": "success", "message": "Geri bildiriminiz RNN döngüsüne eklendi."}
    except Exception as e:
        logger.exception("Egzersiz feedback hatası")
        return {"status": "error", "message": str(e)}
