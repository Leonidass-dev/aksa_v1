import os
import httpx
import json
import logging
from typing import Optional
from models.exercise_model import ExercisePlanResponse, ExerciseItem, ExerciseRequest

logger = logging.getLogger(__name__)

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")

GEMINI_URL = (
    "https://generativelanguage.googleapis.com/v1/models/"
    "gemini-1.5-flash:generateContent"
)
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"

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
Bu verilere dayanarak kullanıcının risk seviyesine uygun SADECE BUGÜN YAPILMASI GEREKEN kişiselleştirilmiş bir GÜNLÜK EGZERSİZ PLANI üret. 

KRİTİK KURALLAR:
1. Sadece bugün için 1-3 egzersiz öner. 
2. ASLA "1. Gün", "2. Gün" veya "Pazartesi" gibi ifadeler kullanma.
3. Egzersiz başlıkları doğrudan egzersizin adı olmalı (Örn: "Düşük Tempolu Yürüyüş", "Güneşe Selam Serisi").
4. Liste formatında değil, sadece o an yapılacak tek bir idman seansı gibi düşün.

JSON FORMATI:
{{
  "exercises": [
    {{
      "title": "Doğrudan Egzersiz Adı",
      "duration_minutes": 20,
      "intensity": "Düşük/Orta/Yüksek",
      "calories": 100,
      "type": "Kardiyo/Yoga/Güç",
      "description": "Yapılış özeti"
    }}
  ],
  "total_duration_minutes": 20,
  "total_calories": 100,
  "ai_advice": "Neden bu egzersizi seçtiğine dair not..."
}}
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

    # Bugünün tarihini ve gününü al
    from datetime import datetime
    tr_days = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"]
    now = datetime.now()
    day_name = tr_days[now.weekday()]
    current_date_str = f"{now.strftime('%d.%m.%Y')} {day_name}"

    prompt = EXERCISE_PROMPT.format(
        age=req.age,
        gender=req.gender,
        height=req.height,
        weight=req.weight,
        class_id=class_id,
        risk_level=req.risk_level,
        health_context=health_context,
        current_date=current_date_str
    )

    # ── AI SEÇİMİ ──
    use_groq = bool(GROQ_API_KEY)
    
    if use_groq:
        url = GROQ_URL
        headers = {"Authorization": f"Bearer {GROQ_API_KEY}"}
        payload = {
            "model": "llama-3.3-70b-versatile",
            "messages": [
                {"role": "system", "content": "Sen uzman bir spor fizyoloğu ve diyetisyensin. Sadece JSON formatında yanıt ver. ASLA '1. Gün' gibi ifadeler kullanma."},
                {"role": "user", "content": prompt}
            ],
            "response_format": {"type": "json_object"},
            "temperature": 0.5
        }
    else:
        url = f"{GEMINI_URL}?key={GEMINI_API_KEY}"
        headers = {}
        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {
                "temperature": 0.7,
                "response_mime_type": "application/json"
            }
        }

    try:
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(url, json=payload, headers=headers)
            
        if resp.status_code != 200:
            logger.error(f"AI API hatası (Egzersiz): {resp.status_code} - {resp.text}")
            return None

        data = resp.json()
        if use_groq:
            raw_text = data["choices"][0]["message"]["content"]
        else:
            raw_text = data["candidates"][0]["content"]["parts"][0]["text"]
        
        # JSON temizleme
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
