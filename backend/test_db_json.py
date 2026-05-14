import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy import select
from database import DATABASE_URL
from db_models import ExercisePlan, DailyDietPlan

async def check():
    engine = create_async_engine(DATABASE_URL)
    async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with async_session() as session:
        result = await session.execute(select(ExercisePlan).limit(1))
        plan = result.scalar_one_or_none()
        if plan:
            print("ExercisePlan:")
            print("Type of exercises:", type(plan.exercises))
            print("Content:", repr(plan.exercises)[:100])
        else:
            print("No ExercisePlan found")
            
        result_diet = await session.execute(select(DailyDietPlan).limit(1))
        diet = result_diet.scalar_one_or_none()
        if diet:
            print("DailyDietPlan:")
            print("Type of plan_data:", type(diet.plan_data))
            print("Content:", repr(diet.plan_data)[:100])
        else:
            print("No DailyDietPlan found")

if __name__ == "__main__":
    asyncio.run(check())
