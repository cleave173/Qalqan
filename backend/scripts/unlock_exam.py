import asyncio
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import SessionLocal
from app.models import User, Lesson, UserCompletedLesson, Category
from sqlalchemy import select

async def unlock_phase_exam(email: str, phase_id: int):
    print(f"Unlocking exam for Phase {phase_id} for user {email}...")
    async with SessionLocal() as db:
        # Find user
        result = await db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
        if not user:
            print(f"❌ Error: User {email} not found.")
            return

        # Find all lessons in the phase
        lessons_q = await db.execute(
            select(Lesson.id)
            .join(Category, Category.id == Lesson.category_id)
            .where(Category.phase_id == phase_id)
        )
        lesson_ids = [row[0] for row in lessons_q.all()]

        if not lesson_ids:
            print(f"❌ Error: No lessons found in phase {phase_id}.")
            return

        # Check existing completions
        existing_q = await db.execute(
            select(UserCompletedLesson.lesson_id)
            .where(UserCompletedLesson.user_id == user.id)
            .where(UserCompletedLesson.lesson_id.in_(lesson_ids))
        )
        existing_ids = {row[0] for row in existing_q.all()}

        # Mark remaining as complete
        added = 0
        for lid in lesson_ids:
            if lid not in existing_ids:
                db.add(UserCompletedLesson(user_id=user.id, lesson_id=lid))
                added += 1

        if added > 0:
            await db.commit()
            print(f"✅ Success: Marked {added} lessons as complete.")
        else:
            print(f"✅ Nothing to do. User {email} already completed all lessons in Phase {phase_id}.")

        print(f"User {email} can now go to the Home Screen, refresh, and the 'Take Exam' button should be active for Phase {phase_id}.")

if __name__ == "__main__":
    email = sys.argv[1] if len(sys.argv) > 1 else "test@gmail.com"
    phase_id = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    asyncio.run(unlock_phase_exam(email, phase_id))
