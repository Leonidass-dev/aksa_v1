import logging
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from models.exercise_model import (
    ExerciseRequest,
    ExercisePlanResponse,
    generate_exercise_plan
)
from database import get_db
from auth import get_current_user
import crud

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
    Kullanıcının profil ve sağlık durumuna göre Gemini AI'dan dinamik
    egzersiz planı çeker ve PostgreSQL'e kaydeder.
    """
    try:
        user = await crud.get_or_create_user(db, uid)
        
        # Son 14 günlük sağlık verilerini DB'den çek
        records = await crud.get_health_records(db, user, days=14)
        
        plan = await generate_exercise_plan(req, records)

        # DB'ye kaydet
        if plan:
            exercises_data = []
            if plan.exercises:
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
        # Fallback: Basit yürüyüş planı döndür
        from models.exercise_model import ExercisePlanResponse, ExerciseItem
        return ExercisePlanResponse(
            total_duration_minutes=30,
            total_calories=120,
            ai_advice="Şu an kişisel plan oluşturulamadı. Temel bir yürüyüş planı öneriyoruz.",
            exercises=[
                ExerciseItem(
                    title="Tempolu Yürüyüş",
                    duration_minutes=30,
                    intensity="Düşük",
                    calories=120,
                    type="Kardiyo",
                    description="Açık havada veya bantta düz yürüyüş.",
                )
            ],
        )
