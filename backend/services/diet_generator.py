import json
import logging
from typing import Optional
from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)

from services.ai_service import ask_text


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
Sen uzman bir klinik diyetisyen ve beslenme bilimcisisin. Görevin, aşağıdaki verilere dayanarak kullanıcıya hiper-kişiselleştirilmiş, bilimsel temelli bir günlük beslenme planı hazırlamak.

GİRDİ PARAMETRELERİ:
- Profil: {age} yaş, {gender}, {height}cm, {weight}kg
- Klinik Risk Seviyesi: {risk_level}
- Tanımlanmış Risk Faktörleri: {risk_factors}
- M2 Sensör Verileri (Bugünkü Durum): {health_context}
- Günlük Kalori Hedefi: {target_calories} kcal

DİYETİSYEN TALİMATLARI:
1. MAKRO DAĞILIMI: Planı yaklaşık %45 Karbonhidrat (kompleks), %25 Protein, %30 Sağlıklı Yağ dengesiyle kur.
2. KLİNİK ÖNCELİKLER:
   - Hipertansiyon varsa: Sodyum < 2300mg. Magnezyum ve Potasyumdan zengin (ıspanak, muz, baklagil) besinler.
   - Yüksek Nabız/Kardiyak risk varsa: Kafein, rafine şeker ve ağır doymuş yağları tamamen çıkar.
   - Hareketsiz günlerde: Glisemik indeksi düşük, lif oranı yüksek besinler.
3. TÜBER UYUMLU: Türkiye Beslenme Rehberi (TÜBER) standartlarına ve Türk damak tadına uygun içerikler seç.
4. DETAYLI PORSİYON: 'Biraz' veya 'Az' gibi belirsiz ifadeler yerine '1 orta boy (150g)', '2 yemek kaşığı' gibi net ölçüler kullan.
5. NEDENSELLİK (Reasoning): Her öğün için 'Neden bu besin?' sorusunu kullanıcının klinik risklerine atıfta bulunarak açıkla.

Yanıtı SADECE aşağıdaki JSON yapısında döndür:

{{
  "daily_calories_target": {target_calories},
  "meals": [
    {{
      "meal_type": "Sabah / Öğle / Akşam / Ara Öğün",
      "food_name": "Yemeğin tam adı",
      "portion": "Net gramaj ve ölçü birimi (örn: 180g Izgara Levrek, 1 kase mevsim salata)",
      "calories": 350,
      "reasoning": "Kullanıcının [Risk Faktörü] durumu için [Besin Bileşeni] sayesinde [Fayda] sağlar."
    }}
  ],
  "ai_advice": "Kullanıcının bugünkü M2 sensör verilerine ve genel risk haritasına göre diyetisyen notu (3-4 cümle)."
}}
"""

async def generate_diet_plan(
    age: int, gender: str, height: float, weight: float,
    risk_level: str, risk_factors: str, health_context: str,
    target_calories: int
) -> Optional[DietPlanResponse]:
    prompt = DIET_PROMPT.format(
        age=age, gender=gender, height=height, weight=weight,
        risk_level=risk_level, risk_factors=risk_factors,
        health_context=health_context, target_calories=target_calories
    )

    # AI Çağrısı (Merkezi Servis Üzerinden)
    raw_text = await ask_text(
        prompt=prompt,
        system_prompt="Sen uzman bir klinik diyetisyensin. Yanıtlarını tamamen Türkçe ve akademik olmayan, halkın anlayacağı sade bir dille ver. Asla İngilizce terim kullanma.",
        json_mode=True
    )

    if not raw_text:
        return None

    try:
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
