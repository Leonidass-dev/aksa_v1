import logging
from datetime import date, timedelta
from fastapi import APIRouter, HTTPException, Depends, Query, BackgroundTasks
from pydantic import BaseModel, Field
from typing import Optional
from dotenv import load_dotenv
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db, async_session
from auth import get_current_user
import crud
from services.ai_service import ask_text, summarize_memory

load_dotenv()

logger = logging.getLogger(__name__)

router = APIRouter()


class ChatRequest(BaseModel):
    message: str = Field(
        description="Kullanıcının yazdığı mesaj (örn: başım ağrıyor, ne yapmalıyım?)"
    )


class ChatResponse(BaseModel):
    reply: str
    is_safe: bool = True


class MoodAdviceRequest(BaseModel):
    mood: str = Field(description="Kullanıcının o anki ruh hali (örn: Stresli, Üzgün)")

class MoodAdviceResponse(BaseModel):
    advice: str


class ChatHistoryItem(BaseModel):
    id: int
    role: str
    content: str
    is_safe: bool
    created_at: str


PROMPT = """
Sen "AKSA" isimli, bilgili ve şefkatli bir yapay zeka sağlık asistanısın.
Kullanıcılar sana yaşadıkları günlük, hafif sağlık sorunlarını veya semptomlarını yazacaklar.

KESİN KURALLARIN:
1. ASLA HASTALIK TEŞHİSİ KOYMA. "Sende migren olabilir", "Bu bir kalp krizi belirtisi" gibi tıbbi konularda tanı veya net bir karar bildiremezsin.
2. Reçeteli ilaç tavsiyesinde ASLA bulunma.
3. Verebileceğin tavsiyeler sadece günlük, risksiz yaşam tarzı tavsiyeleri olmalı: Su içmek, dinlenmek, ekran süresini azaltmak, odayı havalandırmak, buz kompleksi yapmak vb.
4. Ciddi veya geçmeyen semptomlarda, nefes darlığı, şiddetli göğüs ağrısı gibi kırmızı bayrak durumlarında ACİLEN bir doktora / acil servise gitmesini tavsiye et.
5. Her yanıtını samimi, kısa ve anlaşılır bir Türkçe ile ver.
6. Yanıtına her zaman tıbbi bir tanı koyamayacağını ve tavsiyelerin genel bilgilendirme amaçlı olduğunu hatırlatarak başla veya bitir.

VERİ KULLANIMI:
7. Sana kullanıcının BUGÜNKÜ GERÇEK sağlık verileri (adım, nabız, su tüketimi, yemekler, uyku, kalori vb.) sağlanacak. Bu verileri MUTLAKA kullan.
8. Kullanıcı "ne kadar su içmeliyim?" derse, önce bugün ne kadar su içtiğini söyle, sonra tavsiyeni ver.
9. Kullanıcı yemek veya kalori sorarsa, bugün yediği öğünleri ve toplam kalori alımını belirt.
10. Kullanıcı uyku, adım, nabız vb. sorarsa, verilerindeki gerçek değerleri referans göster.
11. Eğer veri 0 veya boşsa, "henüz veri senkronize edilmemiş olabilir" de, uydurma bir değer verme.

Kullanıcının Mesajı: 
"""


async def _bg_update_memory(user_id: int, old_memory: str, req_msg: str, ai_reply: str):
    """Arkaplanda çalışıp kullanıcının kalıcı AI hafızasını günceller."""
    try:
        new_summary = await summarize_memory(old_memory, req_msg, ai_reply)
        async with async_session() as db:
            await crud.update_user_memory(db, user_id, new_summary)
    except Exception as e:
        logger.error(f"Hafıza güncellenirken hata oluştu: {e}")


@router.post("/chat", response_model=ChatResponse)
async def chat_with_assistant(
    req: ChatRequest,
    background_tasks: BackgroundTasks,
    uid: str = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Semptom kontrolcüsü ve sağlık yaşam tarzı asistanı.
    Context-Aware: Kullanıcının TÜM günlük verilerini kullanarak yanıt verir.
    """
    try:
        # Kullanıcıyı ve verilerini çek
        user = await crud.get_or_create_user(db, uid)
        today_record = await crud.get_today_health(db, user)
        latest_risk = await crud.get_latest_risk_score(db, user)
        today_meals = await crud.get_today_meals(db, user)
        user_memory = await crud.get_user_memory(db, user.id)

        # ── Zengin Bağlam (Context) Oluşturma ──
        context_parts = ["--- KULLANICININ BUGÜNKÜ SAĞLIK VERİLERİ VE HAFIZA ---"]

        if user_memory.memory_summary:
            context_parts.append(
                f"🧠 KULLANICI PROFİLİ (Geçmişten Öğrenilenler):\n{user_memory.memory_summary}\n"
            )

        # Profil Bilgileri
        if user.age or user.weight or user.height:
            profile_info = []
            if user.age:
                profile_info.append(f"Yaş: {user.age}")
            if user.gender:
                profile_info.append(
                    f"Cinsiyet: {'Erkek' if user.gender == 'M' else 'Kadın'}"
                )
            if user.height:
                profile_info.append(f"Boy: {user.height} cm")
            if user.weight:
                profile_info.append(f"Kilo: {user.weight} kg")
            if user.weight and user.height and user.height > 0:
                bmi = user.weight / ((user.height / 100) ** 2)
                profile_info.append(f"BMI (VKE): {bmi:.1f}")
            context_parts.append("📋 Profil: " + ", ".join(profile_info))

        if today_record:
            # Aktivite
            context_parts.append(f"👣 Adım: {int(today_record.steps)}")
            if today_record.active_calories > 0:
                context_parts.append(
                    f"🔥 Aktif Kalori: {int(today_record.active_calories)} kcal"
                )
            if today_record.distance_m > 0:
                context_parts.append(f"📏 Mesafe: {int(today_record.distance_m)} m")

            # Kardiyovasküler
            if today_record.heart_rate > 0:
                context_parts.append(f"❤️ Nabız: {int(today_record.heart_rate)} bpm")
            if today_record.resting_heart_rate > 0:
                context_parts.append(
                    f"💓 Dinlenik Nabız: {int(today_record.resting_heart_rate)} bpm"
                )
            if today_record.spo2 > 0:
                context_parts.append(f"🩸 SpO2: %{int(today_record.spo2)}")

            # Tansiyon
            if today_record.systolic > 0 or today_record.diastolic > 0:
                context_parts.append(
                    f"⚖️ Tansiyon: {int(today_record.systolic)}/{int(today_record.diastolic)} mmHg"
                )

            # Uyku
            if today_record.sleep_hours > 0:
                sleep_info = f"🌙 Uyku: {today_record.sleep_hours:.1f} saat"
                details = []
                if today_record.sleep_deep_min > 0:
                    details.append(f"Derin: {int(today_record.sleep_deep_min)} dk")
                if today_record.sleep_light_min > 0:
                    details.append(f"Hafif: {int(today_record.sleep_light_min)} dk")
                if today_record.sleep_rem_min > 0:
                    details.append(f"REM: {int(today_record.sleep_rem_min)} dk")
                if details:
                    sleep_info += f" ({', '.join(details)})"
                context_parts.append(sleep_info)

            # Stres
            if today_record.stress_level > 0:
                context_parts.append(f"🧠 Stres: {int(today_record.stress_level)}/100")

            # Su & Ruh Hali
            context_parts.append(f"💧 Su Tüketimi: {int(today_record.water_ml)} ml")
            if today_record.mood and today_record.mood != "neutral":
                context_parts.append(f"😊 Ruh Hali: {today_record.mood}")
        else:
            context_parts.append(
                "⚠️ Bugüne ait sensör verisi henüz senkronize edilmemiş."
            )

        # Bugünkü Yemekler
        if today_meals:
            total_cal = sum(m.calories for m in today_meals)
            total_protein = sum(m.protein_g for m in today_meals)
            total_carbs = sum(m.carbs_g for m in today_meals)
            total_fat = sum(m.fat_g for m in today_meals)
            meal_names = [m.food_name for m in today_meals]
            context_parts.append(
                f"🍽️ Bugün Yenen ({len(today_meals)} öğün): {', '.join(meal_names)}"
            )
            context_parts.append(
                f"🔢 Toplam Alınan Kalori: {total_cal} kcal (P: {total_protein:.0f}g, K: {total_carbs:.0f}g, Y: {total_fat:.0f}g)"
            )
        else:
            context_parts.append("🍽️ Bugün henüz öğün kaydı yok.")

        # Risk Skoru
        if latest_risk:
            context_parts.append(
                f"📊 Risk Skoru: {latest_risk.score}/100 ({latest_risk.level_label})"
            )
            if latest_risk.top_factors:
                factor_names = [
                    f.get("name", "") if isinstance(f, dict) else ""
                    for f in latest_risk.top_factors[:3]
                ]
                context_parts.append(f"⚠️ Risk Faktörleri: {', '.join(factor_names)}")

        context_parts.append("--- VERİ SONU ---")
        context = "\n".join(context_parts)

        # Sohbet Geçmişini Çek (Hafıza için son 6 mesaj)
        history_records = await crud.get_chat_history(db, user, limit=6)
        history = []
        for m in history_records:
            history.append({"role": m.role, "content": m.content})

        # Kullanıcı mesajını DB'ye kaydet
        await crud.save_chat_message(db, user, role="user", content=req.message)

        # AI Çağrısı (Merkezi Servis Üzerinden)
        full_prompt = f"{context}\n\n[KULLANICI SORUSU]:\n\"\"\"\n{req.message}\n\"\"\""

        reply = await ask_text(
            prompt=full_prompt, system_prompt=PROMPT, history=history, json_mode=False
        )

        if not reply:
            raise HTTPException(
                status_code=502, detail="Yapay zeka servisi şu an yanıt veremiyor."
            )

        # Asistan yanıtını DB'ye kaydet
        await crud.save_chat_message(db, user, role="assistant", content=reply)

        # Arkaplanda hafızayı güncelle
        background_tasks.add_task(
            _bg_update_memory, user.id, user_memory.memory_summary, req.message, reply
        )

        return ChatResponse(reply=reply)

    except HTTPException:
        raise
    except Exception:
        logger.exception("Assistant Chat Error")
        raise HTTPException(
            status_code=500, detail="Bir hata oluştu, lütfen tekrar deneyin."
        )


@router.post("/mood-advice", response_model=MoodAdviceResponse)
async def mood_advice(
    req: MoodAdviceRequest,
    uid: str = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Anlık ruh hali (Mood) için yapay zeka destekli mini rahatlama tavsiyesi verir."""
    try:
        user = await crud.get_or_create_user(db, uid)
        today_record = await crud.get_today_health(db, user)

        context_parts = []
        if today_record:
            if today_record.heart_rate > 0:
                context_parts.append(f"Nabız: {int(today_record.heart_rate)} bpm")
            if today_record.sleep_hours > 0:
                context_parts.append(f"Uyku: {today_record.sleep_hours:.1f} saat")
            if today_record.steps > 0:
                context_parts.append(f"Adım: {int(today_record.steps)}")

        ctx_str = ", ".join(context_parts) if context_parts else "Veri yok"

        prompt = f"Kullanıcı şu an '{req.mood}' hissediyor. Kullanıcının günlük fiziksel verileri: {ctx_str}. " \
                 "Lütfen bu duruma uygun, moral verici ve onu rahatlatacak ÇOK KISA (maksimum 2-3 cümlelik) bir tavsiye veya ufak bir nefes egzersizi ver. " \
                 "Çok içten ve sıcakkanlı ol."

        system_prompt = "Sen 'AKSA', anlayışlı bir psikolojik destek ve sağlık asistanısın. Tıbbi tanı koymadan sadece rahatlatıcı yaşam tarzı tavsiyesi ver."

        reply = await ask_text(prompt=prompt, system_prompt=system_prompt, history=[], json_mode=False)

        if not reply:
            reply = "Şu an biraz zorlanıyor olabilirsin. Gözlerini kapatıp 5 saniye derin nefes al ve yavaşça ver. Bu sana iyi gelecektir."

        return MoodAdviceResponse(advice=reply)
    except Exception as e:
        logger.exception(f"Mood Advice Error: {e}")
        return MoodAdviceResponse(advice="Derin bir nefes al ve omuzlarını gevşet. Her şey yoluna girecek.")


@router.get("/history", response_model=list[ChatHistoryItem])
async def chat_history(
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    uid: str = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Kullanıcının chat geçmişini getirir (eskiden yeniye)."""
    user = await crud.get_or_create_user(db, uid)
    messages = await crud.get_chat_history(db, user, limit, offset)
    return [
        ChatHistoryItem(
            id=m.id,
            role=m.role,
            content=m.content,
            is_safe=m.is_safe,
            created_at=m.created_at.isoformat(),
        )
        for m in messages
    ]


@router.delete("/history")
async def clear_chat_history(
    uid: str = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Kullanıcının chat geçmişini siler."""
    user = await crud.get_or_create_user(db, uid)
    await crud.clear_chat_history(db, user)
    return {"message": "Chat geçmişi temizlendi."}


# ═══════════════════════════════════════════════════════════════════
#  HAFTALIK AI DIGEST
# ═══════════════════════════════════════════════════════════════════


class WeeklyDigestResponse(BaseModel):
    digest: str
    period_start: str
    period_end: str
    avg_steps: float = 0
    avg_sleep: float = 0
    avg_heart_rate: float = 0
    total_meals: int = 0
    total_exercises: int = 0


@router.get("/weekly-digest", response_model=WeeklyDigestResponse)
async def weekly_digest(
    uid: str = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Son 7 günlük sağlık verilerini toplayıp yapay zekadan doğal dilde haftalık değerlendirme üretir.
    """
    try:
        user = await crud.get_or_create_user(db, uid)
        records = await crud.get_health_records(db, user, days=7)
        today_meals = await crud.get_today_meals(db, user)
        meal_history = await crud.get_meal_history(db, user, limit=50)
        latest_risk = await crud.get_latest_risk_score(db, user)

        period_end = date.today()
        period_start = period_end - timedelta(days=7)

        # Son 7 gün istatistikleri
        valid_records = [r for r in records if r.steps > 0 or r.sleep_hours > 0]
        count = len(valid_records) if valid_records else 1

        avg_steps = sum(r.steps for r in valid_records) / count if valid_records else 0
        avg_sleep = sum(r.sleep_hours for r in valid_records) / count if valid_records else 0
        avg_hr = sum(r.heart_rate for r in valid_records if r.heart_rate > 0) / max(1, sum(1 for r in valid_records if r.heart_rate > 0)) if valid_records else 0
        avg_water = sum(r.water_ml for r in valid_records) / count if valid_records else 0

        # Son 7 gündeki yemek sayısı
        week_meals = [m for m in meal_history if m.analyzed_at and m.analyzed_at.date() >= period_start]
        total_meals = len(week_meals)

        # Egzersiz planları (geçen hafta)
        from sqlalchemy import select, desc
        from db_models import ExercisePlan
        ex_stmt = (
            select(ExercisePlan)
            .where(ExercisePlan.user_id == user.id)
            .order_by(desc(ExercisePlan.created_at))
            .limit(30)
        )
        ex_result = await db.execute(ex_stmt)
        all_exercises = list(ex_result.scalars().all())
        week_exercises = [e for e in all_exercises if e.created_at and e.created_at.date() >= period_start]
        total_exercises = len(week_exercises)

        # Trend hesaplama (son 3 gün vs ilk 3 gün)
        trend_text = ""
        if len(valid_records) >= 6:
            sorted_recs = sorted(valid_records, key=lambda r: r.record_date)
            first_half = sorted_recs[:3]
            second_half = sorted_recs[-3:]
            first_avg_steps = sum(r.steps for r in first_half) / 3
            second_avg_steps = sum(r.steps for r in second_half) / 3
            if first_avg_steps > 0:
                step_change = ((second_avg_steps - first_avg_steps) / first_avg_steps) * 100
                trend_text = f"Adım trendi: Hafta başına göre %{abs(step_change):.0f} {'artış' if step_change > 0 else 'azalış'}. "

        # AI Prompt oluştur
        data_summary = f"""
Son 7 gün sağlık verileri:
- Ortalama Adım: {avg_steps:.0f} adım/gün
- Ortalama Uyku: {avg_sleep:.1f} saat/gece
- Ortalama Nabız: {avg_hr:.0f} bpm
- Ortalama Su Tüketimi: {avg_water:.0f} ml/gün
- Bu hafta kaydedilen öğün: {total_meals}
- Bu hafta yapılan egzersiz planı: {total_exercises}
{trend_text}
"""

        if latest_risk:
            data_summary += f"- Son Risk Skoru: {latest_risk.score:.0f}/100 ({latest_risk.level_label})\n"

        # Günlük detaylar
        if valid_records:
            sorted_recs = sorted(valid_records, key=lambda r: r.record_date)
            daily_details = []
            for r in sorted_recs:
                day_str = r.record_date.strftime("%A")
                details = f"  {day_str}: {int(r.steps)} adım, {r.sleep_hours:.1f}s uyku"
                if r.heart_rate > 0:
                    details += f", {int(r.heart_rate)} bpm"
                if r.water_ml > 0:
                    details += f", {int(r.water_ml)} ml su"
                daily_details.append(details)
            data_summary += "\nGünlük Detaylar:\n" + "\n".join(daily_details)

        system_prompt = (
            "Sen AKSA, deneyimli bir sağlık koçu ve yazarsın. "
            "Kullanıcının son 7 günlük sağlık verilerini analiz edip, samimi ve motive edici bir haftalık değerlendirme mektubu yaz. "
            "Kurallar:\n"
            "1. 4-6 cümle olsun, KISA ve ÖZ tut.\n"
            "2. Hem olumlu gelişmeleri vurgula hem de iyileştirme alanlarını nazikçe belirt.\n"
            "3. Somut verilere referans ver (kaç adım, kaç saat uyku gibi).\n"
            "4. Gelecek hafta için 1 pratik öneri ver.\n"
            "5. Tıbbi tanı koyma, genel yaşam tarzı tavsiyesi ver.\n"
            "6. Türkçe yaz, samimi ve destekleyici bir ton kullan.\n"
            "7. Emoji kullanabilirsin ama abartma (en fazla 3-4)."
        )

        digest = await ask_text(
            prompt=data_summary,
            system_prompt=system_prompt,
            history=[],
            json_mode=False,
        )

        if not digest:
            digest = (
                f"Bu hafta ortalama {avg_steps:.0f} adım attınız ve {avg_sleep:.1f} saat uyudunuz. "
                f"Verileriniz genel olarak normal aralıkta görünüyor. Sağlıklı yaşam alışkanlıklarınızı sürdürmeye devam edin! 💪"
            )

        return WeeklyDigestResponse(
            digest=digest,
            period_start=period_start.isoformat(),
            period_end=period_end.isoformat(),
            avg_steps=round(avg_steps, 1),
            avg_sleep=round(avg_sleep, 1),
            avg_heart_rate=round(avg_hr, 1),
            total_meals=total_meals,
            total_exercises=total_exercises,
        )

    except Exception as e:
        logger.exception(f"Weekly Digest Error: {e}")
        return WeeklyDigestResponse(
            digest="Haftalık değerlendirme şu an oluşturulamadı. Lütfen daha sonra tekrar deneyin.",
            period_start=(date.today() - timedelta(days=7)).isoformat(),
            period_end=date.today().isoformat(),
        )


# ═══════════════════════════════════════════════════════════════════
#  İLERLEME ÖZETİ (Progress Summary)
# ═══════════════════════════════════════════════════════════════════


class ProgressSummaryResponse(BaseModel):
    total_meal_days: int = 0
    total_exercise_days: int = 0
    days_in_period: int = 30
    meal_streak: int = 0
    exercise_streak: int = 0
    total_calories_burned: int = 0
    total_exercise_minutes: int = 0
    avg_health_score: float = 0
    monthly_meals: list = []
    monthly_exercises: list = []


@router.get("/progress-summary", response_model=ProgressSummaryResponse)
async def progress_summary(
    days: int = Query(default=30, ge=7, le=90),
    uid: str = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Son N günlük yemek ve egzersiz geçmişinden ilerleme istatistiklerini çıkarır.
    """
    try:
        user = await crud.get_or_create_user(db, uid)
        since = date.today() - timedelta(days=days)

        # Yemek geçmişi
        meal_history = await crud.get_meal_history(db, user, limit=200)
        period_meals = [m for m in meal_history if m.analyzed_at and m.analyzed_at.date() >= since]
        meal_dates = set(m.analyzed_at.date() for m in period_meals if m.analyzed_at)
        total_meal_days = len(meal_dates)

        # Yemek sağlık skoru ortalaması
        health_scores = [m.health_score for m in period_meals if m.health_score and m.health_score > 0]
        avg_health_score = sum(health_scores) / len(health_scores) if health_scores else 0

        # Egzersiz geçmişi
        from sqlalchemy import select, desc
        from db_models import ExercisePlan
        ex_stmt = (
            select(ExercisePlan)
            .where(ExercisePlan.user_id == user.id)
            .order_by(desc(ExercisePlan.created_at))
            .limit(200)
        )
        ex_result = await db.execute(ex_stmt)
        all_exercises = list(ex_result.scalars().all())
        period_exercises = [e for e in all_exercises if e.created_at and e.created_at.date() >= since]
        exercise_dates = set(e.created_at.date() for e in period_exercises if e.created_at)
        total_exercise_days = len(exercise_dates)

        total_calories_burned = sum(e.total_calories or 0 for e in period_exercises)
        total_exercise_minutes = sum(e.total_duration_minutes or 0 for e in period_exercises)

        # Streak hesaplama (ardışık gün sayısı)
        def calc_streak(dates_set):
            if not dates_set:
                return 0
            sorted_dates = sorted(dates_set, reverse=True)
            streak = 0
            current = date.today()
            for d in sorted_dates:
                if d == current or d == current - timedelta(days=1):
                    streak += 1
                    current = d
                else:
                    break
            return streak

        meal_streak = calc_streak(meal_dates)
        exercise_streak = calc_streak(exercise_dates)

        # Aylık yemek listesi (son 10 benzersiz yemek)
        seen_foods = set()
        monthly_meals_list = []
        for m in period_meals:
            if m.food_name not in seen_foods and len(monthly_meals_list) < 10:
                seen_foods.add(m.food_name)
                monthly_meals_list.append({
                    "food_name": m.food_name,
                    "calories": m.calories,
                    "health_score": m.health_score or 0,
                    "date": m.analyzed_at.date().isoformat() if m.analyzed_at else "",
                })

        # Aylık egzersiz listesi (son 10 plan)
        monthly_exercises_list = []
        for e in period_exercises[:10]:
            monthly_exercises_list.append({
                "total_duration": e.total_duration_minutes or 0,
                "total_calories": e.total_calories or 0,
                "exercise_count": len(e.exercises) if e.exercises else 0,
                "date": e.created_at.date().isoformat() if e.created_at else "",
                "has_feedback": bool(e.feedback),
            })

        return ProgressSummaryResponse(
            total_meal_days=total_meal_days,
            total_exercise_days=total_exercise_days,
            days_in_period=days,
            meal_streak=meal_streak,
            exercise_streak=exercise_streak,
            total_calories_burned=total_calories_burned,
            total_exercise_minutes=total_exercise_minutes,
            avg_health_score=round(avg_health_score, 1),
            monthly_meals=monthly_meals_list,
            monthly_exercises=monthly_exercises_list,
        )

    except Exception as e:
        logger.exception(f"Progress Summary Error: {e}")
        return ProgressSummaryResponse()
