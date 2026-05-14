import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
from database import DATABASE_URL

async def migrate():
    engine = create_async_engine(DATABASE_URL, echo=True)
    async with engine.begin() as conn:
        try:
            await conn.execute(text("ALTER TABLE users ADD COLUMN allergies JSON;"))
            print("Added allergies column.")
        except Exception as e:
            print(f"Error adding allergies: {e}")
            
        try:
            await conn.execute(text("ALTER TABLE users ADD COLUMN diet_preference VARCHAR(50);"))
            print("Added diet_preference column.")
        except Exception as e:
            print(f"Error adding diet_preference: {e}")

if __name__ == "__main__":
    asyncio.run(migrate())
