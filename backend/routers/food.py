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
    "gemini-2.5-flash:generateContent"
)

# ── RAG BİLGİ TABANI (KNOWLEDGE BASE) ──
NUTRITION_KNOWLEDGE_BASE = {
    "Tansiyon": "Hipertansiyon riskiniz varsa sodyum tüketimini günlük 1500mg ile sınırlandırın. Sebze ve meyvelerdeki potasyum kan basıncını dengelemeye yardımcı olur.",
    "Nabız": "Taşikardi veya yüksek nabız eğilimi olan durumlarda kafein ve eklenti şeker tüketimi kısıtlanmalıdır. Bol su içmek kalp sağlığı için elzemdir.",
    "Hareketsizlik": "Hareketsiz yaşam (düşük adım) dönemlerinde porsiyon kontrolü sağlamak ve kompleks karbonhidrat (lifli) ağırlıklı beslenmek kilo alımını önler.",
    "Uyku": "Yetersiz uyku leptin hormonunu baskılayıp kalori iştahını artırabilir. Gece geç saatte sindirimi zor (yağlı, baharatlı) yiyeceklerden kaçının.",
    "Oksijen": "Solunum/SpO2 desteklemek için antioksidan (C vitamini) açısından zengin narenciye, biber, ve ıspanak tüketimi faydalı olabilir.",
    "Stres": "Stres (yüksek kortizol) dönemlerinde B vitamini açısından zengin tam tahıllar, magnezyumlu badem ve muz sinir sistemini yatıştırmaya destek olur."
}


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
Bu yemek fotoğrafını analiz et.

ÖNEMLİ KURALLAR:
1. Fotoğraftaki GERÇEK porsiyon boyutunu dikkatlice tahmin et (tabak boyutu, kaşık referansı vb. kullan).
2. Kalori ve makro değerlerini SADECE görünen porsiyon miktarına göre hesapla. Abartma yapma.
3. Porsiyon tahmini yaparken Türk mutfağı standart porsiyon boyutlarını referans al.
4. Örnek: Bir kase çorba ~250ml = ~80-120 kcal, bir dilim ekmek = ~70-80 kcal, bir porsiyon pilav (150g) = ~180 kcal
5. Eğer yemek tanınamıyorsa food_name = "Tanımlanamadı" yaz ve tüm sayısal değerleri 0 döndür.

Yanıtta SADECE aşağıdaki JSON formatı olsun, başka hiçbir metin ekleme:

{
  "food_name": "yemeğin Türkçe adı",
  "portion": "tahmini porsiyon miktarı (örn: 1 kase ~250ml, 1 tabak ~200g)",
  "nutrients": {
    "calories": 280,
    "protein_g": 15.0,
    "carbs_g": 30.0,
    "fat_g": 8.0,
    "fiber_g": 3.0
  },
  "health_score": 75,
  "recommendation": "kısa, kişiselleştirilmiş öneri (1-2 cümle)",
  "tags": ["dengeli", "ev yapımı"]
}

health_score: 0 (çok sağlıksız) - 100 (çok sağlıklı)
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

    user = await crud.get_or_create_user(db, uid)
    
    # ── RAG: İstirdat (Retrieval) Mekanizması ──
    # Kullanıcının en güncel sağlık risk geçmişi çekilir.
    risk_history = await crud.get_risk_history(db, user, limit=1)
    
    rag_context_texts = []
    if risk_history and len(risk_history) > 0:
        latest_risk = risk_history[0]
        rag_context_texts.append(f"Kullanıcının Genel Sağlık Risk Seviyesi: {latest_risk.level_label}")
        
        # Risk faktörlerini (Tansiyon, Uyku vb) çıkarıp ilgili rehber (Knowledge Base) metnini geri getir.
        factors = latest_risk.top_factors or []
        for f in factors:
            factor_name = f.get("name", "") if isinstance(f, dict) else getattr(f, "name", "")
            
            for kb_key, kb_text in NUTRITION_KNOWLEDGE_BASE.items():
                if kb_key.lower() in factor_name.lower():
                    rag_context_texts.append(f"- TÜBER REHBER NOTU ({kb_key}): {kb_text}")
    
    if not rag_context_texts:
        rag_context = "RAG Bağlamı Yok: Kullanıcı hakkında spesifik bir risk verisi bulunamadı. Standart yetişkin sağlıklı beslenme ilkelerini uygula."
    else:
        rag_context = "RAG (Kullanıcının Sağlık Durumu ve Getirilen Beslenme Rehberi):\\n" + "\\n".join(rag_context_texts)

    augmented_prompt = f"{PROMPT}\\n\\n[SİSTEM ÖZEL BİLGİSİ / RAG BAĞLAMI]\\nAşağıdaki tıbbi/bağlamsal bilgiye dayanarak 'recommendation' (öneri) kısmını bu kullanıcıya göre hiper-kişiselleştir:\\n{rag_context}"

    payload = {
        "contents": [
            {
                "parts": [
                    {"text": augmented_prompt},
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

    import asyncio
    max_retries = 3
    
    for attempt in range(max_retries):
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(
                f"{GEMINI_URL}?key={GEMINI_API_KEY}",
                json=payload,
            )
        
        if resp.status_code == 200:
            break
            
        if resp.status_code == 503 and attempt < max_retries - 1:
            await asyncio.sleep(2)  # 2 saniye bekle ve tekrar dene
            continue
            
    if resp.status_code != 200:
        error_msg = "Bilinmeyen API hatası"
        try:
            data = resp.json()
            error_msg = data.get("error", {}).get("message", resp.text[:200])
        except Exception:
            error_msg = resp.text[:200]
            
        logger.error(f"Gemini API Error [{resp.status_code}]: {error_msg}")
        
        if resp.status_code == 503:
            detail = "Google sunucularında aşırı yoğunluk var. Lütfen biraz bekleyip tekrar deneyin."
        elif resp.status_code == 429:
            detail = "API kullanım limitinize ulaştınız. (Kota aşıldı veya çok sık istek atıldı)."
        elif resp.status_code in [401, 403]:
            detail = "Gemini API Anahtarı (API_KEY) yetkisiz veya hatalı."
        elif resp.status_code == 404:
            detail = "Kullanılan yapay zeka modeli bulunamadı."
        elif resp.status_code == 400:
            detail = f"Geçersiz istek gönderildi. Detay: {error_msg}"
        else:
            detail = f"Gemini API Sunucu Hatası ({resp.status_code}): {error_msg}"
            
        raise HTTPException(status_code=502, detail=detail)

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
