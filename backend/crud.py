"""
AKSA Backend — CRUD İşlemleri
Veritabanı okuma/yazma fonksiyonları.
"""

from datetime import datetime, date, timedelta, timezone
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession

from db_models import (
    User,
    HealthRecord,
    RiskScore,
    MealRecord,
    ExercisePlan,
    ChatMessage,
    DailyDietPlan,
    UserMemory,
    get_turkey_time,
)


# ═══════════════════════════════════════════════════════════════════
#  USER
# ═══════════════════════════════════════════════════════════════════


async def get_or_create_user(
    db: AsyncSession,
    firebase_uid: str,
    email: str = "",
    full_name: str = "",
) -> User:
    """Firebase UID ile kullanıcıyı bul veya oluştur."""
    stmt = select(User).where(User.firebase_uid == firebase_uid)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if user is None:
        user = User(
            firebase_uid=firebase_uid,
            email=email,
            full_name=full_name,
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)

    return user


async def delete_user_completely(db: AsyncSession, user: User) -> bool:
    """Kullanıcının veritabanındaki tüm izlerini (cascade) siler."""
    try:
        await db.delete(user)
        await db.commit()
        return True
    except Exception as e:
        await db.rollback()
        import logging

        logging.error(f"Error deleting user {user.firebase_uid}: {e}")
        return False


# ═══════════════════════════════════════════════════════════════════
#  HEALTH RECORDS
async def get_user_memory(db: AsyncSession, user_id: int) -> UserMemory:
    """Kullanıcının AI hafızasını getir veya boş oluştur."""
    stmt = select(UserMemory).where(UserMemory.user_id == user_id)
    result = await db.execute(stmt)
    memory = result.scalar_one_or_none()
    if not memory:
        memory = UserMemory(user_id=user_id, memory_summary="")
        db.add(memory)
        await db.commit()
        await db.refresh(memory)
    return memory


async def update_user_memory(
    db: AsyncSession, user_id: int, new_summary: str
) -> UserMemory:
    """Kullanıcının AI hafızasını güncelle."""
    memory = await get_user_memory(db, user_id)
    memory.memory_summary = new_summary
    await db.commit()
    await db.refresh(memory)
    return memory


# ═══════════════════════════════════════════════════════════════════


async def save_health_record(
    db: AsyncSession,
    user: User,
    data: dict,
) -> HealthRecord:
    """Günlük sağlık verisini kaydet (upsert: aynı gün varsa güncelle)."""
    record_date = data.get("record_date", get_turkey_time().date())
    if isinstance(record_date, str):
        record_date = date.fromisoformat(record_date)

    stmt = select(HealthRecord).where(
        HealthRecord.user_id == user.id,
        HealthRecord.record_date == record_date,
    )
    result = await db.execute(stmt)
    record = result.scalar_one_or_none()

    if record is None:
        record = HealthRecord(user_id=user.id, record_date=record_date)
        db.add(record)

    # Alanları güncelle (None ise mevcut değeri koru, 0 meşru değer olabilir)
    for field in [
        "steps",
        "heart_rate",
        "resting_heart_rate",
        "spo2",
        "systolic",
        "diastolic",
        "sleep_hours",
        "sleep_deep_min",
        "sleep_light_min",
        "sleep_rem_min",
        "sleep_awake_min",
        "active_calories",
        "total_calories",
        "distance_m",
        "stress_level",
        "weight",
        "water_ml",
        "mood",
        "ml_features",
    ]:
        if field in data:
            setattr(record, field, data[field])

    if "source" in data:
        record.source = data["source"]

    record.updated_at = get_turkey_time()
    try:
        await db.commit()
        await db.refresh(record)
    except Exception as e:
        await db.rollback()
        raise e
    return record


async def get_health_records(
    db: AsyncSession,
    user: User,
    days: int = 7,
    offset: int = 0,
    limit: int = 365,
) -> list[HealthRecord]:
    """Son N günün sağlık kayıtlarını getir (sayfalamalı)."""
    since = get_turkey_time().date() - timedelta(days=days)
    stmt = (
        select(HealthRecord)
        .where(
            HealthRecord.user_id == user.id,
            HealthRecord.record_date >= since,
        )
        .order_by(desc(HealthRecord.record_date))
        .offset(offset)
        .limit(limit)
    )
    result = await db.execute(stmt)
    return list(result.scalars().all())


async def get_today_health(db: AsyncSession, user: User) -> HealthRecord | None:
    """Bugünün sağlık kaydını getir."""
    stmt = select(HealthRecord).where(
        HealthRecord.user_id == user.id,
        HealthRecord.record_date == get_turkey_time().date(),
    )
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


async def get_latest_health_record(db: AsyncSession, user: User) -> HealthRecord | None:
    """Kullanıcının en son (tarih olarak) sağlık kaydını getir."""
    stmt = (
        select(HealthRecord)
        .where(HealthRecord.user_id == user.id)
        .order_by(desc(HealthRecord.record_date))
        .limit(1)
    )
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


# ═══════════════════════════════════════════════════════════════════
#  RISK SCORES
# ═══════════════════════════════════════════════════════════════════


async def save_risk_score(
    db: AsyncSession,
    user: User,
    score: float,
    level: str,
    level_label: str,
    top_factors: list[dict],
    recommendations: list[str],
    model_version: str = "rule-v1",
) -> RiskScore:
    """Risk skoru sonucunu kaydet."""
    record = RiskScore(
        user_id=user.id,
        score=score,
        level=level,
        level_label=level_label,
        top_factors=top_factors,
        recommendations=recommendations,
        model_version=model_version,
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)
    return record


async def get_risk_history(
    db: AsyncSession,
    user: User,
    limit: int = 30,
    offset: int = 0,
) -> list[RiskScore]:
    """Risk skoru geçmişini getir."""
    stmt = (
        select(RiskScore)
        .where(RiskScore.user_id == user.id)
        .order_by(desc(RiskScore.calculated_at))
        .offset(offset)
        .limit(limit)
    )
    result = await db.execute(stmt)
    return list(result.scalars().all())


async def get_latest_risk_score(db: AsyncSession, user: User) -> RiskScore | None:
    """Kullanıcının en son hesaplanan risk skorunu getir."""
    stmt = (
        select(RiskScore)
        .where(RiskScore.user_id == user.id)
        .order_by(desc(RiskScore.calculated_at))
        .limit(1)
    )
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


# ═══════════════════════════════════════════════════════════════════
#  MEAL RECORDS
# ═══════════════════════════════════════════════════════════════════


async def save_meal_record(
    db: AsyncSession,
    user: User,
    food_name: str,
    portion: str,
    calories: int,
    protein_g: float,
    carbs_g: float,
    fat_g: float,
    fiber_g: float,
    health_score: int,
    recommendation: str,
    tags: list[str],
) -> MealRecord:
    """Yemek analizi sonucunu kaydet."""
    record = MealRecord(
        user_id=user.id,
        food_name=food_name,
        portion=portion,
        calories=calories,
        protein_g=protein_g,
        carbs_g=carbs_g,
        fat_g=fat_g,
        fiber_g=fiber_g,
        health_score=health_score,
        recommendation=recommendation,
        tags=tags,
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)
    return record


async def get_meal_history(
    db: AsyncSession,
    user: User,
    limit: int = 30,
    offset: int = 0,
) -> list[MealRecord]:
    """Yemek analiz geçmişini getir."""
    stmt = (
        select(MealRecord)
        .where(MealRecord.user_id == user.id)
        .order_by(desc(MealRecord.analyzed_at))
        .offset(offset)
        .limit(limit)
    )
    result = await db.execute(stmt)
    return list(result.scalars().all())


async def get_today_meals(db: AsyncSession, user: User) -> list[MealRecord]:
    """Bugün analiz edilen yemekleri getir."""
    today_start = get_turkey_time().replace(hour=0, minute=0, second=0, microsecond=0)
    stmt = (
        select(MealRecord)
        .where(
            MealRecord.user_id == user.id,
            MealRecord.analyzed_at >= today_start,
        )
        .order_by(desc(MealRecord.analyzed_at))
    )
    result = await db.execute(stmt)
    return list(result.scalars().all())


# ═══════════════════════════════════════════════════════════════════
#  EXERCISE PLANS
# ═══════════════════════════════════════════════════════════════════


async def save_exercise_plan(
    db: AsyncSession,
    user: User,
    exercises: list[dict],
    total_duration: int,
    total_calories: int,
    ai_advice: str,
) -> ExercisePlan:
    """Egzersiz planı sonucunu kaydet."""
    record = ExercisePlan(
        user_id=user.id,
        exercises=exercises,
        total_duration_minutes=total_duration,
        total_calories=total_calories,
        ai_advice=ai_advice,
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)
    return record


async def save_exercise_feedback(
    db: AsyncSession,
    user: User,
    feedback: str,
) -> ExercisePlan | None:
    """Son egzersiz planına geri bildirimi kaydeder."""
    stmt = (
        select(ExercisePlan)
        .where(ExercisePlan.user_id == user.id)
        .order_by(desc(ExercisePlan.created_at))
        .limit(1)
    )
    result = await db.execute(stmt)
    plan = result.scalar_one_or_none()

    if plan:
        plan.feedback = feedback
        await db.commit()
        return plan
    return None


async def get_last_exercise_plan(
    db: AsyncSession,
    user: User,
) -> ExercisePlan | None:
    """Kullanıcının en sonki egzersiz planını getirir."""
    stmt = (
        select(ExercisePlan)
        .where(ExercisePlan.user_id == user.id)
        .order_by(desc(ExercisePlan.created_at))
        .limit(1)
    )
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


# ═══════════════════════════════════════════════════════════════════
#  CHAT MESSAGES
# ═══════════════════════════════════════════════════════════════════


async def save_chat_message(
    db: AsyncSession,
    user: User,
    role: str,
    content: str,
    is_safe: bool = True,
) -> ChatMessage:
    """Chat mesajını kaydet."""
    msg = ChatMessage(
        user_id=user.id,
        role=role,
        content=content,
        is_safe=is_safe,
    )
    db.add(msg)
    await db.commit()
    await db.refresh(msg)
    return msg


async def get_chat_history(
    db: AsyncSession,
    user: User,
    limit: int = 50,
    offset: int = 0,
) -> list[ChatMessage]:
    """Chat geçmişini getir (eskiden yeniye)."""
    stmt = (
        select(ChatMessage)
        .where(ChatMessage.user_id == user.id)
        .order_by(desc(ChatMessage.created_at))
        .offset(offset)
        .limit(limit)
    )
    result = await db.execute(stmt)
    return list(result.scalars().all())[::-1]


async def clear_chat_history(db: AsyncSession, user: User) -> bool:
    """Kullanıcının tüm chat geçmişini siler."""
    from sqlalchemy import delete

    stmt = delete(ChatMessage).where(ChatMessage.user_id == user.id)
    await db.execute(stmt)
    await db.commit()
    return True


# ═══════════════════════════════════════════════════════════════════
#  DAILY DIET PLANS (Caching)
# ═══════════════════════════════════════════════════════════════════


async def get_daily_diet_plan(
    db: AsyncSession, user: User, target_date: date
) -> DailyDietPlan | None:
    """Belirli bir tarihteki diyet planını getir."""
    stmt = select(DailyDietPlan).where(
        DailyDietPlan.user_id == user.id, DailyDietPlan.plan_date == target_date
    )
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


async def save_daily_diet_plan(
    db: AsyncSession, user: User, plan_date: date, plan_data: dict
) -> DailyDietPlan:
    """Bir günlük diyet planını kaydet."""
    # Varsa güncelle yoksa oluştur
    stmt = select(DailyDietPlan).where(
        DailyDietPlan.user_id == user.id, DailyDietPlan.plan_date == plan_date
    )
    result = await db.execute(stmt)
    record = result.scalar_one_or_none()

    if record:
        record.plan_data = plan_data
    else:
        record = DailyDietPlan(
            user_id=user.id, plan_date=plan_date, plan_data=plan_data
        )
        db.add(record)

    await db.commit()
    await db.refresh(record)
    return record
