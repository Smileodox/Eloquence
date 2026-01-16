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

    # Azure OpenAI Configuration
    azure_openai_endpoint: str = ""
    azure_openai_api_key: str = ""
    azure_openai_whisper_deployment: str = "whisper"
    azure_openai_whisper_api_version: str = "2024-06-01"
    azure_openai_gpt_deployment: str = "gpt-5-mini"
    azure_openai_gpt_api_version: str = "2025-04-01-preview"

    # LLM Access Control - comma-separated list of allowed emails
    llm_allowed_emails: str = ""

    class Config:
        env_file = ".env"

    @property
    def allowed_origins_list(self) -> List[str]:
        return [origin.strip() for origin in self.allowed_origins.split(",")]

    @property
    def llm_allowed_emails_list(self) -> List[str]:
        """Parse comma-separated email whitelist into a list."""
        if not self.llm_allowed_emails:
            return []
        return [email.strip().lower() for email in self.llm_allowed_emails.split(",") if email.strip()]

    def is_email_allowed_for_llm(self, email: str) -> bool:
        """Check if email is allowed to use LLM endpoints."""
        allowed = self.llm_allowed_emails_list
        if not allowed:
            # If no whitelist configured, allow all authenticated users
            return True
        return email.lower() in allowed

settings = Settings()
