"""
LLM Proxy Router - Proxies Azure OpenAI API calls with authentication and email whitelist.
"""
from datetime import datetime
from fastapi import APIRouter, HTTPException, status, Header, UploadFile, File
from app.models import (
    TranscriptionResponse,
    SpeechAnalysisRequest, SpeechAnalysisResponse,
    GestureAnalysisRequest, GestureAnalysisResponse,
    KeyFrameAnnotationRequest, KeyFrameAnnotationResponse,
)
from app.services.storage_service import StorageService
from app.services.azure_openai_service import AzureOpenAIService
from app.config import settings

router = APIRouter(prefix="/llm", tags=["LLM Proxy"])

# Initialize services
storage_service = StorageService()
openai_service = AzureOpenAIService()


async def validate_session_and_whitelist(authorization: str) -> dict:
    """
    Validate session token and check email whitelist.

    Args:
        authorization: Authorization header value (Bearer <token>)

    Returns:
        Session dict if valid

    Raises:
        HTTPException if invalid or not whitelisted
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header. Expected: Bearer <token>",
        )

    token = authorization[7:]  # Remove "Bearer " prefix

    # Validate session
    session = storage_service.get_session(token)
    if not session:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired session token.",
        )

    # Check expiration
    expires_at = datetime.fromisoformat(session.get("expiresAt"))
    if expires_at < datetime.utcnow():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session has expired. Please log in again.",
        )

    # Check email whitelist
    email = session.get("PartitionKey", "")  # Email is stored as PartitionKey
    if not settings.is_email_allowed_for_llm(email):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your account is not authorized to use LLM features.",
        )

    return session


@router.post("/transcribe", response_model=TranscriptionResponse)
async def transcribe_audio(
    file: UploadFile = File(...),
    authorization: str = Header(...),
):
    """
    Transcribe audio using Azure Whisper API.

    Expects multipart form data with audio file.
    Requires valid session token and whitelisted email.
    """
    await validate_session_and_whitelist(authorization)

    # Read file content
    audio_data = await file.read()

    if len(audio_data) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Empty audio file.",
        )

    # Limit file size (10MB)
    if len(audio_data) > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Audio file too large. Maximum size is 10MB.",
        )

    try:
        result = await openai_service.transcribe_audio(
            audio_data=audio_data,
            filename=file.filename or "audio.m4a",
        )

        # Validate transcription is not empty
        text = result.get("text", "").strip()
        if not text:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Transcription returned empty. Audio may be silent or unclear.",
            )

        return TranscriptionResponse(
            text=text,
            duration=result.get("duration"),
            language=result.get("language"),
        )

    except HTTPException:
        raise
    except Exception as e:
        print(f"Transcription error: {e}")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Azure OpenAI API error: {str(e)}",
        )


@router.post("/analyze-speech", response_model=SpeechAnalysisResponse)
async def analyze_speech(
    request: SpeechAnalysisRequest,
    authorization: str = Header(...),
):
    """
    Generate speech feedback using Azure GPT.

    Requires valid session token and whitelisted email.
    """
    await validate_session_and_whitelist(authorization)

    try:
        result = await openai_service.analyze_speech(
            transcription=request.transcription,
            word_count=request.wordCount,
            duration=request.duration,
            words_per_minute=request.wordsPerMinute,
            pause_count=request.pauseCount,
            sentence_count=request.sentenceCount,
            average_sentence_length=request.averageSentenceLength,
        )

        return SpeechAnalysisResponse(
            toneScore=result["toneScore"],
            confidenceScore=result["confidenceScore"],
            enthusiasmScore=result["enthusiasmScore"],
            clarityScore=result["clarityScore"],
            feedback=result["feedback"],
            keyStrengths=result["keyStrengths"],
            areasToImprove=result["areasToImprove"],
        )

    except HTTPException:
        raise
    except Exception as e:
        print(f"Speech analysis error: {e}")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Azure OpenAI API error: {str(e)}",
        )


@router.post("/analyze-gesture", response_model=GestureAnalysisResponse)
async def analyze_gesture(
    request: GestureAnalysisRequest,
    authorization: str = Header(...),
):
    """
    Generate gesture feedback using Azure GPT.

    Requires valid session token and whitelisted email.
    """
    await validate_session_and_whitelist(authorization)

    try:
        result = await openai_service.analyze_gesture(
            transcription=request.transcription,
            smile_frequency=request.smileFrequency,
            expression_variety=request.expressionVariety,
            engagement_level=request.engagementLevel,
            confidence_score=request.confidenceScore,
            movement_consistency=request.movementConsistency,
            stability_score=request.stabilityScore,
            camera_focus_percentage=request.cameraFocusPercentage,
            reading_notes_percentage=request.readingNotesPercentage,
            gaze_stability_score=request.gazeStabilityScore,
        )

        return GestureAnalysisResponse(
            gestureFeedback=result["gestureFeedback"],
            gestureStrength=result["gestureStrength"],
            gestureImprovement=result["gestureImprovement"],
            isTemplateFallback=False,
        )

    except HTTPException:
        raise
    except Exception as e:
        print(f"Gesture analysis error: {e}")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Azure OpenAI API error: {str(e)}",
        )


@router.post("/annotate-frame", response_model=KeyFrameAnnotationResponse)
async def annotate_key_frame(
    request: KeyFrameAnnotationRequest,
    authorization: str = Header(...),
):
    """
    Generate key frame annotation using Azure GPT Vision.

    Requires valid session token and whitelisted email.
    """
    await validate_session_and_whitelist(authorization)

    # Validate base64 image size (roughly 200KB limit for base64)
    if len(request.imageBase64) > 300 * 1024:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Image too large. Maximum size is ~200KB.",
        )

    try:
        annotation = await openai_service.annotate_key_frame(
            image_base64=request.imageBase64,
            frame_type=request.frameType,
            transcription_excerpt=request.transcriptionExcerpt,
            timestamp=request.timestamp,
        )

        return KeyFrameAnnotationResponse(annotation=annotation)

    except HTTPException:
        raise
    except Exception as e:
        print(f"Frame annotation error: {e}")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Azure OpenAI API error: {str(e)}",
        )
