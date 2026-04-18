import os
import httpx
import json
import logging
from typing import Optional
from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
GEMINI_URL = (
    "https://generativelanguage.googleapis.com/v1beta/models/"
    "gemini-2.5-flash:generateContent"
)

# ── Pydantic Modelleri ──
class DietMeal(BaseModel):
    meal_type: str = Field(description="Öğün Türü (Sabah, Öğle, Akşam, Ara Öğün)")
    food_name: str = Field(description="Yemeklerin adı")
    portion: str = Field(description="Porsiyon büyüklüğü")
    calories: int = Field(description="Tahmini kalori")
    reasoning: str = Field(description="Neden bu öğün seçildi? (Risk faktörlerine göre açıklama)")

class DietPlanResponse(BaseModel):
    daily_calories_target: int
    meals: list[DietMeal]
    ai_advice: str = Field(description="Kullanıcının risk haritasına göre diyetisyen tavsiyesi.")

DIET_PROMPT = """
Sen uzman bir klinik diyetisyen ve yapay zeka sağlık asistanısın.
Görecin: Kullanıcının fiziksel verileri, tıbbi riskleri ve günlük aktivitesine uygun {target_calories} kalorilik kişiselleştirilmiş bir tam gün (3 ana + 1 ara öğün) beslenme listesi oluşturmak.

GİRDİ VERİLERİ:
- Kullanıcı: {age} yaş, {gender}, {height}cm, {weight}kg
- Tıbbi Risk Seviyesi: {risk_level}
- Aktif Risk Problemleri: {risk_factors}
- M2 Sensör Sağlık Özeti: {health_context}

KURALLAR:
1. Eğer kullanıcının Tansiyon / Hipertansiyon riski varsa, Sodyum(tuz) uyarısı yap ve potasyum içeren yiyeceklere öncelik ver.
2. Eğer kullanıcının Kalp/Taşikardi riski varsa (Yüksek Nabız), kafeinsiz ve şekersiz, hafif öğünler öner.
3. Eğer kullanıcı hareketsizse (Düşük Adım), kaloriyi düşür ve lifli besinler öner.
4. Verdiğin liste Türk mutfağı damak tadına ve standart diyetisyen listelerine (örn: Yulaf, haşlanmış yumurta, ızgara tavuk salata, sebze yemeği) uygun olsun.
5. {target_calories} hedefine ortalama +-%10 sapma ile yaklaş.

Planı SADECE aşağıdaki JSON formatında döndür. Başka hiçbir metin ekleme.

JSON FORMATI:
{{
  "daily_calories_target": 1800,
  "meals": [
    {{
      "meal_type": "Sabah",
      "food_name": "Haşlanmış Yumurta ve Zeytinli Peynir Tabağı",
      "portion": "1 tam yumurta, 30g az yağlı peynir, 5 zeytin, 1 dilim tam buğday ekmeği",
      "calories": 300,
      "reasoning": "Tansiyon riskinize karşı az tuzlu peynir seçildi, güne tok başlamanız amaçkandı."
    }}
  ],
  "ai_advice": "Bugün 14:00'ten sonra adım sayınız azaldığı için akşam yemeğini hafif tuttuk. Bol su içmeyi unutmayın."
}}
"""

async def generate_diet_plan(
    age: int, gender: str, height: float, weight: float,
    risk_level: str, risk_factors: str, health_context: str,
    target_calories: int
) -> Optional[DietPlanResponse]:
    """Gemini AI kullanarak kişiselleştirilmiş 1 günlük diyet listesi üretir."""
    if not GEMINI_API_KEY:
        logger.warning("GEMINI_API_KEY bulunamadı, diyet planı iptal.")
        return None

    prompt = DIET_PROMPT.format(
        age=age, gender=gender, height=height, weight=weight,
        risk_level=risk_level, risk_factors=risk_factors,
        health_context=health_context, target_calories=target_calories
    )

    payload = {
        "contents": [
            {
                "parts": [{"text": prompt}]
            }
        ],
        "generationConfig": {
            "temperature": 0.3,
            "responseMimeType": "application/json"
        }
    }

    try:
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(
                f"{GEMINI_URL}?key={GEMINI_API_KEY}",
                json=payload
            )
            
        if resp.status_code != 200:
            logger.error(f"Gemini API hatası (Diyet): {resp.status_code} - {resp.text}")
            return None

        data = resp.json()
        raw_text = data["candidates"][0]["content"]["parts"][0]["text"]
        
        # JSON temizleme
        cleaned_json = raw_text.strip()
        if cleaned_json.startswith("```json"):
            cleaned_json = cleaned_json[7:-3].strip()
        elif cleaned_json.startswith("```"):
            cleaned_json = cleaned_json[3:-3].strip()
            
        json_data = json.loads(cleaned_json)
        return DietPlanResponse(**json_data)

    except Exception as e:
        logger.error(f"Diyet planı üretilirken hata oluştu: {e}")
        return None
