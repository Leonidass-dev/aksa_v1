"""
AKSA Backend — Veritabanı Bağlantı Katmanı
SQLAlchemy Async Engine + Session Factory
"""

import os
from dotenv import load_dotenv
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import DeclarativeBase

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    raise ValueError("DATABASE_URL environment değişkeni ayarlanmamış!")

# Render/Bulut platformları için düzeltme
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql+asyncpg://", 1)
elif DATABASE_URL.startswith("postgresql://") and "+asyncpg" not in DATABASE_URL:
    DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://", 1)

# ── Bağlantı Ayarları ──────────────────────────────────────────
connect_args = {}

if "sslmode=require" in DATABASE_URL:
    import ssl

    DATABASE_URL = DATABASE_URL.replace("?sslmode=require", "").replace(
        "&sslmode=require", ""
    )
    ctx = ssl.create_default_context()
    connect_args["ssl"] = ctx

# ── Engine & Session ───────────────────────────────────────────
engine = create_async_engine(
    DATABASE_URL,
    echo=False,
    connect_args=connect_args,
    pool_pre_ping=True,
    pool_recycle=3600,
)

async_session = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    pass


async def get_db():
    async with async_session() as session:
        try:
            yield session
        finally:
            await session.close()


async def init_db():
    """Uygulama başlarken tabloları oluşturur."""

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
