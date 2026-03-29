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
    "gemini-3-flash-preview:generateContent"
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
    Mesajları ve yanıtları PostgreSQL'e kaydeder.
    """
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY eksik")

    # Kullanıcı mesajını DB'ye kaydet
    user = await crud.get_or_create_user(db, uid)
    await crud.save_chat_message(db, user, role="user", content=req.message)

    payload = {
        "contents": [
            {
                "parts": [
                    {"text": PROMPT + req.message}
                ]
            }
        ],
        "generationConfig": {
            "temperature": 0.4  # Biraz yaratıcılık iyidir ancak çok uçmamalı
        },
    }

    try:
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(
                f"{GEMINI_URL}?key={GEMINI_API_KEY}",
                json=payload,
            )

        if resp.status_code != 200:
            logger.error(f"Gemini API hatası: {resp.text[:200]}")
            raise HTTPException(
                status_code=502,
                detail="Asistana şu an ulaşılamıyor. Lütfen daha sonra tekrar deneyin.",
            )

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
