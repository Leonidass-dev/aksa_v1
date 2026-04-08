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

load_dotenv()

logger = logging.getLogger(__name__)

router = APIRouter()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
GEMINI_URL = (
    "https://generativelanguage.googleapis.com/v1beta/models/"
    "gemini-2.5-flash:generateContent"
)

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
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY eksik")

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
        context += f"- Risk Seviyesi: {latest_risk.level_name}\n"
    context += "--------------------------------\n"

    # Kullanıcı mesajını DB'ye kaydet
    await crud.save_chat_message(db, user, role="user", content=req.message)

    payload = {
        "contents": [
            {
                "parts": [
                    {"text": PROMPT + context + "\nKullanıcı Sorusu: " + req.message}
                ]
            }
        ],
        "generationConfig": {
            "temperature": 0.4
        },
    }

    try:
        import asyncio
        max_retries = 3
        
        for attempt in range(max_retries):
            async with httpx.AsyncClient(timeout=30) as client:
                resp = await client.post(
                    f"{GEMINI_URL}?key={GEMINI_API_KEY}",
                    json=payload,
                )
                
            if resp.status_code == 200:
                break
                
            if resp.status_code == 503 and attempt < max_retries - 1:
                await asyncio.sleep(2)
                continue

        if resp.status_code != 200:
            error_msg = "Bilinmeyen API hatası"
            try:
                data = resp.json()
                error_msg = data.get("error", {}).get("message", resp.text[:200])
            except Exception:
                error_msg = resp.text[:200]
                
            logger.error(f"Gemini API Error [{resp.status_code}]: {error_msg}")
            
            if resp.status_code == 503:
                detail = "Google sunucularında aşırı yoğunluk var. Lütfen biraz bekleyip tekrar deneyin."
            elif resp.status_code == 429:
                detail = "API kullanım limitinize ulaştınız. (Kota aşıldı veya çok sık istek atıldı)."
            elif resp.status_code in [401, 403]:
                detail = "Gemini API Anahtarı (API_KEY) yetkisiz veya hatalı."
            elif resp.status_code == 404:
                detail = "Kullanılan yapay zeka modeli bulunamadı."
            elif resp.status_code == 400:
                detail = f"Geçersiz istek gönderildi. Detay: {error_msg}"
            else:
                detail = f"Gemini API Sunucu Hatası ({resp.status_code}): {error_msg}"
                
            raise HTTPException(status_code=502, detail=detail)

        text = resp.json()["candidates"][0]["content"]["parts"][0]["text"]
        reply = text.strip()

        # Asistan yanıtını DB'ye kaydet
        await crud.save_chat_message(db, user, role="assistant", content=reply)

        return ChatResponse(reply=reply)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Assistant Chat Error: {e}")
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
