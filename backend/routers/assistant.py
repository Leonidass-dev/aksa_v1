import os
import httpx
import logging
from fastapi import APIRouter, HTTPException, Depends, Query
from pydantic import BaseModel, Field
from dotenv import load_dotenv
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from auth import get_current_user
import crud
from services.ai_service import ask_text

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

Kullanıcının Mesajı: 
"""

@router.post("/chat", response_model=ChatResponse)
async def chat_with_assistant(
    req: ChatRequest,
    uid: str = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Semptom kontrolcüsü ve sağlık yaşam tarzı asistanı.
    Context-Aware: Kullanıcının son verilerini kullanarak yanıt verir.
    """
    try:
        # Kullanıcıyı ve son verilerini çek
        user = await crud.get_or_create_user(db, uid)
        latest_record = await crud.get_latest_health_record(db, user)
        latest_risk = await crud.get_latest_risk_score(db, user)

        # Context (Bağlam) Oluşturma
        context = "\n--- KULLANICI SAĞLIK BAĞLAMI ---\n"
        if latest_record:
            context += f"- Bugünkü Adım: {latest_record.steps}\n"
            context += f"- Kalp Atışı (Ort): {latest_record.heart_rate} bpm\n"
            context += f"- Uyku Süresi: {latest_record.sleep_hours} saat\n"
            context += f"- İçilen Su: {latest_record.water_ml} ml\n"
            context += f"- Ruh Hali: {latest_record.mood or 'Belirtilmedi'}\n"
        if latest_risk:
            context += f"- Hesaplanan Risk Skoru: {latest_risk.score} / 100\n"
            context += f"- Risk Seviyesi: {latest_risk.level_label}\n"
        context += "--------------------------------\n"

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
