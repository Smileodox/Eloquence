from pydantic_settings import BaseSettings
from typing import List

class Settings(BaseSettings):
    # Azure Communication Services
    azure_communication_connection_string: str
    azure_email_from_address: str

    # Azure Table Storage
    azure_storage_connection_string: str

    # OTP Configuration
    otp_length: int = 6
    otp_expiry_minutes: int = 10
    otp_max_attempts: int = 3
    otp_rate_limit_minutes: int = 1

    # Session Configuration
    session_expiry_days: int = 30

    # CORS
    allowed_origins: str = "*"

    # Environment
    environment: str = "production"

    class Config:
        env_file = ".env"

    @property
    def allowed_origins_list(self) -> List[str]:
        return [origin.strip() for origin in self.allowed_origins.split(",")]

settings = Settings()
