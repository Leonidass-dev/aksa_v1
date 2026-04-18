import os
from datetime import date
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
    "gemini-2.0-flash:generateContent"
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
    
    # M2 Pipeline'dan bugünün temizlenmiş özellik matrisini çek
    today_record = await crud.get_today_health(db, user)
    ml_features = today_record.ml_features if today_record and hasattr(today_record, 'ml_features') else None
    
    rag_context_texts = []

    # M2 verilerini RAG bağlamına ekle (varsa)
    if ml_features and len(ml_features) == 9:
        rag_context_texts.append(
            f"Kullanıcının M2 Pipeline Temiz Verileri — "
            f"Ort. Nabız: {ml_features[0]:.0f} bpm, "
            f"Min Nabız: {ml_features[2]:.0f} bpm, "
            f"Maks Nabız: {ml_features[3]:.0f} bpm, "
            f"Adım Yoğunluğu: {ml_features[5]:.0f}, "
            f"Aktif Süre: {ml_features[6]:.0f} dk"
        )

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
            "temperature": 0.2,
            "responseMimeType": "application/json"
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

# ── M5: DİYETİSYEN SİSTEMİ (ÖĞÜN PLANLAYICI) ──
from services.diet_generator import generate_diet_plan, DietPlanResponse

@router.get("/diet-plan", response_model=DietPlanResponse)
async def get_diet_plan(
    uid: str = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Kullanıcının risk haritası, M2 sensör verileri ve günlük kalori ihtiyacına
    göre yapay zeka destekli diyet listesi oluşturur. 
    Aynı gün içindeki isteklerde önbellekteki planı döner.
    """
    user = await crud.get_or_create_user(db, uid)
    today = date.today()

    # 0. Önbellek Kontrolü (Günde 1 kez oluşturma kuralı)
    cached_plan = await crud.get_daily_diet_plan(db, user, today)
    if cached_plan:
        return DietPlanResponse(**cached_plan.plan_data)
    
    # 1. Kullanıcı Profili ve Kalori Hedefi
    age = user.age if user.age else 30
    weight = user.weight if user.weight else 70.0
    height = user.height if user.height else 170.0
    gender = user.gender if user.gender else "Erkek"
    
    # Basit BMR hesabı
    if gender.lower() == "erkek":
        bmr = 88.362 + (13.397 * weight) + (4.799 * height) - (5.677 * age)
    else:
        bmr = 447.593 + (9.247 * weight) + (3.098 * height) - (4.330 * age)
    
    # 2. Risk Verileri
    risk_history = await crud.get_risk_history(db, user, limit=1)
    risk_level = "Medium"
    risk_factors = ""
    
    if risk_history and len(risk_history) > 0:
        latest = risk_history[0]
        risk_level = latest.level_label
        if latest.top_factors:
            risk_factors = ", ".join([f.get("name", "") if isinstance(f, dict) else getattr(f, "name", "") for f in latest.top_factors])

    # 3. M2 Sensör Verileri & Kalori Tahmini
    today_record = await crud.get_today_health(db, user)
    health_context = ""
    
    # Varsayılan: Sedanter (Hareketsiz) TDEE
    target_calories = int(bmr * 1.2)
    calc_method = "BMR * 1.2 (Default)"
    
    if today_record:
        raw_active = today_record.active_calories or 0
        
        if raw_active > 0:
            # KRİTİK KONTROL: Eğer gelen aktif kalori BMR'den büyükse, saat muhtemelen 
            # "Toplam Yakılan Kalori" (BMR + Aktif) gönderiyordur. Üstüne tekrar BMR ekleme.
            if raw_active > bmr:
                target_calories = int(raw_active)
                calc_method = f"Device Total Calories ({raw_active})"
            else:
                target_calories = int(bmr + raw_active)
                calc_method = f"BMR ({int(bmr)}) + Active ({raw_active})"
        else:
            calc_method = "BMR * 1.2 (No Active Data)"

        # M2 Meta verileri
        ml_features = today_record.ml_features if hasattr(today_record, 'ml_features') else None
        if ml_features and len(ml_features) == 9:
            health_context = (
                f"Nabız Ort: {ml_features[0]:.0f}, "
                f"Nabız Max: {ml_features[3]:.0f}, "
                f"Adım/Aktivite Skoru: {ml_features[5]:.0f}"
            )
        else:
            health_context = "Veri M2'den geçmemiş."

    # GÜVENLİK SINIRLARI: İnsan limitlerini zorlama.
    if target_calories < 1200:
        target_calories = 1200
        calc_method += " -> Capped at Min 1200"
    elif target_calories > 3500:
        target_calories = 3500
        calc_method += " -> Capped at Max 3500"

    logger.info(f"🎯 M5 Diyet Planlayıcı: Kullanıcı {user.firebase_uid} için hedef kalori: {target_calories} ({calc_method})")
            
    plan = await generate_diet_plan(
        age, gender, height, weight,
        risk_level, risk_factors, health_context,
        target_calories
    )
    
    if not plan:
        raise HTTPException(status_code=500, detail="Diyet planı üretilemedi.")
    
    # 4. Sonucu Önbelleğe Kaydet
    await crud.save_daily_diet_plan(db, user, today, plan.model_dump())
        
    return plan
