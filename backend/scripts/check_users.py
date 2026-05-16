import asyncio
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import engine, SessionLocal
from app.models import User
from sqlalchemy import select

async def check():
    try:
        async with SessionLocal() as db:
            result = await db.execute(select(User))
            users = result.scalars().all()
            print(f"--- DB User List ---")
            print(f"Total users: {len(users)}")
            for u in users:
                print(f"User: {u.email}, ID: {u.id}")
            print(f"--------------------")
    except Exception as e:
        print(f"Error checking DB: {e}")

if __name__ == "__main__":
    asyncio.run(check())
