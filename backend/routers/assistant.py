import os
import httpx
import logging
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from dotenv import load_dotenv

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
async def chat_with_assistant(req: ChatRequest):
    """
    Semptom kontrolcüsü ve sağlık yaşam tarzı asistanı.
    """
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY eksik")

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
        
        return ChatResponse(
            reply=text.strip()
        )

    except Exception as e:
        logger.error(f"Assistant Chat Error: {e}")
        raise HTTPException(status_code=500, detail="Bir hata oluştu, lütfen tekrar deneyin.")
