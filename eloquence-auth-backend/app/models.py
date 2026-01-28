from __future__ import annotations
from pydantic import BaseModel, EmailStr, Field
from datetime import datetime
from typing import Optional

# Request Models
class SendOTPRequest(BaseModel):
    email: EmailStr

class VerifyOTPRequest(BaseModel):
    email: EmailStr
    code: str = Field(..., min_length=6, max_length=6, pattern="^[0-9]{6}$")

# Response Models
class SendOTPResponse(BaseModel):
    success: bool
    message: str
    expiresIn: int  # seconds

class UserResponse(BaseModel):
    id: str
    email: str
    createdAt: str
    lastLoginAt: str

class VerifyOTPResponse(BaseModel):
    success: bool
    message: str
    user: Optional[UserResponse] = None
    accessToken: Optional[str] = None
    expiresIn: Optional[int] = None  # seconds

# Error Response
class ErrorResponse(BaseModel):
    error: str
    message: str
    code: int


# LLM Proxy Models

class TranscriptionResponse(BaseModel):
    text: str
    duration: Optional[float] = None
    language: Optional[str] = None


class GPTMessage(BaseModel):
    role: str
    content: str


class SpeechAnalysisRequest(BaseModel):
    transcription: str
    wordCount: int
    duration: float
    wordsPerMinute: int
    pauseCount: int
    sentenceCount: int
    averageSentenceLength: float


class SpeechAnalysisResponse(BaseModel):
    toneScore: int
    confidenceScore: int
    enthusiasmScore: int
    clarityScore: int
    feedback: str
    keyStrengths: list[str]
    areasToImprove: list[str]
    toneStrength: Optional[str] = None
    toneImprovement: Optional[str] = None
    pacingStrength: Optional[str] = None
    pacingImprovement: Optional[str] = None


class GestureAnalysisRequest(BaseModel):
    transcription: str
    smileFrequency: float
    expressionVariety: float
    engagementLevel: float
    confidenceScore: float
    movementConsistency: float
    stabilityScore: float
    cameraFocusPercentage: float
    readingNotesPercentage: float
    gazeStabilityScore: float


class GestureAnalysisResponse(BaseModel):
    gestureFeedback: str
    gestureStrength: str
    gestureImprovement: str
    isTemplateFallback: bool = False


class KeyFrameAnnotationRequest(BaseModel):
    imageBase64: str
    frameType: str  # bestFacial, bestOverall, improveFacial, etc.
    transcriptionExcerpt: str
    timestamp: float


class KeyFrameAnnotationResponse(BaseModel):
    annotation: str
