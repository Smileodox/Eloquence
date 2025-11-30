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
