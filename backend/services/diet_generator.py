import json
import logging
from typing import Optional
from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)

from services.ai_service import ask_text  # noqa: E402


# ── Pydantic Modelleri ──
class DietMeal(BaseModel):
    meal_type: str = Field(description="Öğün Türü (Sabah, Öğle, Akşam, Ara Öğün)")
    food_name: str = Field(description="Yemeklerin adı")
    portion: str = Field(description="Porsiyon büyüklüğü")
    calories: int = Field(description="Tahmini kalori")
    reasoning: str = Field(
        description="Neden bu öğün seçildi? (Risk faktörlerine göre açıklama)"
    )


class DietPlanResponse(BaseModel):
    daily_calories_target: int
    meals: list[DietMeal]
    ai_advice: str = Field(
        description="Kullanıcının risk haritasına göre diyetisyen tavsiyesi."
    )


DIET_PROMPT = """
Sen uzman bir klinik diyetisyen ve beslenme bilimcisisin. Görevin, aşağıdaki verilere dayanarak kullanıcıya hiper-kişiselleştirilmiş, bilimsel temelli bir günlük beslenme planı hazırlamak.

GİRDİ PARAMETRELERİ:
- Profil: {age} yaş, {gender}, {height}cm, {weight}kg
- Alerjiler: {allergies}
- Diyet Tercihi: {diet_preference}
- Klinik Risk Seviyesi: {risk_level}
- Tanımlanmış Risk Faktörleri: {risk_factors}
- M2 Sensör Verileri (Bugünkü Durum): {health_context}
- Günlük Kalori Hedefi: {target_calories} kcal (BU DEĞER UYGULAMA TARAFINDAN ÖZEL HESAPLANMIŞTIR. KESİNLİKLE EKSİLTME YAPMAYIN, DİYET LİSTESİNİ TAM OLARAK BU KALORİYE GÖRE HAZIRLAYIN)

DİYETİSYEN TALİMATLARI:
1. MAKRO DAĞILIMI: Planı yaklaşık %45 Karbonhidrat (kompleks), %25 Protein, %30 Sağlıklı Yağ dengesiyle kur.
2. MATEMATİKSEL KONTROL (ÇOK ÖNEMLİ): Yazdığın tüm öğünlerin (Sabah, Öğle, Akşam, Ara Öğünler) kalori değerlerinin TOPLAMI, BİREBİR sana verilen Günlük Kalori Hedefi ({target_calories}) değerine EŞİT OLMALIDIR. Kalorileri gramajları ayarlayarak bu toplama tam uyacak şekilde dağıt.
3. KLİNİK ÖNCELİKLER:
   - Hipertansiyon varsa: Sodyum < 2300mg. Magnezyum ve Potasyumdan zengin (ıspanak, muz, baklagil) besinler.
   - Yüksek Nabız/Kardiyak risk varsa: Kafein, rafine şeker ve ağır doymuş yağları tamamen çıkar.
   - Hareketsiz günlerde: Glisemik indeksi düşük, lif oranı yüksek besinler.
4. TÜBER UYUMLU: Türkiye Beslenme Rehberi (TÜBER) standartlarına ve Türk damak tadına uygun içerikler seç.
5. ÇEŞİTLİLİK VE ROTASYON: Her defasında balık veya aynı ızgara et türünü önerme. Türk mutfağındaki sebze yemekleri, kurubaklagiller, kırmızı et, hindi, yumurta ve alternatif protein kaynaklarını dönüşümlü olarak kullan. Rastgelelik kat.
6. DETAYLI PORSİYON: 'Biraz' veya 'Az' gibi belirsiz ifadeler yerine '1 orta boy (150g)', '2 yemek kaşığı' gibi net ölçüler kullan.
7. NEDENSELLİK (Reasoning): Her öğün için 'Neden bu besin?' sorusunu kullanıcının klinik risklerine atıfta bulunarak açıkla.

Yanıtı SADECE aşağıdaki JSON yapısında döndür:

{{
  "daily_calories_target": {target_calories},
  "meals": [
    {{
      "meal_type": "Sabah / Öğle / Akşam / Ara Öğün",
      "food_name": "Yemeğin tam adı",
      "portion": "Net gramaj ve ölçü birimi (örn: 150g Izgara Tavuk, 6 kaşık Zeytinyağlı Fasulye)",
      "calories": 350,
      "reasoning": "Kullanıcının [Risk Faktörü] durumu için [Besin Bileşeni] sayesinde [Fayda] sağlar."
    }}
  ],
  "ai_advice": "Kullanıcının bugünkü M2 sensör verilerine ve genel risk haritasına göre diyetisyen notu (3-4 cümle)."
}}
"""


async def generate_diet_plan(
    age: int,
    gender: str,
    height: float,
    weight: float,
    risk_level: str,
    risk_factors: str,
    health_context: str,
    target_calories: int,
    allergies: list[str],
    diet_preference: str,
) -> Optional[DietPlanResponse]:

    # Alerji stringini formatla
    allergy_str = ", ".join(allergies) if allergies else "Yok"

    prompt = DIET_PROMPT.format(
        age=age,
        gender=gender,
        height=height,
        weight=weight,
        allergies=allergy_str,
        diet_preference=diet_preference,
        risk_level=risk_level,
        risk_factors=risk_factors,
        health_context=health_context,
        target_calories=target_calories,
    )

    # AI Çağrısı (Merkezi Servis Üzerinden)
    raw_text = await ask_text(
        prompt=prompt,
        system_prompt="Sen uzman bir klinik diyetisyensin. Yanıtlarını tamamen Türkçe ve akademik olmayan, halkın anlayacağı sade bir dille ver. Asla İngilizce terim kullanma.",
        json_mode=True,
    )

    if not raw_text:
        return None

    try:
        # JSON temizleme
        from services.ai_service import clean_json_string

        cleaned_json = clean_json_string(raw_text)

        json_data = json.loads(cleaned_json)

        # MATEMATİK KORUMASI: LLM'ler toplama işleminde hata yapabilir.
        # Öğünlerin toplamını alıp, hedef kaloriye eşitlemek için orantısal olarak dağıtıyoruz.
        if "meals" in json_data and isinstance(json_data["meals"], list):
            total_meal_cals = sum(
                meal.get("calories", 0) for meal in json_data["meals"]
            )
            if total_meal_cals > 0 and abs(total_meal_cals - target_calories) > 10:
                scale_factor = target_calories / total_meal_cals
                for meal in json_data["meals"]:
                    meal["calories"] = int(meal.get("calories", 0) * scale_factor)

                # Yuvarlama farklarını kapatmak için kalanı ilk (veya en büyük) öğüne ekle
                new_total = sum(meal.get("calories", 0) for meal in json_data["meals"])
                diff = target_calories - new_total
                if diff != 0 and len(json_data["meals"]) > 0:
                    json_data["meals"][0]["calories"] += diff

            # Asla hedefini değiştirme, arayüzdeki (NutritionScreen) değer ile aynı kalsın.
            json_data["daily_calories_target"] = target_calories

        return DietPlanResponse(**json_data)

    except Exception as e:
        logger.error(f"Diyet planı üretilirken hata oluştu: {e}")
        return None
