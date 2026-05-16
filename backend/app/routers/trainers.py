"""Trainers router – speaking verification via Whisper STT."""
import os
import tempfile
from difflib import SequenceMatcher

from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from app.schemas import SpeakingVerifyResponse
from app.models import User
from app.auth import get_current_user

router = APIRouter(prefix="/trainers", tags=["trainers"])

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")


@router.post("/speaking/verify", response_model=SpeakingVerifyResponse)
async def verify_speaking(
    audio: UploadFile = File(...),
    target_text: str = Form(...),
    user: User = Depends(get_current_user),
):
    """Accept audio file, transcribe with Whisper, compare to target text."""
    if not OPENAI_API_KEY:
        # Fallback: return a simulated result when no API key configured
        return SpeakingVerifyResponse(
            transcription="[API key not configured]",
            target_text=target_text,
            accuracy=0.0,
            is_correct=False,
        )

    try:
        import openai
        client = openai.OpenAI(api_key=OPENAI_API_KEY)

        # Save uploaded file to temp
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            content = await audio.read()
            tmp.write(content)
            tmp_path = tmp.name

        # Transcribe with Whisper
        with open(tmp_path, "rb") as f:
            transcript = client.audio.transcriptions.create(
                model="whisper-1",
                file=f,
                response_format="text",
            )

        # Clean up
        os.unlink(tmp_path)

        transcription = transcript.strip() if isinstance(transcript, str) else str(transcript).strip()

        # Compare transcription to target
        accuracy = SequenceMatcher(
            None,
            transcription.lower(),
            target_text.lower(),
        ).ratio()

        return SpeakingVerifyResponse(
            transcription=transcription,
            target_text=target_text,
            accuracy=round(accuracy * 100, 1),
            is_correct=accuracy >= 0.75,
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Speech verification failed: {str(e)}")
