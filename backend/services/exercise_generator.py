import json
import logging
from typing import Optional
from models.exercise_model import ExercisePlanResponse, ExerciseItem, ExerciseRequest

logger = logging.getLogger(__name__)

from services.ai_service import ask_text


EXERCISE_PROMPT = """
Sen Türkiye'nin en iyi spor fizyoloğu ve kinesiyologsun. Görevin, kullanıcının tıbbi durumu ve aktivite geçmişine dayanan, GERÇEK bir spor salonu koçu gibi detaylı ve çeşitli bir antrenman programı hazırlamak.

━━━ YOĞUNLUK SINIFI: {class_id} ━━━
Sınıf 0 (YÜKSEK RİSK): Ev içi hafif mobilite, oturarak esneme, nefes egzersizleri. Max 20 dk.
Sınıf 1 (ORTA-YÜKSEK RİSK): Yoga akışı, yavaş yürüyüş, denge çalışması. Max 25 dk.
Sınıf 2 (ORTA RİSK): Tempolu yürüyüş, hafif direnç bandı, pilates, core stabilite. Max 35 dk.
Sınıf 3 (DÜŞÜK RİSK): Koşu, bisiklet, yüzme, vücut ağırlığı antrenmanı, fonksiyonel hareketler. Max 45 dk.
Sınıf 4 (OPTİMAL): HIIT, ağırlık antrenmanı, devre antrenmanı (circuit), sprint intervalleri. Max 50 dk.

━━━ KULLANICI PROFİLİ ━━━
- {age} yaş, {gender}, {height}cm, {weight}kg
- Risk Durumu: {risk_level}
- Bugünkü/Geçmiş Veriler: {health_context}
- Tarih: {current_date}

━━━ ZORUNLU KURALLAR ━━━
1. YAPI: Her programda mutlaka 3 aşama olsun:
   a) ISINMA (5-7 dk): Dinamik esneme, eklem mobilizasyonu
   b) ANA SET (15-35 dk): En az 3 farklı egzersiz. Farklı kas gruplarını hedefle.
   c) SOĞUMA (5 dk): Statik esneme, nefes düzenleme

2. ÇEŞİTLİLİK: Asla tek bir egzersiz önerme. Her planda EN AZ 4, EN FAZLA 7 farklı egzersiz olsun.
   - Kardiyo + Güç + Esneklik karışımı yap
   - Üst gövde, alt gövde ve core kas gruplarını dengeli dağıt
   - Hep aynı hareketleri önerme. Squat, lunge, plank, push-up, glute bridge, dead bug, bird dog, mountain climber, jumping jack, burpee, kettlebell swing, dumbbell row, lateral raise, calf raise, wall sit, bear crawl gibi geniş bir havuzdan seç.

3. DETAY: Her egzersiz için:
   - Kaç set × kaç tekrar VEYA kaç dakika (interval ise aktif/dinlenme süresi)
   - Hangi kas grubunu çalıştırdığı
   - Doğru form uyarısı (örn: "Dizler ayak uçlarını geçmesin", "Sırt düz kalsın")
   - Ekipman gereksinimi (varsa) veya "Ekipman gerektirmez" notu

4. KALORİ: {weight}kg ağırlık ve MET değerlerine göre GERÇEK kalori hesabı yap.
   Formül: Kalori = MET × Ağırlık(kg) × Süre(saat)
   Örnek MET değerleri: Yürüyüş=3.5, Koşu=8.0, Bisiklet=6.0, Yoga=2.5, HIIT=8.0, Ağırlık=5.0

5. TAVSİYE: ai_advice alanında:
   - Kullanıcının {health_context} verilerine atıfta bulun
   - Neden bu program seçildiğini açıkla
   - Antrenman sonrası beslenme ve hidrasyon önerisi ver
   - Bir sonraki antrenman için motivasyon cümlesi ekle

━━━ JSON ÇIKTI FORMATI ━━━
{{
  "exercises": [
    {{
      "title": "Egzersizin Türkçe adı",
      "duration_minutes": 10,
      "intensity": "Çok Düşük / Düşük / Orta / Yüksek",
      "calories": 50,
      "type": "Isınma / Kardiyo / Güç / Esneklik / Denge / Soğuma",
      "description": "3 set × 12 tekrar. Hedef kas: Quadriceps, Gluteus. Dizler ayak uçlarını geçmesin. Ekipman gerektirmez."
    }}
  ],
  "total_duration_minutes": 40,
  "total_calories": 250,
  "ai_advice": "Detaylı fizyolog notu (4-5 cümle)"
}}
"""

async def generate_dynamic_plan(
    req: ExerciseRequest, 
    class_id: int, 
    health_context: str
) -> Optional[ExercisePlanResponse]:
    """Yapay zeka kullanarak dinamik ve kişiselleştirilmiş egzersiz planı üretir."""

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
        from services.ai_service import clean_json_string
        cleaned_json = clean_json_string(raw_text)
            
        json_data = json.loads(cleaned_json)
        return ExercisePlanResponse(**json_data)

    except Exception as e:
        logger.error(f"Dinamik egzersiz planı üretilirken hata oluştu: {e}")
        return None
