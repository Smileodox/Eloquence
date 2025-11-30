from fastapi import APIRouter, HTTPException, status
from datetime import datetime
from app.models import (
    SendOTPRequest, SendOTPResponse,
    VerifyOTPRequest, VerifyOTPResponse, UserResponse,
    ErrorResponse
)
from app.services.otp_service import OTPService
from app.services.email_service import EmailService
from app.services.storage_service import StorageService
from app.config import settings

router = APIRouter(prefix="/auth", tags=["Authentication"])

# Initialize services
otp_service = OTPService()
email_service = EmailService()
storage_service = StorageService()

@router.post("/send-otp", response_model=SendOTPResponse)
async def send_otp(request: SendOTPRequest):
    """
    Send OTP code to user's email.
    Similar to Supabase's signInWithOTP endpoint.
    """

    # Check rate limiting
    latest_otp = storage_service.get_latest_otp(request.email)
    if latest_otp:
        created_at = datetime.fromisoformat(latest_otp.get('createdAt'))
        if otp_service.is_rate_limited(created_at):
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many requests. Please wait before requesting a new code."
            )

    # Clean up old OTPs for this email
    storage_service.delete_old_otps(request.email)

    # Generate OTP
    code = otp_service.generate_otp()
    expires_at = otp_service.calculate_expiry()

    # Save OTP to storage
    storage_service.save_otp(request.email, code, expires_at)

    # Send email
    email_sent = email_service.send_otp_email(request.email, code)

    if not email_sent:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to send email. Please try again."
        )

    return SendOTPResponse(
        success=True,
        message=f"OTP sent to {request.email}",
        expiresIn=settings.otp_expiry_minutes * 60
    )

@router.post("/verify-otp", response_model=VerifyOTPResponse)
async def verify_otp(request: VerifyOTPRequest):
    """
    Verify OTP code and create session.
    Similar to Supabase's verifyOTP endpoint.
    """

    # Get latest OTP for email
    otp_record = storage_service.get_latest_otp(request.email)

    if not otp_record:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No OTP found for this email. Please request a new code."
        )

    # Check if OTP is expired
    expires_at = datetime.fromisoformat(otp_record.get('expiresAt'))
    if otp_service.is_expired(expires_at):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="OTP code has expired. Please request a new code."
        )

    # Check max attempts
    attempts = otp_record.get('attempts', 0)
    if attempts >= settings.otp_max_attempts:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Too many failed attempts. Please request a new code."
        )

    # Verify code
    if otp_record.get('code') != request.code:
        # Increment attempt counter
        storage_service.increment_otp_attempts(request.email, otp_record['RowKey'])

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid OTP code. Please try again."
        )

    # Code is valid - mark as used
    storage_service.mark_otp_used(request.email, otp_record['RowKey'])

    # Create session
    session_token = otp_service.generate_session_token()
    session_expires = otp_service.calculate_session_expiry()
    session = storage_service.create_session(request.email, session_token, session_expires)

    # Build response
    user = UserResponse(
        id=session['userId'],
        email=request.email,
        createdAt=session['createdAt'],
        lastLoginAt=session['lastAccessedAt']
    )

    expires_in_seconds = int((session_expires - datetime.utcnow()).total_seconds())

    return VerifyOTPResponse(
        success=True,
        message="Login successful",
        user=user,
        accessToken=session_token,
        expiresIn=expires_in_seconds
    )

@router.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "service": "eloquence-auth-api"}
