import secrets
import string
from datetime import datetime, timedelta
from typing import Optional
from app.config import settings

class OTPService:
    @staticmethod
    def generate_otp() -> str:
        """Generate a secure random 6-digit OTP code."""
        return ''.join(secrets.choice(string.digits) for _ in range(settings.otp_length))

    @staticmethod
    def generate_session_token() -> str:
        """Generate a secure session token (URL-safe random string)."""
        return secrets.token_urlsafe(32)

    @staticmethod
    def calculate_expiry() -> datetime:
        """Calculate OTP expiry time."""
        return datetime.utcnow() + timedelta(minutes=settings.otp_expiry_minutes)

    @staticmethod
    def calculate_session_expiry() -> datetime:
        """Calculate session expiry time."""
        return datetime.utcnow() + timedelta(days=settings.session_expiry_days)

    @staticmethod
    def is_expired(expiry_time: datetime) -> bool:
        """Check if a timestamp has expired."""
        return datetime.utcnow() > expiry_time

    @staticmethod
    def is_rate_limited(last_request_time: Optional[datetime]) -> bool:
        """Check if email is rate limited."""
        if not last_request_time:
            return False
        time_since_last = datetime.utcnow() - last_request_time
        return time_since_last.total_seconds() < (settings.otp_rate_limit_minutes * 60)
