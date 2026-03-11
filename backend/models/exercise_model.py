import os
import json
import logging
from pydantic import BaseModel, Field
from typing import List, Optional
import httpx
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

# Modeller
class ExerciseRequest(BaseModel):
    age: int
    weight: float
    height: float
    gender: str
    risk_level: str  # 'low', 'medium', 'high'
    systolic_bp: Optional[float] = None
    diastolic_bp: Optional[float] = None
    heart_rate: Optional[float] = None
    
class ExerciseItem(BaseModel):
    title: str = Field(description="Egzersizin adı (örn: Hafif Tempo Yürüyüş)")
    duration_minutes: int = Field(description="Süre (dakika)")
    intensity: str = Field(description="Zorluk seviyesi: Düşük, Orta, Yüksek")
    calories: int = Field(description="Tahmini yakılan kalori")
    type: str = Field(description="Egzersiz türü (Kardiyo, Güç, Esneklik, Yoga vb.)")
    description: str = Field(description="Nasıl yapılacağına dair kısa açıklama")

class ExercisePlanResponse(BaseModel):
    exercises: List[ExerciseItem]
    total_duration_minutes: int
    total_calories: int
    ai_advice: str = Field(description="Kullanıcıya özel genel tavsiye ve dikkat etmesi gerekenler")

# Gemini prompt
async def generate_exercise_plan(req: ExerciseRequest) -> ExercisePlanResponse:
    gemini_key = os.getenv("GEMINI_API_KEY", "")
    gemini_url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent"
    
    # Güvenlik kuralları (Prompt mühendisliği)
    health_context = f"Kullanıcı {req.age} yaşında, {req.gender} cinsiyetinde, {req.weight}kg, {req.height}cm."
    if req.systolic_bp and req.diastolic_bp:
        health_context += f" Tansiyon: {req.systolic_bp}/{req.diastolic_bp}."
    if req.heart_rate:
        health_context += f" Nabız: {req.heart_rate} bpm."
        
    health_context += f" Mevcut Sağlık Risk Seviyesi: {req.risk_level.upper()}."

    if req.risk_level == "high":
        safety_rule = "Kritik: Risk seviyesi YÜKSEK. Sadece çok hafif, nabzı zorlamayacak esneme, nefes egzersizleri veya yavaş yürüyüş önerin. Ağırlık veya yüksek HIIT KESİNLİKLE YASAK."
    elif req.risk_level == "medium":
        safety_rule = "Önemli: Risk seviyesi ORTA. Orta tempo yürüyüş, hafif yoga, ısınma hareketleri önerin. Aşırı yorucu aktivitelerden kaçının."
    else:
        safety_rule = "Risk seviyesi DÜŞÜK. Genel fitness için kardiyo, güç ve esneklik dengeli bir günlük program hazırlayın."

    prompt = f"""
Sen uzman bir fizyoterapist ve kişisel antrenörsün.
Aşağıdaki kullanıcı profiline uygun, GÜNLÜK bir egzersiz rutini (genellikle 3-5 hareket/aktivite) hazırla.

Kullanıcı Profili:
{health_context}

Güvenlik Kuralı:
{safety_rule}

Lütfen JSON formatında dön. JSON şablonu:
{{
  "exercises": [
    {{
      "title": "...",
      "duration_minutes": 20,
      "intensity": "Düşük",
      "calories": 100,
      "type": "Kardiyo",
      "description": "..."
    }}
  ],
  "total_duration_minutes": 45,
  "total_calories": 250,
  "ai_advice": "Tansiyonunuz yüksek olduğu için egzersiz sırasında baş dönmesi hissederseniz hemen bırakın."
}}
"""

    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 0.2}
    }

    try:
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(f"{gemini_url}?key={gemini_key}", json=payload)
            
        if resp.status_code != 200:
            logger.error(f"Gemini API Error: {resp.text}")
            raise Exception("Gemini HTTP Error")

        text = resp.json()["candidates"][0]["content"]["parts"][0]["text"]
        # Markdown backtick'leri temizle
        text = text.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()
            
        data = json.loads(text)
        
        exercises = []
        for e in data.get("exercises", []):
            exercises.append(ExerciseItem(
                title=e.get("title", ""),
                duration_minutes=e.get("duration_minutes", 0),
                intensity=e.get("intensity", "Düşük"),
                calories=e.get("calories", 0),
                type=e.get("type", "Genel"),
                description=e.get("description", "")
            ))
            
        return ExercisePlanResponse(
            exercises=exercises,
            total_duration_minutes=data.get("total_duration_minutes", 0),
            total_calories=data.get("total_calories", 0),
            ai_advice=data.get("ai_advice", "Lütfen egzersize başlamadan önce doktorunuza danışın.")
        )

    except Exception as e:
        logger.error(f"Egzersiz planı oluşturulamadı: {e}")
        # Fallback plan
        return ExercisePlanResponse(
            exercises=[
                ExerciseItem(
                    title="Hafif Tempolu Yürüyüş",
                    duration_minutes=20,
                    intensity="Düşük",
                    calories=80,
                    type="Kardiyo",
                    description="Düz zeminde, nefes nefese kalmayacak tempoda yürüyüş."
                )
            ],
            total_duration_minutes=20,
            total_calories=80,
            ai_advice="Sistem geçici olarak yanıt veremiyor, bu standart hafif aktiviteyi uygulayabilirsiniz."
        )
