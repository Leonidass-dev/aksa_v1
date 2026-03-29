import os
import json
import httpx
import logging
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from dotenv import load_dotenv
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from auth import get_current_user
import crud

load_dotenv()

logger = logging.getLogger(__name__)

router = APIRouter()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
GEMINI_URL = (
    "https://generativelanguage.googleapis.com/v1beta/models/"
    "gemini-3-flash-preview:generateContent"
)


class FoodAnalysisRequest(BaseModel):
    image_base64: str   # base64 encoded JPEG/PNG


class NutrientInfo(BaseModel):
    calories: int
    protein_g: float
    carbs_g: float
    fat_g: float
    fiber_g: float


class FoodAnalysisResponse(BaseModel):
    food_name: str
    portion: str
    nutrients: NutrientInfo
    health_score: int          # 0-100
    recommendation: str
    tags: list[str]


class MealHistoryItem(BaseModel):
    id: int
    food_name: str
    portion: str | None
    calories: int
    protein_g: float
    carbs_g: float
    fat_g: float
    fiber_g: float
    health_score: int
    recommendation: str | None
    tags: list | None
    analyzed_at: str


PROMPT = """
Sen bir beslenme uzmanı yapay zeka asistanısın.
Bu yemek fotoğrafını analiz et ve aşağıdaki JSON formatında yanıt ver.
Yanıtta SADECE JSON olsun, başka hiçbir metin olmasın.Eğer yemek tanınamıyorsa food_name = "Tanımlanamadı" yaz ve tüm sayısal değerleri 0 olarak döndür.

{
  "food_name": "yemeğin Türkçe adı",
  "portion": "tahmini porsiyon (örn: 1 kase ~250g)",
  "nutrients": {
    "calories": 350,
    "protein_g": 25.0,
    "carbs_g": 30.0,
    "fat_g": 12.0,
    "fiber_g": 4.0
  },
  "health_score": 75,
  "recommendation": "kısa, kişiselleştirilmiş öneri (1-2 cümle)",
  "tags": ["yüksek protein", "düşük karbonhidrat"]
}

health_score: 0 (çok sağlıksız) - 100 (çok sağlıklı)
Eğer yemek tanınamıyorsa food_name = "Tanımlanamadı" yaz.
"""


@router.post("/analyze-food", response_model=FoodAnalysisResponse)
async def analyze_food(
    req: FoodAnalysisRequest,
    uid: str = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    M5 — Yemek Fotoğrafı Analizi (Gemini Vision)
    Base64 JPEG/PNG alır, kalori + makro + öneri döner.
    Sonucu PostgreSQL'e kaydeder.
    """
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY eksik")

    payload = {
        "contents": [
            {
                "parts": [
                    {"text": PROMPT},
                    {
                        "inline_data": {
                            "mime_type": "image/jpeg",
                            "data": req.image_base64,
                        }
                    },
                ]
            }
        ],
        "generationConfig": {
            "temperature": 0.2
        },
    }

    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(
            f"{GEMINI_URL}?key={GEMINI_API_KEY}",
            json=payload,
        )

    if resp.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"Gemini API hatası: {resp.text[:200]}",
        )

    try:
        text = resp.json()["candidates"][0]["content"]["parts"][0]["text"]
        # Markdown kod bloğu varsa temizle
        text = text.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()
        data = json.loads(text)
        nutrients = data.get("nutrients", {})

        food_name = data.get("food_name", "Tanımlanamadı")
        portion = data.get("portion", "-")
        calories = int(nutrients.get("calories", 0))
        protein_g = float(nutrients.get("protein_g", 0.0))
        carbs_g = float(nutrients.get("carbs_g", 0.0))
        fat_g = float(nutrients.get("fat_g", 0.0))
        fiber_g = float(nutrients.get("fiber_g", 0.0))
        health_score = int(data.get("health_score", 0))
        recommendation = data.get("recommendation", "Analiz yapılamadı.")
        tags = data.get("tags", [])

        # DB'ye kaydet
        user = await crud.get_or_create_user(db, uid)
        await crud.save_meal_record(
            db, user,
            food_name=food_name,
            portion=portion,
            calories=calories,
            protein_g=protein_g,
            carbs_g=carbs_g,
            fat_g=fat_g,
            fiber_g=fiber_g,
            health_score=health_score,
            recommendation=recommendation,
            tags=tags,
        )

        return FoodAnalysisResponse(
            food_name=food_name,
            portion=portion,
            nutrients=NutrientInfo(
                calories=calories,
                protein_g=protein_g,
                carbs_g=carbs_g,
                fat_g=fat_g,
                fiber_g=fiber_g,
            ),
            health_score=health_score,
            recommendation=recommendation,
            tags=tags,
        )
    except Exception as e:
        logger.error(f"JSON Parse Error. Raw Text: {text}")
        raise HTTPException(status_code=500, detail=f"JSON parse hatası: {e}. Raw Text: {text[:150]}")


@router.get("/meal-history", response_model=list[MealHistoryItem])
async def meal_history(
    limit: int = 30,
    uid: str = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Kullanıcının yemek analiz geçmişini getirir."""
    user = await crud.get_or_create_user(db, uid)
    records = await crud.get_meal_history(db, user, limit)
    return [
        MealHistoryItem(
            id=r.id,
            food_name=r.food_name,
            portion=r.portion,
            calories=r.calories,
            protein_g=r.protein_g,
            carbs_g=r.carbs_g,
            fat_g=r.fat_g,
            fiber_g=r.fiber_g,
            health_score=r.health_score,
            recommendation=r.recommendation,
            tags=r.tags,
            analyzed_at=r.analyzed_at.isoformat(),
        )
        for r in records
    ]
