import os
import httpx
import json
import logging
from typing import Optional, List, Dict, Any
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

# Config
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
PRIMARY_PROVIDER = os.getenv("PRIMARY_AI_PROVIDER", "ollama")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3")
OLLAMA_VISION_MODEL = os.getenv("OLLAMA_VISION_MODEL", "llava")

# URLs
GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"

import re

def clean_json_string(raw_text: str) -> str:
    """Metin içindeki JSON bloğunu güvenle çıkarır ve Markdown temizler."""
    # Markdown json bloğunu bul
    match = re.search(r'```(?:json)?\s*([\s\S]*?)\s*```', raw_text)
    if match:
        return match.group(1).strip()
    
    # Süslü veya köşeli parantez içini bul (Fallback)
    match = re.search(r'(\{[\s\S]*\}|\[[\s\S]*\])', raw_text)
    if match:
        return match.group(1).strip()
        
    return raw_text.strip()

async def summarize_memory(old_memory: str, new_user_msg: str, new_ai_msg: str) -> str:
    """Eski hafızayı yeni sohbetle birleştirip özetler."""
    system_prompt = (
        "Sen gelişmiş bir profil çıkarma (profiling) AI'ısın. "
        "Aşağıdaki eski hafıza ve yeni sohbet bağlamından kullanıcının kalıcı sağlık profilini (hastalıklar, "
        "diyet alışkanlıkları, vücut yapısı, son durumu vb.) kısa ve öz bir şekilde GÜNCELLE. "
        "Yalnızca kalıcı ve önemli bilgileri tut, gereksiz sohbet detaylarını at. Sadece Türkçe metin dön."
    )
    prompt = f"Eski Hafıza:\n{old_memory}\n\nYeni Konuşma:\nKullanıcı: {new_user_msg}\nAsistan: {new_ai_msg}"
    
    # Kendi ask_text fonksiyonumuzu kullanarak özetletiyoruz
    new_memory = await ask_text(prompt, system_prompt=system_prompt)
    return new_memory or old_memory


async def ask_text(prompt: str, system_prompt: str = "Sen uzman bir sağlık asistanısın. Yanıtlarını SADECE Türkçe olarak ver. Teknik terimlerin doğrudan Türkçe karşılıklarını kullan. Asla İngilizce kelime karıştırma.", history: List[Dict] = None, json_mode: bool = False) -> Optional[str]:
    """
    General purpose text generation with fallback logic.
    Providers: Ollama -> Groq -> Gemini
    """
    # Metin tabanlı işlemlerde sadece Ollama (ve gerekirse Groq) kullanıyoruz.
    providers = ["ollama", "groq"]

    for provider in providers:
        try:
            if provider == "ollama":
                res = await _call_ollama(prompt, system_prompt, history, json_mode)
                if res: return res
            elif provider == "groq" and GROQ_API_KEY:
                res = await _call_groq(prompt, system_prompt, history, json_mode)
                if res: return res
            elif provider == "gemini" and GEMINI_API_KEY:
                res = await _call_gemini(prompt, system_prompt, history)
                if res: return res
        except Exception as e:
            logger.error(f"Provider {provider} failed: {e}")
            continue
    
    return None

async def ask_vision(prompt: str, image_base64: str, json_mode: bool = True) -> Optional[str]:
    """
    Vision analysis with fallback logic.
    """
    # Görsel analizde SADECE Gemini kullanıyoruz (en yüksek doğruluk için).
    providers = ["gemini"]
    
    for provider in providers:
        try:
            if provider == "gemini" and GEMINI_API_KEY:
                res = await _call_gemini_vision(prompt, image_base64)
                if res: return res
            elif provider == "groq" and GROQ_API_KEY:
                res = await _call_groq_vision(prompt, image_base64, json_mode)
                if res: return res
            elif provider == "ollama":
                res = await _call_ollama_vision(prompt, image_base64, json_mode)
                if res: return res
        except Exception as e:
            logger.error(f"Vision Provider {provider} failed: {e}")
            continue
    return None

# --- Helper Methods ---

async def _call_ollama(prompt: str, system: str, history: List[Dict], json_mode: bool) -> Optional[str]:
    url = f"{OLLAMA_BASE_URL}/api/chat"
    messages = [{"role": "system", "content": system}]
    if history:
        messages.extend(history)
    messages.append({"role": "user", "content": prompt})

    payload = {
        "model": OLLAMA_MODEL,
        "messages": messages,
        "stream": False,
        "options": {"temperature": 0.4}
    }
    if json_mode:
        payload["format"] = "json"

    async with httpx.AsyncClient(timeout=60) as client:
        resp = await client.post(url, json=payload)
        if resp.status_code == 200:
            return resp.json()["message"]["content"]
    return None

async def _call_groq(prompt: str, system: str, history: List[Dict], json_mode: bool) -> Optional[str]:
    headers = {"Authorization": f"Bearer {GROQ_API_KEY}"}
    messages = [{"role": "system", "content": system}]
    if history:
        messages.extend(history)
    messages.append({"role": "user", "content": prompt})

    payload = {
        "model": "llama-3.3-70b-versatile" if json_mode else "llama-3.1-8b-instant",
        "messages": messages,
        "temperature": 0.4
    }
    if json_mode:
        payload["response_format"] = {"type": "json_object"}

    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(GROQ_URL, json=payload, headers=headers)
        if resp.status_code == 200:
            return resp.json()["choices"][0]["message"]["content"]
    return None

async def _call_gemini(prompt: str, system: str, history: List[Dict]) -> Optional[str]:
    url = f"{GEMINI_URL}?key={GEMINI_API_KEY}"
    # Gemini 1.5 doesn't have a simple 'system' role in the same way, we prepend it
    full_prompt = f"{system}\n\n"
    if history:
        for m in history:
            full_prompt += f"{m['role']}: {m['content']}\n"
    full_prompt += f"User: {prompt}"

    payload = {
        "contents": [{"parts": [{"text": full_prompt}]}],
        "generationConfig": {"temperature": 0.4}
    }
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(url, json=payload)
        if resp.status_code == 200:
            return resp.json()["candidates"][0]["content"]["parts"][0]["text"]
    return None

# --- Vision Helpers ---

async def _call_gemini_vision(prompt: str, image_base64: str) -> Optional[str]:
    url = f"{GEMINI_URL}?key={GEMINI_API_KEY}"
    payload = {
        "contents": [{
            "parts": [
                {"text": prompt},
                {"inlineData": {"mimeType": "image/jpeg", "data": image_base64}}
            ]
        }],
        "generationConfig": {"temperature": 0.2}
    }
    async with httpx.AsyncClient(timeout=90.0) as client:
        try:
            resp = await client.post(url, json=payload)
            if resp.status_code == 200:
                return resp.json()["candidates"][0]["content"]["parts"][0]["text"]
            else:
                logger.error(f"Gemini Vision API Hatası ({resp.status_code}): {resp.text}")
        except Exception as e:
            logger.error(f"Gemini Vision Bağlantı Hatası: {e}")
    return None

async def _call_groq_vision(prompt: str, image_base64: str, json_mode: bool) -> Optional[str]:
    headers = {"Authorization": f"Bearer {GROQ_API_KEY}"}
    payload = {
        "model": "llama-3.2-11b-vision-preview",
        "messages": [{
            "role": "user",
            "content": [
                {"type": "text", "text": prompt},
                {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_base64}"}}
            ]
        }],
        "temperature": 0.2
    }
    if json_mode:
        payload["response_format"] = {"type": "json_object"}

    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(GROQ_URL, json=payload, headers=headers)
        if resp.status_code == 200:
            return resp.json()["choices"][0]["message"]["content"]
    return None

async def _call_ollama_vision(prompt: str, image_base64: str, json_mode: bool) -> Optional[str]:
    url = f"{OLLAMA_BASE_URL}/api/chat"
    payload = {
        "model": OLLAMA_VISION_MODEL,
        "messages": [{
            "role": "user",
            "content": prompt,
            "images": [image_base64]
        }],
        "stream": False,
        "options": {"temperature": 0.2}
    }
    if json_mode:
        payload["format"] = "json"

    async with httpx.AsyncClient(timeout=60) as client:
        resp = await client.post(url, json=payload)
        if resp.status_code == 200:
            return resp.json()["message"]["content"]
    return None
