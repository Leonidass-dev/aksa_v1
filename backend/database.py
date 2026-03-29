"""
AKSA Backend — Veritabanı Bağlantı Katmanı
SQLAlchemy Async Engine + Session Factory
"""

import os
from dotenv import load_dotenv
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import DeclarativeBase

load_dotenv()

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "sqlite+aiosqlite:///./aksa_dev.db",
)

import ssl

connect_args = {}
# SQLAlchemy'de asyncpg için sslmode string parametresi sorun yaratabilir
# "?sslmode=require" url'de kalırsa hata veriyor. Gerekirse URL'den temizleyip args olarak veriyoruz.
if "sslmode=require" in DATABASE_URL:
    DATABASE_URL = DATABASE_URL.replace("?sslmode=require", "")
    DATABASE_URL = DATABASE_URL.replace("&sslmode=require", "")
    # asyncpg için SSL context
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    connect_args["ssl"] = ctx

if DATABASE_URL.startswith("sqlite"):
    connect_args = {"check_same_thread": False}

engine = create_async_engine(
    DATABASE_URL,
    echo=False,
    connect_args=connect_args,
)

async_session = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    pass


async def get_db():
    """FastAPI dependency — her istekte yeni session açar, sonra kapatır."""
    async with async_session() as session:
        try:
            yield session
        finally:
            await session.close()


async def init_db():
    """Uygulama başlarken tabloları oluşturur."""
    async with engine.begin() as conn:
        from db_models import (
            User, HealthRecord, RiskScore,
            MealRecord, ExercisePlan, ChatMessage,
        )
        await conn.run_sync(Base.metadata.create_all)
