import os
import httpx
import json
import logging
from typing import Optional
from models.exercise_model import ExercisePlanResponse, ExerciseItem, ExerciseRequest

logger = logging.getLogger(__name__)

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
GEMINI_URL = (
    "https://generativelanguage.googleapis.com/v1/models/"
    "gemini-1.5-flash:generateContent"
)

EXERCISE_PROMPT = """
Sen uzman bir spor fizyoloğu ve sağlık koçusun. 
Kullanıcının sağlık verilerine ve tıbbi risk seviyesine göre ona özel bir egzersiz planı oluşturmalısın.

GÜVENLİK SINIRI (ÇOK ÖNEMLİ):
Kullanıcının belirlenen YOĞUNLUK KATEGORİSİ dışına asla çıkma.
- Kategori 0: Sadece düşük tempolu yürüyüş ve hafif esneme. (Yüksek Risk)
- Kategori 1: Yoga, nefes egzersizleri ve hafif esneme. (Orta Risk - Yaşlı)
- Kategori 2: Hafif tempo koşu, ısınma/soğuma odaklı kardiyo. (Orta/Düşük Risk)
- Kategori 3: Bisiklet, yüzme veya direnç bandı egzersizleri. (Dinamik/Düşük Risk)
- Kategori 4: HIIT, ağırlık antrenmanı, fonksiyonel antrenman. (Sağlıklı/Genç/Düşük Risk)

GİRDİ VERİLERİ:
- Kullanıcı: {age} yaş, {gender}, {height}cm, {weight}kg
- Belirlenen Yoğunluk Kategorisi: {class_id}
- Tıbbi Risk Seviyesi: {risk_level}
- Son Sağlık Verileri: {health_context}

GÖREVİN:
Bu verilere dayanarak kullanıcının risk seviyesine uygun 3 ila 5 günlük bir HAFTALIK EGZERSİZ DÖNGÜSÜ (Weekly Plan) üret.
Planı MUTLAKA aşağıdaki JSON formatında döndür. Egzersiz isimlerinin başına gün bilgisini ekle (Örn: "1. Gün: Tempolu Yürüyüş").

JSON FORMATI ÖRNEĞİ:
{{
  "exercises": [
    {{
      "title": "Egzersiz Adı",
      "duration_minutes": 20,
      "intensity": "Düşük/Orta/Yüksek",
      "calories": 100,
      "type": "Kardiyo/Yoga/Güç",
      "description": "Yapılış özeti"
    }}
  ],
  "total_duration_minutes": 150,
  "total_calories": 800,
  "ai_advice": "Haftalık hedefleriniz: İlk 3 gün kardiyo, sonraki günler aktif dinlenme. Unutmayın..."
}}

Sadece JSON çıktısı ver, başka açıklama ekleme.
"""

async def generate_dynamic_plan(
    req: ExerciseRequest, 
    class_id: int, 
    health_context: str
) -> Optional[ExercisePlanResponse]:
    """Gemini AI kullanarak dinamik ve kişiselleştirilmiş egzersiz planı üretir."""
    if not GEMINI_API_KEY:
        logger.warning("GEMINI_API_KEY bulunamadı, dinamik plan iptal.")
        return None

    prompt = EXERCISE_PROMPT.format(
        age=req.age,
        gender=req.gender,
        height=req.height,
        weight=req.weight,
        class_id=class_id,
        risk_level=req.risk_level,
        health_context=health_context
    )

    payload = {
        "contents": [
            {
                "parts": [{"text": prompt}]
            }
        ],
        "generationConfig": {
            "temperature": 0.7,
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
            logger.error(f"Gemini API hatası (Egzersiz): {resp.status_code} - {resp.text}")
            return None

        data = resp.json()
        raw_text = data["candidates"][0]["content"]["parts"][0]["text"]
        
        # JSON temizleme (Bazen Gemini ```json ... ``` bloğu içinde dönebiliyor)
        cleaned_json = raw_text.strip()
        if cleaned_json.startswith("```json"):
            cleaned_json = cleaned_json[7:-3].strip()
        elif cleaned_json.startswith("```"):
            cleaned_json = cleaned_json[3:-3].strip()
            
        json_data = json.loads(cleaned_json)
        return ExercisePlanResponse(**json_data)

    except Exception as e:
        logger.error(f"Dinamik egzersiz planı üretilirken hata oluştu: {e}")
        return None
