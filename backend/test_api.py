import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy import select, func
from database import DATABASE_URL
from db_models import ChatMessage


async def check():
    engine = create_async_engine(DATABASE_URL)
    async_session = async_sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )
    async with async_session() as session:
        result = await session.execute(select(func.count(ChatMessage.id)))
        count = result.scalar()
        print("Remaining ChatMessages:", count)


if __name__ == "__main__":
    asyncio.run(check())
