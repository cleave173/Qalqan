import asyncio
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import engine, SessionLocal
from app.models import User
from app.auth import hash_password
from sqlalchemy import select

async def reset_password(email: str, new_pass: str):
    print(f"Resetting password for {email} to {new_pass}...")
    async with SessionLocal() as db:
        result = await db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
        
        if not user:
            print(f"Error: User {email} not found.")
            return

        user.hashed_password = hash_password(new_pass)
        db.add(user)
        await db.commit()
        print(f"✅ Success: Password for {email} updated.")

if __name__ == "__main__":
    email = sys.argv[1] if len(sys.argv) > 1 else "test@gmail.com"
    new_pass = sys.argv[2] if len(sys.argv) > 2 else "123456"
    asyncio.run(reset_password(email, new_pass))
