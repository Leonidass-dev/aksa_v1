from datetime import date
import json
import logging
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from auth import get_current_user
import crud
from services.ai_service import ask_vision

logger = logging.getLogger(__name__)

router = APIRouter()


# ── RAG BİLGİ TABANI (KNOWLEDGE BASE) ──
NUTRITION_KNOWLEDGE_BASE = {
    "Tansiyon": "Hipertansiyon riskiniz varsa sodyum tüketimini günlük 1500mg ile sınırlandırın. Sebze ve meyvelerdeki potasyum kan basıncını dengelemeye yardımcı olur.",
    "Nabız": "Taşikardi veya yüksek nabız eğilimi olan durumlarda kafein ve eklenti şeker tüketimi kısıtlanmalıdır. Bol su içmek kalp sağlığı için elzemdir.",
    "Adım": "Hareketsiz yaşam (düşük adım) dönemlerinde porsiyon kontrolü sağlamak ve kompleks karbonhidrat (lifli) ağırlıklı beslenmek kilo alımını önler.",
    "Aktif": "Hareketsizlik nedeniyle porsiyon kontrolü sağlamak önemlidir.",
    "Uyku": "Yetersiz uyku leptin hormonunu baskılayıp kalori iştahını artırabilir. Gece geç saatte sindirimi zor (yağlı, baharatlı) yiyeceklerden kaçının.",
    "Oksijen": "Solunum/SpO2 desteklemek için antioksidan (C vitamini) açısından zengin narenciye, biber, ve ıspanak tüketimi faydalı olabilir.",
    "Stres": "Stres (yüksek kortizol) dönemlerinde B vitamini açısından zengin tam tahıllar, magnezyumlu badem ve muz sinir sistemini yatıştırmaya destek olur.",
}


class FoodAnalysisRequest(BaseModel):
    image_base64: str  # base64 encoded JPEG/PNG
    grammage_hint: str | None = None  # Kullanıcının manuel girdiği gramaj bilgisi


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
    health_score: int  # 0-100
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
Sen dünyanın en iyi görsel beslenme uzmanısın. Fotoğraftaki tabağı analiz et ve GERÇEK verilerle bir JSON raporu hazırla.

TALİMATLAR:
1. GÖRSEL ANALİZ: Fotoğrafta ne görüyorsan (örn: fasulye, pilav, salata, yoğurt, hamburger, pizza vb.) tam ismini yaz.
2. PORSİYON: Eğer sana ekstra bir gramaj bilgisi (grammage_hint) verildiyse mutlaka o değeri baz alarak porsiyon hesapla. Verilmediyse, gördüğün porsiyonun yaklaşık gramajını tahmin et.
3. HESAPLAMA: Toplam kalori ve makroları (protein, karbonhidrat, yağ, lif) belirlediğin bu gramaja/porsiyona göre hesapla. 
4. BOŞ BIRAKMA: JSON içindeki tırnak içlerini ve rakamları sakın benim verdiğim gibi bırakma; mutlaka senin bulduğun gerçek sonuçlarla doldur.

ÇIKTI FORMATI (SADECE JSON):
{
  "food_name": "",
  "portion": "",
  "nutrients": {
    "calories": 0,
    "protein_g": 0.0,
    "carbs_g": 0.0,
    "fat_g": 0.0,
    "fiber_g": 0.0
  },
  "health_score": 0,
  "recommendation": "",
  "tags": []
}
"""


@router.post("/analyze-food", response_model=FoodAnalysisResponse)
async def analyze_food(
    req: FoodAnalysisRequest,
    uid: str = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    M5 — Yemek Fotoğrafı Analizi.
    """
    user = await crud.get_or_create_user(db, uid)

    # ── RAG: İstirdat (Retrieval) Mekanizması ──
    # Kullanıcının en güncel sağlık risk geçmişi çekilir.
    risk_history = await crud.get_risk_history(db, user, limit=1)

    # M2 Pipeline'dan bugünün temizlenmiş özellik matrisini çek
    today_record = await crud.get_today_health(db, user)
    ml_features = (
        today_record.ml_features
        if today_record and hasattr(today_record, "ml_features")
        else None
    )

    rag_context_texts = []

    # M2 verilerini RAG bağlamına ekle (varsa)
    # ml_features formatı: [[9], [9], ...] (matris) veya [9] (eski flat format)
    ml_vector = None
    if ml_features:
        if isinstance(ml_features, list) and len(ml_features) > 0:
            if isinstance(ml_features[0], list):
                # Matris formatı — son pencereyi al
                ml_vector = ml_features[-1]
            elif len(ml_features) == 9:
                # Eski flat format
                ml_vector = ml_features

    if ml_vector and len(ml_vector) == 9:
        rag_context_texts.append(
            f"Kullanıcının M2 Pipeline Temiz Verileri — "
            f"Ort. Nabız: {ml_vector[0]:.0f} bpm, "
            f"Min Nabız: {ml_vector[2]:.0f} bpm, "
            f"Maks Nabız: {ml_vector[3]:.0f} bpm, "
            f"Adım Yoğunluğu: {ml_vector[5]:.0f}, "
            f"Aktif Süre: {ml_vector[6]:.0f} dk"
        )

    if risk_history and len(risk_history) > 0:
        latest_risk = risk_history[0]
        rag_context_texts.append(
            f"Kullanıcının Genel Sağlık Risk Seviyesi: {latest_risk.level_label}"
        )

        # Risk faktörlerini (Tansiyon, Uyku vb) çıkarıp ilgili rehber (Knowledge Base) metnini geri getir.
        factors = latest_risk.top_factors or []
        for f in factors:
            factor_name = (
                f.get("name", "") if isinstance(f, dict) else getattr(f, "name", "")
            )

            for kb_key, kb_text in NUTRITION_KNOWLEDGE_BASE.items():
                if kb_key.lower() in factor_name.lower():
                    rag_context_texts.append(
                        f"- TÜBER REHBER NOTU ({kb_key}): {kb_text}"
                    )

    if not rag_context_texts:
        rag_context = "RAG Bağlamı Yok: Kullanıcı hakkında spesifik bir risk verisi bulunamadı. Standart yetişkin sağlıklı beslenme ilkelerini uygula."
    else:
        rag_context = (
            "RAG (Kullanıcının Sağlık Durumu ve Getirilen Beslenme Rehberi):\n"
            + "\n".join(rag_context_texts)
        )

    augmented_prompt = f"{PROMPT}\n\n[SİSTEM ÖZEL BİLGİSİ / RAG BAĞLAMI]\nAşağıdaki tıbbi/bağlamsal bilgiye dayanarak 'recommendation' (öneri) kısmını bu kullanıcıya göre hiper-kişiselleştir:\n{rag_context}"
    
    if req.grammage_hint:
        augmented_prompt += f"\n\n[KULLANICI BİLGİSİ]: Kullanıcı gramajın yaklaşık olarak {req.grammage_hint} olduğunu belirtti. Analizinde porsiyon gramajını kesinlikle buna göre yap."

    # AI Çağrısı (Merkezi Servis Üzerinden)
    try:
        text = await ask_vision(
            prompt=augmented_prompt, image_base64=req.image_base64, json_mode=True
        )
    except Exception as e:
        logger.error(f"Yemek analizi sırasında kritik hata: {e}")
        text = None

    if not text:
        return FoodAnalysisResponse(
            food_name="Tanımlanamadı",
            portion="Bilinmiyor",
            nutrients=NutrientInfo(
                calories=0,
                protein_g=0,
                carbs_g=0,
                fat_g=0,
                fiber_g=0,
            ),
            health_score=0,
            recommendation="Yemek analizi şu an yapılamıyor. Lütfen internet bağlantınızı kontrol edin veya biraz sonra tekrar deneyin.",
            tags=["hata"],
        )

    try:
        from services.ai_service import clean_json_string

        text = clean_json_string(text)
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
            db,
            user,
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
        logger.exception(f"JSON Parse Error. Raw Text: {text}")
        raise HTTPException(
            status_code=500, detail=f"JSON parse hatası: {e}. Raw Text: {text[:150]}"
        )


@router.get("/meal-history", response_model=list[MealHistoryItem])
async def meal_history(
    limit: int = 30,
    offset: int = 0,
    uid: str = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Kullanıcının yemek analiz geçmişini getirir."""
    user = await crud.get_or_create_user(db, uid)
    records = await crud.get_meal_history(db, user, limit, offset)
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
from services.diet_generator import generate_diet_plan, DietPlanResponse  # noqa: E402


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

    # 1. Kullanıcı Profili ve Kalori Hedefi
    age = user.age if user.age else 30
    weight = user.weight if user.weight else 70.0
    height = user.height if user.height else 170.0
    gender = user.gender if user.gender else "Erkek"
    allergies = user.allergies if user.allergies else []
    diet_preference = user.diet_preference if user.diet_preference else "Standart"

    # Mifflin-St Jeor BMR Formülü (Modern Standart - Mobil Uygulama ile Senkronize)
    if gender.lower() in ["erkek", "m"]:
        bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5
    else:
        bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161

    # 2. Risk Verileri
    risk_history = await crud.get_risk_history(db, user, limit=1)
    risk_level = "Medium"
    risk_factors = ""

    if risk_history and len(risk_history) > 0:
        latest = risk_history[0]
        risk_level = latest.level_label
        if latest.top_factors:
            risk_factors = ", ".join(
                [
                    f.get("name", "") if isinstance(f, dict) else getattr(f, "name", "")
                    for f in latest.top_factors
                ]
            )

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
        ml_features = (
            today_record.ml_features if hasattr(today_record, "ml_features") else None
        )
        ml_vec = None
        if ml_features and isinstance(ml_features, list) and len(ml_features) > 0:
            if isinstance(ml_features[0], list):
                ml_vec = ml_features[-1]
            elif len(ml_features) == 9:
                ml_vec = ml_features

        if ml_vec and len(ml_vec) == 9:
            health_context = (
                f"Nabız Ort: {ml_vec[0]:.0f}, "
                f"Nabız Max: {ml_vec[3]:.0f}, "
                f"Adım/Aktivite Skoru: {ml_vec[5]:.0f}"
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

    # 0. Önbellek Kontrolü (Kalori hedefine göre dinamik geçersiz kılma)
    cached_plan = await crud.get_daily_diet_plan(db, user, today)
    if cached_plan:
        cached_target = cached_plan.plan_data.get("daily_calories_target", 0)
        # Eğer kalori hedefi ±300 kcal'den fazla değişmediyse önbelleği kullan
        if abs(cached_target - target_calories) < 300:
            logger.info(
                f"🎯 M5 Diyet Planlayıcı: Önbellekten dönüyor. Hedef kalori: {target_calories}"
            )
            return DietPlanResponse(**cached_plan.plan_data)
        else:
            logger.info(
                f"🎯 M5 Diyet Planlayıcı: Kalori hedefi değişti ({cached_target} -> {target_calories}). Plan yeniden oluşturuluyor."
            )

    logger.info(
        f"🎯 M5 Diyet Planlayıcı: Kullanıcı {user.firebase_uid} için hedef kalori: {target_calories} ({calc_method})"
    )

    plan = await generate_diet_plan(
        age,
        gender,
        height,
        weight,
        risk_level,
        risk_factors,
        health_context,
        target_calories,
        allergies,
        diet_preference,
    )

    if not plan:
        raise HTTPException(status_code=500, detail="Diyet planı üretilemedi.")

    # 4. Sonucu Önbelleğe Kaydet
    await crud.save_daily_diet_plan(db, user, today, plan.model_dump())

    return plan


class ManualFoodRequest(BaseModel):
    food_name: str
    portion: str


@router.post("/manual", response_model=FoodAnalysisResponse)
async def add_manual_food(
    req: ManualFoodRequest,
    uid: str = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Kullanıcının kamerasız, manuel olarak yediği yemeği kaydetmesi ve AI'ın makro tahmini yapması."""
    user = await crud.get_or_create_user(db, uid)

    # 1. AI ile Makro Tahmini (Hızlı ve API Dostu: Sadece Groq Kullan)
    from services.ai_service import _call_groq, clean_json_string
    import json

    estimated_calories = 300  # Varsayılan fallback
    protein_g, carbs_g, fat_g, fiber_g = 0.0, 0.0, 0.0, 0.0
    health_score = 50
    recommendation = "Makrolar yapay zeka tarafından tahmin edildi."
    tags = ["manuel_giris", "ai_kalori"]

    try:
        prompt = f"Yemek: {req.food_name}\nPorsiyon: {req.portion}"
        system = """Sen uzman bir diyetisyensin. Verilen yemeğin besin değerlerini tahmin et ve SADECE aşağıdaki JSON formatında dön:
{
  "food_name": "Yemeğin adı",
  "portion": "Net gramaj",
  "nutrients": {
    "calories": 0,
    "protein_g": 0.0,
    "carbs_g": 0.0,
    "fat_g": 0.0,
    "fiber_g": 0.0
  },
  "health_score": 50,
  "recommendation": "Beslenme tavsiyesi",
  "tags": ["etiket1", "etiket2"]
}"""

        ai_res = await _call_groq(prompt, system, history=[], json_mode=True)
        if ai_res:
            data = json.loads(clean_json_string(ai_res))
            nutrients = data.get("nutrients", {})
            estimated_calories = int(nutrients.get("calories", estimated_calories))
            protein_g = float(nutrients.get("protein_g", 0.0))
            carbs_g = float(nutrients.get("carbs_g", 0.0))
            fat_g = float(nutrients.get("fat_g", 0.0))
            fiber_g = float(nutrients.get("fiber_g", 0.0))
            health_score = int(data.get("health_score", 50))
            recommendation = data.get("recommendation", recommendation)
            tags = data.get("tags", tags)

            logger.info(
                f"💡 Manuel Yemek Groq Tahmini: {estimated_calories} kcal, P: {protein_g}g ({req.food_name})"
            )
    except Exception as e:
        logger.error(f"Manuel yemek Groq tahmini hatası: {e}")

    # 2. Veritabanına Kaydet
    await crud.save_meal_record(
        db=db,
        user=user,
        food_name=req.food_name,
        portion=req.portion,
        calories=estimated_calories,
        protein_g=protein_g,
        carbs_g=carbs_g,
        fat_g=fat_g,
        fiber_g=fiber_g,
        health_score=health_score,
        recommendation=recommendation,
        tags=tags,
    )

    return FoodAnalysisResponse(
        food_name=req.food_name,
        portion=req.portion,
        nutrients=NutrientInfo(
            calories=estimated_calories,
            protein_g=protein_g,
            carbs_g=carbs_g,
            fat_g=fat_g,
            fiber_g=fiber_g,
        ),
        health_score=health_score,
        recommendation=recommendation,
        tags=tags,
    )
