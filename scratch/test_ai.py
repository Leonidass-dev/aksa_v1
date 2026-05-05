import asyncio
import os
import sys

# Add backend to path
sys.path.append(os.path.join(os.getcwd(), "backend"))

from services.ai_service import ask_text

async def main():
    print("Testing AI Service with Ollama (Qwen)...")
    prompt = "Merhaba, nasılsın? AKSA projesi hakkında ne biliyorsun?"
    system_prompt = "Sen AKSA isimli bir sağlık asistanısın."
    
    try:
        response = await ask_text(prompt, system_prompt)
        if response:
            print("\nAI Response:")
            print("-" * 20)
            print(response)
            print("-" * 20)
        else:
            print("\nNo response from AI service. Make sure Ollama is running.")
    except Exception as e:
        print(f"\nError: {e}")

if __name__ == "__main__":
    asyncio.run(main())
