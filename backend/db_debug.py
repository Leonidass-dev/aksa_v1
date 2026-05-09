import asyncio
import traceback
from database import engine

async def debug_db():
    print("Testing DB connection...")
    try:
        async with engine.begin() as conn:
            print("Connected!")
            await conn.run_sync(lambda x: print("Sync run successful"))
    except Exception:
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(debug_db())
