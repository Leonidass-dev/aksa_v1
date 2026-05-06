import asyncio
import asyncpg

async def main():
    conn = await asyncpg.connect('postgresql://postgres:123456asd@localhost:5432/aksa_db')
    await conn.execute('''
        CREATE TABLE IF NOT EXISTS user_memories (
            id SERIAL PRIMARY KEY,
            user_id INTEGER NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
            memory_summary TEXT NOT NULL DEFAULT '',
            last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
        );
        CREATE INDEX IF NOT EXISTS ix_user_memories_user_id ON user_memories (user_id);
    ''')
    print("Table user_memories created successfully!")
    await conn.close()

if __name__ == '__main__':
    asyncio.run(main())
