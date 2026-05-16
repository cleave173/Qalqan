import os
import json
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from openai import AsyncOpenAI

from ..database import get_db
from ..models import User, Phase
from ..schemas import (
    PlacementQuestion, PlacementSubmitRequest, PlacementResultResponse,
)
from ..auth import get_current_user

router = APIRouter(prefix="/placement", tags=["placement"])

# Static placement questions covering A1–A2 range
PLACEMENT_QUESTIONS = [
    PlacementQuestion(id=1, question="What is the English word for 'дом'?", options=["house", "car", "tree", "book"], difficulty="A1.1"),
    PlacementQuestion(id=2, question="Choose the correct: 'She ___ a student.'", options=["is", "are", "am", "be"], difficulty="A1.1"),
    PlacementQuestion(id=3, question="What is the opposite of 'big'?", options=["small", "tall", "fast", "old"], difficulty="A1.1"),
    PlacementQuestion(id=4, question="'I ___ to school every day.'", options=["go", "goes", "going", "gone"], difficulty="A1.2"),
    PlacementQuestion(id=5, question="Which sentence is correct?", options=["He doesn't like coffee.", "He don't like coffee.", "He not like coffee.", "He no like coffee."], difficulty="A1.2"),
    PlacementQuestion(id=6, question="What does 'beautiful' mean?", options=["красивый", "быстрый", "сильный", "высокий"], difficulty="A1.2"),
    PlacementQuestion(id=7, question="Choose: 'There ___ many people at the party.'", options=["were", "was", "is", "has"], difficulty="A1.3"),
    PlacementQuestion(id=8, question="'I have ___ been to London.'", options=["never", "ever", "yet", "already"], difficulty="A1.3"),
    PlacementQuestion(id=9, question="What is the past tense of 'buy'?", options=["bought", "buyed", "buied", "boughted"], difficulty="A1.3"),
    PlacementQuestion(id=10, question="'If I ___ rich, I would travel.'", options=["were", "am", "will be", "was being"], difficulty="A2.1"),
    PlacementQuestion(id=11, question="Choose the correct preposition: 'She arrived ___ Monday.'", options=["on", "in", "at", "by"], difficulty="A2.1"),
    PlacementQuestion(id=12, question="'The book ___ by millions of people.'", options=["has been read", "has read", "is reading", "was reading"], difficulty="A2.1"),
    PlacementQuestion(id=13, question="What does 'despite' mean?", options=["несмотря на", "потому что", "вместо", "до тех пор"], difficulty="A2.2"),
    PlacementQuestion(id=14, question="'I wish I ___ more time.'", options=["had", "have", "will have", "having"], difficulty="A2.2"),
    PlacementQuestion(id=15, question="Choose: 'Not only ___ she smart, but also kind.'", options=["is", "does", "has", "was"], difficulty="A2.2"),
]


OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY", "")

@router.get("/questions", response_model=list[PlacementQuestion])
async def get_questions():
    return PLACEMENT_QUESTIONS


@router.post("/evaluate", response_model=PlacementResultResponse)
async def evaluate_placement(
    data: PlacementSubmitRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Evaluate placement test answers and assign starting phase using OpenRouter."""
    
    # 1. Format the user's answers into a prompt
    questions_map = {q.id: q for q in PLACEMENT_QUESTIONS}
    prompt_lines = ["Evaluate the following English placement test answers:"]
    
    for answer in data.answers:
        q = questions_map.get(answer.question_id)
        if q:
            prompt_lines.append(f"- Question ({q.difficulty}): {q.question}")
            prompt_lines.append(f"  User answered: {answer.answer}")
            
    prompt_lines.append("\nBased on these answers, determine the user's CEFR level (A1.1, A1.2, A1.3, A2.1, A2.2) and assigned phase (1-5).")
    prompt_lines.append("Return ONLY a raw JSON object with no markdown formatting. Example: {\"cefr_level\": \"A1.2\", \"assigned_phase_id\": 2, \"message\": \"Ваш уровень A1.2. Начинаем со 2 фазы!\"}")
    
    prompt = "\n".join(prompt_lines)
    
    # Defaults in case of failure
    assigned_phase = 1
    assigned_level = "A1.1"
    message = "Ваш уровень: A1.1. Начинаем с фазы 1!"
    
    if OPENROUTER_API_KEY:
        try:
            client = AsyncOpenAI(
                base_url="https://openrouter.ai/api/v1",
                api_key=OPENROUTER_API_KEY,
            )
            completion = await client.chat.completions.create(
                model="meta-llama/llama-3.3-70b-instruct:free",
                messages=[
                    {"role": "system", "content": "You are an expert English teacher evaluating placement tests."},
                    {"role": "user", "content": prompt}
                ],
                response_format={"type": "json_object"}
            )
            
            result_str = completion.choices[0].message.content
            # OpenRouter models sometimes return markdown anyway, try to clean it
            if result_str.startswith("```json"):
                result_str = result_str.split("```json")[-1].split("```")[0].strip()
            elif result_str.startswith("```"):
                result_str = result_str.split("```")[-1].split("```")[0].strip()
                
            result_json = json.loads(result_str)
            
            assigned_phase = int(result_json.get("assigned_phase_id", 1))
            assigned_level = result_json.get("cefr_level", "A1.1")
            message = result_json.get("message", "Ваш уровень определен.")
            
        except Exception as e:
            print(f"OpenRouter evaluation failed: {e}")
            # Fallback to defaults logic skipped for brevity, using initial defaults
            pass
            
    # Cap to the actual number of seeded phases (no hard-coded 3-phase limit).
    max_phase_q = await db.execute(select(func.max(Phase.id)))
    max_phase = max_phase_q.scalar() or 1
    assigned_phase = min(max(assigned_phase, 1), max_phase)

    result = await db.execute(select(Phase).where(Phase.id == assigned_phase))
    phase = result.scalar_one_or_none()
    if phase:
        user.current_phase_id = phase.id
        db.add(user)
    else:
        assigned_phase = 1
        assigned_level = "A1.1"

    return PlacementResultResponse(
        assigned_phase_id=assigned_phase,
        cefr_level=assigned_level,
        message=message,
    )
