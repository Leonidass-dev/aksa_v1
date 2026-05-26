"""
AKSA Backend — SQLAlchemy ORM Modelleri
Redmi Watch 4 tüm sensör verileri dahil.
"""

from datetime import datetime, timezone, timedelta
from sqlalchemy import (
    Column,
    Integer,
    Float,
    String,
    Boolean,
    Text,
    Date,
    DateTime,
    ForeignKey,
    JSON,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship
from database import Base


# Türkiye (UTC+3) saati yardımcısı
def get_turkey_time():
    return datetime.now(timezone(timedelta(hours=3)))


class User(Base):
    """Firebase UID ile eşleşen kullanıcı profili."""

    __tablename__ = "users"

    id = Column(Integer, primary_key=True, autoincrement=True)
    firebase_uid = Column(String(128), unique=True, nullable=False, index=True)
    email = Column(String(255), nullable=True)
    full_name = Column(String(255), nullable=True)
    age = Column(Integer, nullable=True)
    height = Column(Float, nullable=True)  # cm
    weight = Column(Float, nullable=True)  # kg
    gender = Column(String(10), nullable=True)  # M / F / O
    photo_url = Column(String(500), nullable=True)
    allergies = Column(JSON, nullable=True)  # ["fıstık", "glüten"] vb.
    diet_preference = Column(
        String(50), nullable=True
    )  # "vegan", "vejetaryen", "ketojenik" vb.
    created_at = Column(DateTime(timezone=True), default=get_turkey_time)
    updated_at = Column(
        DateTime(timezone=True), default=get_turkey_time, onupdate=get_turkey_time
    )

    # İlişkiler
    health_records = relationship(
        "HealthRecord", back_populates="user", cascade="all, delete-orphan"
    )
    risk_scores = relationship(
        "RiskScore", back_populates="user", cascade="all, delete-orphan"
    )
    meal_records = relationship(
        "MealRecord", back_populates="user", cascade="all, delete-orphan"
    )
    exercise_plans = relationship(
        "ExercisePlan", back_populates="user", cascade="all, delete-orphan"
    )
    chat_messages = relationship(
        "ChatMessage", back_populates="user", cascade="all, delete-orphan"
    )
    daily_diet_plans = relationship(
        "DailyDietPlan", back_populates="user", cascade="all, delete-orphan"
    )
    memory = relationship(
        "UserMemory", back_populates="user", uselist=False, cascade="all, delete-orphan"
    )


class UserMemory(Base):
    """Yapay Zeka Uzun Süreli Kullanıcı Hafızası."""

    __tablename__ = "user_memories"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(
        Integer, ForeignKey("users.id"), nullable=False, unique=True, index=True
    )
    memory_summary = Column(Text, nullable=False, default="")
    last_updated = Column(
        DateTime(timezone=True), default=get_turkey_time, onupdate=get_turkey_time
    )

    user = relationship("User", back_populates="memory")


class HealthRecord(Base):
    """
    Günlük sağlık verisi — Redmi Watch 4 tüm sensör verileri.
    Mi Fitness → Health Connect → Flutter health paketi → Backend.
    """

    __tablename__ = "health_records"
    __table_args__ = (UniqueConstraint("user_id", "record_date", name="uq_user_date"),)

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    record_date = Column(Date, nullable=False, index=True)

    # ── Aktivite ──────────────────────────────────────────────
    steps = Column(Float, default=0)  # Günlük adım (Akselerometre)
    active_calories = Column(Float, default=0)  # Aktif yakılan kalori (kcal)
    total_calories = Column(Float, default=0)  # Toplam yakılan kalori (kcal)
    distance_m = Column(Float, default=0)  # Yürüme/koşma mesafesi (metre)

    # ── Kardiyovasküler (PPG 4-kanal sensör) ───────────────────
    heart_rate = Column(Float, default=0)  # Ortalama nabız (bpm)
    resting_heart_rate = Column(Float, default=0)  # Dinlenik nabız (bpm)
    spo2 = Column(Float, default=0)  # Kan oksijen saturasyonu (%)

    # ── Tansiyon ──────────────────────────────────────────────
    systolic = Column(Float, default=0)  # Sistolik (mmHg)
    diastolic = Column(Float, default=0)  # Diastolik (mmHg)

    # ── Uyku (detaylı) ────────────────────────────────────────
    sleep_hours = Column(Float, default=0)  # Toplam uyku süresi (saat)
    sleep_deep_min = Column(Float, default=0)  # Derin uyku (dakika)
    sleep_light_min = Column(Float, default=0)  # Hafif uyku (dakika)
    sleep_rem_min = Column(Float, default=0)  # REM uyku (dakika)
    sleep_awake_min = Column(Float, default=0)  # Uyanıklık süresi (dakika)

    # ── Stres & Vücut ────────────────────────────────────────
    stress_level = Column(Float, default=0)  # Stres seviyesi (0-100, PPG→HRV)
    weight = Column(Float, default=0)  # Kilo (kg)

    # ── Yeni Özellikler ──────────────────────────────────────
    water_ml = Column(Float, default=0)  # Su içme (ml)
    mood = Column(String(50), default="neutral")  # Ruh hali (happy, sad, etc.)

    # ── Yapay Zeka & Filtrelenmiş Veriler (M2 - Pipeline) ────
    ml_features = Column(
        JSON, nullable=True
    )  # Sliding Window özellikleri (LSTM için hazır matris)

    # ── Meta ──────────────────────────────────────────────────
    source = Column(String(50), default="manual")  # "health_connect" | "manual"
    created_at = Column(DateTime(timezone=True), default=get_turkey_time)
    updated_at = Column(
        DateTime(timezone=True), default=get_turkey_time, onupdate=get_turkey_time
    )

    user = relationship("User", back_populates="health_records")


class RiskScore(Base):
    """Risk skoru hesaplama geçmişi."""

    __tablename__ = "risk_scores"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    score = Column(Float, nullable=False)
    level = Column(String(20), nullable=False)  # low / medium / high
    level_label = Column(Text, nullable=True)  # Değişti: TEXT
    top_factors = Column(JSON, nullable=True)  # [{name, contribution, description}]
    recommendations = Column(JSON, nullable=True)  # [str]
    model_version = Column(String(30), default="rule-v1")
    calculated_at = Column(DateTime(timezone=True), default=get_turkey_time)

    user = relationship("User", back_populates="risk_scores")


class MealRecord(Base):
    """Yemek fotoğrafı analizi geçmişi."""

    __tablename__ = "meal_records"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    food_name = Column(Text, nullable=False)
    portion = Column(Text, nullable=True)
    calories = Column(Integer, default=0)
    protein_g = Column(Float, default=0)
    carbs_g = Column(Float, default=0)
    fat_g = Column(Float, default=0)
    fiber_g = Column(Float, default=0)
    health_score = Column(Integer, default=0)
    recommendation = Column(Text, nullable=True)
    tags = Column(JSON, nullable=True)  # ["yüksek protein", ...]
    analyzed_at = Column(DateTime(timezone=True), default=get_turkey_time)

    user = relationship("User", back_populates="meal_records")


class ExercisePlan(Base):
    """AI egzersiz planı geçmişi."""

    __tablename__ = "exercise_plans"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    exercises = Column(JSON, nullable=True)  # [{title, duration, intensity, ...}]
    total_duration_minutes = Column(Integer, default=0)
    total_calories = Column(Integer, default=0)
    ai_advice = Column(Text, nullable=True)
    feedback = Column(Text, nullable=True)  # Değişti: TEXT
    created_at = Column(DateTime(timezone=True), default=get_turkey_time)

    user = relationship("User", back_populates="exercise_plans")


class ChatMessage(Base):
    """AI asistan konuşma geçmişi."""

    __tablename__ = "chat_messages"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    role = Column(
        String(50), nullable=False
    )  # Değişti: 20'den 50'ye çıkardık garantilemek için.
    content = Column(Text, nullable=False)
    is_safe = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), default=get_turkey_time)

    user = relationship("User", back_populates="chat_messages")


class DailyDietPlan(Base):
    """Günü birlik diyet planı önbelleği."""

    __tablename__ = "daily_diet_plans"
    __table_args__ = (UniqueConstraint("user_id", "plan_date", name="uq_user_diet_date"),)

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    plan_date = Column(Date, nullable=False, index=True)
    plan_data = Column(JSON, nullable=False)  # DietPlanResponse içeriği (JSON)
    created_at = Column(DateTime(timezone=True), default=get_turkey_time)

    user = relationship("User", back_populates="daily_diet_plans")
