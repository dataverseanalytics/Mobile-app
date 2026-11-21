from functools import lru_cache
from typing import Literal

from pydantic import AliasChoices, Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """All configuration comes from environment variables (or `.env`)."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    env: Literal["development", "test", "production"] = "development"
    app_name: str = "NutriLens API"

    database_url: str = "postgresql+asyncpg://nutrilens:nutrilens@localhost:5434/nutrilens"

    # Auth
    jwt_secret: str = Field(default="dev-only-jwt-secret-change-me-in-production", min_length=32)
    admin_jwt_secret: str = Field(default="dev-only-admin-secret-change-me-in-production", min_length=32)
    access_token_minutes: int = 30
    refresh_token_days: int = 60
    admin_token_hours: int = 12

    # OTP
    otp_length: int = 6
    otp_ttl_seconds: int = 300
    otp_resend_seconds: int = 30
    otp_max_attempts: int = 5
    otp_max_per_hour: int = 5
    # Numbers that always accept OTP_TEST_CODE (app-store review, QA).
    otp_test_numbers: list[str] = []
    otp_test_code: str = "123456"

    # SMS delivery: "console" logs codes (development); "apitxt" or "twilio" send real SMS.
    sms_provider: Literal["console", "apitxt", "twilio"] = "console"
    # APITxT (apitxt.com) unified OTP API. We generate the code; APITxT delivers it.
    apitxt_auth_key: str = ""
    apitxt_base_url: str = "https://apitxt.com"
    apitxt_channel: Literal["sms", "whatsapp", "voice"] = "sms"
    # Your SMS template id from the APITxT dashboard (blank = their default OTP template).
    apitxt_template_id: int | None = None
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    twilio_verify_service_sid: str = ""

    # All AI features (photo scan, meal text parsing, suggestions):
    # "mock" = built-in sample answers (dev/tests), "openai" = OpenAI models.
    ai_provider: Literal["mock", "openai"] = Field(
        default="mock", validation_alias=AliasChoices("AI_PROVIDER", "SCAN_PROVIDER")
    )
    openai_api_key: str = ""
    openai_model: str = "gpt-5.5"  # vision: meal photos
    openai_text_model: str = "gpt-5.4-mini"  # text: meal descriptions, suggestions
    # Reasoning models only (e.g. gpt-5.x): none|minimal|low|medium|high.
    # Leave empty for non-reasoning models such as gpt-4.1 / gpt-4o.
    openai_reasoning_effort: Literal["", "none", "minimal", "low", "medium", "high"] = ""
    max_upload_mb: int = 8

    # Payments — Razorpay (Dashboard → Settings → API Keys / Webhooks)
    razorpay_key_id: str = ""
    razorpay_key_secret: str = ""
    razorpay_webhook_secret: str = ""

    # CORS for the admin panel / web build
    cors_origins: list[str] = ["http://localhost:3000"]

    # First admin account, created by `python -m app.seed`
    admin_email: str = "admin@nutrilens.app"
    admin_password: str = "ChangeMe123!"

    @model_validator(mode="after")
    def _production_safety(self) -> "Settings":
        if self.sms_provider == "apitxt" and not self.apitxt_auth_key:
            raise ValueError("SMS_PROVIDER=apitxt needs APITXT_AUTH_KEY")
        if self.env == "production":
            if "dev-only" in self.jwt_secret or "dev-only" in self.admin_jwt_secret:
                raise ValueError("Set real JWT_SECRET and ADMIN_JWT_SECRET in production")
            if self.admin_password == "ChangeMe123!":
                raise ValueError("Set a real ADMIN_PASSWORD in production")
        return self

    @property
    def is_dev(self) -> bool:
        return self.env != "production"


@lru_cache
def get_settings() -> Settings:
    return Settings()
