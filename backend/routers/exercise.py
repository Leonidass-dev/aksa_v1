import logging
import crud
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from database import get_db
from auth import get_current_user
from models.exercise_model import (
    ExerciseRequest,
    ExercisePlanResponse,
    get_exercise_class,
    get_fallback_plan
)
from services.exercise_generator import generate_dynamic_plan

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/exercise-plan",
    tags=["Exercise"]
)

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
        
        # 1. Klasifikasyon: Güvenlik Sınırı Belirle
        class_id = await get_exercise_class(req, records)
        
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
        logger.error(f"Egzersiz planı router hatası: {e}")
        return get_fallback_plan(0)  # En güvenli fallback
