import asyncio
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from database import init_db


async def run_init():
    print("PostgreSQL Neon veritabanına bağlanılıyor ve tablolar oluşturuluyor...")
    try:
        await init_db()
        print(
            "[BAŞARILI] Tüm veritabanı tabloları Neon üzerinde başarıyla oluşturuldu!"
        )
    except Exception as e:
        print(f"[HATA] Veritabanı bağlantısı veya tablo oluşturma başarısız: {e}")


if __name__ == "__main__":
    asyncio.run(run_init())
