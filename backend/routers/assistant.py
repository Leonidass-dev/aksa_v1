import os
import httpx
import logging
from fastapi import APIRouter, HTTPException, Depends, Query, BackgroundTasks
from pydantic import BaseModel, Field
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
    message: str = Field(description="Kullanıcının yazdığı mesaj (örn: başım ağrıyor, ne yapmalıyım?)")

class ChatResponse(BaseModel):
    reply: str
    is_safe: bool = True

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
            context_parts.append(f"🧠 KULLANICI PROFİLİ (Geçmişten Öğrenilenler):\n{user_memory.memory_summary}\n")

        # Profil Bilgileri
        if user.age or user.weight or user.height:
            profile_info = []
            if user.age: profile_info.append(f"Yaş: {user.age}")
            if user.gender: profile_info.append(f"Cinsiyet: {'Erkek' if user.gender == 'M' else 'Kadın'}")
            if user.height: profile_info.append(f"Boy: {user.height} cm")
            if user.weight: profile_info.append(f"Kilo: {user.weight} kg")
            if user.weight and user.height and user.height > 0:
                bmi = user.weight / ((user.height / 100) ** 2)
                profile_info.append(f"BMI (VKE): {bmi:.1f}")
            context_parts.append("📋 Profil: " + ", ".join(profile_info))

        if today_record:
            # Aktivite
            context_parts.append(f"👣 Adım: {int(today_record.steps)}")
            if today_record.active_calories > 0:
                context_parts.append(f"🔥 Aktif Kalori: {int(today_record.active_calories)} kcal")
            if today_record.distance_m > 0:
                context_parts.append(f"📏 Mesafe: {int(today_record.distance_m)} m")

            # Kardiyovasküler
            if today_record.heart_rate > 0:
                context_parts.append(f"❤️ Nabız: {int(today_record.heart_rate)} bpm")
            if today_record.resting_heart_rate > 0:
                context_parts.append(f"💓 Dinlenik Nabız: {int(today_record.resting_heart_rate)} bpm")
            if today_record.spo2 > 0:
                context_parts.append(f"🩸 SpO2: %{int(today_record.spo2)}")

            # Tansiyon
            if today_record.systolic > 0 or today_record.diastolic > 0:
                context_parts.append(f"⚖️ Tansiyon: {int(today_record.systolic)}/{int(today_record.diastolic)} mmHg")

            # Uyku
            if today_record.sleep_hours > 0:
                sleep_info = f"🌙 Uyku: {today_record.sleep_hours:.1f} saat"
                details = []
                if today_record.sleep_deep_min > 0: details.append(f"Derin: {int(today_record.sleep_deep_min)} dk")
                if today_record.sleep_light_min > 0: details.append(f"Hafif: {int(today_record.sleep_light_min)} dk")
                if today_record.sleep_rem_min > 0: details.append(f"REM: {int(today_record.sleep_rem_min)} dk")
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
            context_parts.append("⚠️ Bugüne ait sensör verisi henüz senkronize edilmemiş.")

        # Bugünkü Yemekler
        if today_meals:
            total_cal = sum(m.calories for m in today_meals)
            total_protein = sum(m.protein_g for m in today_meals)
            total_carbs = sum(m.carbs_g for m in today_meals)
            total_fat = sum(m.fat_g for m in today_meals)
            meal_names = [m.food_name for m in today_meals]
            context_parts.append(f"🍽️ Bugün Yenen ({len(today_meals)} öğün): {', '.join(meal_names)}")
            context_parts.append(f"🔢 Toplam Alınan Kalori: {total_cal} kcal (P: {total_protein:.0f}g, K: {total_carbs:.0f}g, Y: {total_fat:.0f}g)")
        else:
            context_parts.append("🍽️ Bugün henüz öğün kaydı yok.")

        # Risk Skoru
        if latest_risk:
            context_parts.append(f"📊 Risk Skoru: {latest_risk.score}/100 ({latest_risk.level_label})")
            if latest_risk.top_factors:
                factor_names = [f.get("name", "") if isinstance(f, dict) else "" for f in latest_risk.top_factors[:3]]
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
        full_prompt = f"{context}\n\nKullanıcı: {req.message}"
        
        reply = await ask_text(
            prompt=full_prompt,
            system_prompt=PROMPT,
            history=history,
            json_mode=False
        )

        if not reply:
            raise HTTPException(status_code=502, detail="Yapay zeka servisi şu an yanıt veremiyor.")

        # Asistan yanıtını DB'ye kaydet
        await crud.save_chat_message(db, user, role="assistant", content=reply)

        # Arkaplanda hafızayı güncelle
        background_tasks.add_task(
            _bg_update_memory,
            user.id,
            user_memory.memory_summary,
            req.message,
            reply
        )

        return ChatResponse(reply=reply)

    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Assistant Chat Error")
        raise HTTPException(status_code=500, detail="Bir hata oluştu, lütfen tekrar deneyin.")


@router.get("/history", response_model=list[ChatHistoryItem])
async def chat_history(
    limit: int = Query(default=50, ge=1, le=200),
    uid: str = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Kullanıcının chat geçmişini getirir (eskiden yeniye)."""
    user = await crud.get_or_create_user(db, uid)
    messages = await crud.get_chat_history(db, user, limit)
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
