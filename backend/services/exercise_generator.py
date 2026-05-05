import json
import logging
from typing import Optional
from models.exercise_model import ExercisePlanResponse, ExerciseItem, ExerciseRequest

logger = logging.getLogger(__name__)

from services.ai_service import ask_text


EXERCISE_PROMPT = """
Sen uzman bir spor fizyoloğu ve kinesiyologsun. Görevin, aşağıdaki tıbbi verilere ve bugünkü aktivite seviyesine dayanarak kullanıcıya 'Güvenli Limitler' içinde bir egzersiz planı hazırlamak.

HİYERARŞİK YOĞUNLUK SINIFLARI (KRİTİK):
- Sınıf 0: YÜKSEK RİSK. Sadece ev içi mobilite ve 10 dk hafif esneme.
- Sınıf 1: ORTA-YÜKSEK RİSK. Yoga (nefes odaklı), 15 dk yavaş yürüyüş.
- Sınıf 2: ORTA RİSK. 20-30 dk tempolu yürüyüş, hafif direnç bandı.
- Sınıf 3: DÜŞÜK RİSK. 30-45 dk bisiklet, yüzme veya vücut ağırlığı antrenmanı.
- Sınıf 4: OPTİMAL. HIIT, ağırlık antrenmanı veya 5km koşu.

GİRDİ PARAMETRELERİ:
- Profil: {age} yaş, {gender}, {height}cm, {weight}kg
- Hedef Yoğunluk Sınıfı: {class_id}
- Klinik Risk Durumu: {risk_level}
- M2 Sensör & 14 Günlük Özet: {health_context}
- Tarih: {current_date}

TALİMATLAR:
1. GÜVENLİK ODAKLI: Eğer M2 verilerinde son günlerde nabız anomalisi veya yüksek tansiyon varsa, {class_id} ne olursa olsun tempoyu bir alt sınıfa çek.
2. DETAYLI AÇIKLAMA: Her egzersizin nasıl yapılacağını, hangi kas grubuna odaklandığını ve 'nefes kontrolü' uyarısını description kısmına ekle.
3. KALORİ HESABI: Kullanıcının kilosuna ({weight}kg) ve egzersiz MET değerine göre gerçekçi kalori hesabı yap.
4. AI ADVICE: Kullanıcının bugünkü verilerine (RAG) atıfta bulunarak, neden bu programın seçildiğini bilimsel bir dille açıkla.

Yanıtı SADECE aşağıdaki JSON yapısında döndür:

{{
  "exercises": [
    {{
      "title": "Egzersizin tam adı",
      "duration_minutes": 25,
      "intensity": "Çok Düşük / Düşük / Orta / Yüksek",
      "calories": 150,
      "type": "Kardiyo / Güç / Esneklik / Denge",
      "description": "Detaylı yapılış tekniği, set/tekrar veya nefes uyarısı."
    }}
  ],
  "total_duration_minutes": 25,
  "total_calories": 150,
  "ai_advice": "Fizyolog notu: Bugünkü {health_context} verileriniz ve {risk_level} riskiniz göz önüne alınarak bu program hazırlanmıştır. (3-4 cümle)."
}}
"""

async def generate_dynamic_plan(
    req: ExerciseRequest, 
    class_id: int, 
    health_context: str
) -> Optional[ExercisePlanResponse]:
    """Gemini AI kullanarak dinamik ve kişiselleştirilmiş egzersiz planı üretir."""

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

    # AI Çağrısı (Merkezi Servis Üzerinden)
    raw_text = await ask_text(
        prompt=prompt,
        system_prompt="Sen uzman bir spor fizyoloğu ve kinesiyologsun. Yanıtlarını tamamen Türkçe ve anlaşılır bir dille ver. 'Set', 'Reps' gibi terimler yerine 'Tekrar', 'Dizi' gibi Türkçe karşılıkları kullan.",
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
        return ExercisePlanResponse(**json_data)

    except Exception as e:
        logger.error(f"Dinamik egzersiz planı üretilirken hata oluştu: {e}")
        return None
