import asyncio
import asyncpg

async def main():
    conn = await asyncpg.connect('postgresql://postgres:123456asd@localhost:5432/aksa_db')
    await conn.execute('''
        ALTER TABLE meal_records 
        ALTER COLUMN food_name TYPE TEXT,
        ALTER COLUMN portion TYPE TEXT;
    ''')
    print("Table updated successfully!")
    await conn.close()

if __name__ == '__main__':
    asyncio.run(main())
