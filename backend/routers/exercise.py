import logging
from fastapi import APIRouter
from pydantic import BaseModel
from typing import Optional
from models.exercise_model import (
    ExerciseRequest,
    ExercisePlanResponse,
    generate_exercise_plan
)

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/exercise-plan",
    tags=["Exercise"]
)

@router.post("", response_model=ExercisePlanResponse)
async def get_exercise_plan(req: ExerciseRequest):
    """
    Kullanıcının profil ve sağlık durumuna göre Gemini AI'dan dinamik
    egzersiz planı çeker.
    """
    try:
        plan = await generate_exercise_plan(req)
        return plan
    except Exception as e:
        logger.error(f"Egzersiz planı router hatası: {e}")
        # Hata durumunda model zaten fallback dönse de buraya da ek güvenlik koyabiliriz
        pass 
