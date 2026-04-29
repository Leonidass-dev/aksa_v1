import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
import os
from dotenv import load_dotenv

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql+asyncpg://postgres:123456asd@localhost:5432/aksa_db")

async def main():
    engine = create_async_engine(DATABASE_URL)
    async with engine.begin() as conn:
        try:
            await conn.execute(text("ALTER TABLE exercise_plans ADD COLUMN feedback VARCHAR(50);"))
            print("Successfully added feedback column!")
        except Exception as e:
            print(f"Error (maybe column already exists): {e}")
    await engine.dispose()

if __name__ == "__main__":
    asyncio.run(main())
