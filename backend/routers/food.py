import os
import base64
import json
import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from dotenv import load_dotenv
import logging

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
async def analyze_food(req: FoodAnalysisRequest):
    """
    M5 — Yemek Fotoğrafı Analizi (Gemini Vision)
    Base64 JPEG/PNG alır, kalori + makro + öneri döner.
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
        
        return FoodAnalysisResponse(
                food_name=data.get("food_name", "Tanımlanamadı"),
                portion=data.get("portion", "-"),
                nutrients=NutrientInfo(
                    calories=int(nutrients.get("calories", 0)),
                    protein_g=float(nutrients.get("protein_g", 0.0)),
                    carbs_g=float(nutrients.get("carbs_g", 0.0)),
                    fat_g=float(nutrients.get("fat_g", 0.0)),
                    fiber_g=float(nutrients.get("fiber_g", 0.0))
                ),
                health_score=int(data.get("health_score", 0)),
                recommendation=data.get("recommendation", "Analiz yapılamadı."),
                tags=data.get("tags", [])
        )
    except Exception as e:
        logger.error(f"JSON Parse Error. Raw Text: {text}")
        raise HTTPException(status_code=500, detail=f"JSON parse hatası: {e}. Raw Text: {text[:150]}")
