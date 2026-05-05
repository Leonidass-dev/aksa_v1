import asyncio
import asyncpg

async def main():
    conn = await asyncpg.connect('postgresql://postgres:123456asd@localhost:5432/aksa_db')
    await conn.execute('''
        ALTER TABLE risk_scores ALTER COLUMN level_label TYPE TEXT;
        ALTER TABLE exercise_plans ALTER COLUMN feedback TYPE TEXT;
        ALTER TABLE chat_messages ALTER COLUMN role TYPE VARCHAR(50);
    ''')
    print("Table updated successfully for risk_scores, exercise_plans, and chat_messages!")
    await conn.close()

if __name__ == '__main__':
    asyncio.run(main())
