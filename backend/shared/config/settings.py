from pydantic_settings import BaseSettings, SettingsConfigDict
from functools import lru_cache
from typing import List


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # App
    APP_ENV: str = "development"
    APP_NAME: str = "FillFormAI"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False

    # Security
    SECRET_KEY: str
    JWT_ACCESS_EXPIRE_MINUTES: int = 60
    JWT_REFRESH_EXPIRE_DAYS: int = 30
    ENCRYPTION_KEY: str = ""
    BCRYPT_ROUNDS: int = 12

    # PostgreSQL
    DATABASE_URL: str

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"

    # MongoDB
    MONGO_URL: str = "mongodb://localhost:27017"
    MONGO_DB: str = "fillformai_docs"

    # AWS
    AWS_ACCESS_KEY_ID: str = ""
    AWS_SECRET_ACCESS_KEY: str = ""
    AWS_REGION: str = "ap-south-1"
    S3_BUCKET: str = "fillformai-documents"
    S3_ENDPOINT_URL: str = ""

    # AI
    OPENAI_API_KEY: str = ""
    OPENAI_MODEL: str = "gpt-4o"
    ANTHROPIC_API_KEY: str = ""
    CLAUDE_MODEL: str = "claude-sonnet-4-6"
    EMBEDDING_MODEL: str = "text-embedding-3-small"
    PINECONE_API_KEY: str = ""
    PINECONE_INDEX: str = "fillformai-opportunities"

    # Communication
    TWILIO_ACCOUNT_SID: str = ""
    TWILIO_AUTH_TOKEN: str = ""
    TWILIO_PHONE_NUMBER: str = ""
    WHATSAPP_BUSINESS_TOKEN: str = ""
    WHATSAPP_PHONE_NUMBER_ID: str = ""
    SENDGRID_API_KEY: str = ""
    FROM_EMAIL: str = "noreply@fillformai.in"

    # Payments
    RAZORPAY_KEY_ID: str = ""
    RAZORPAY_KEY_SECRET: str = ""
    RAZORPAY_WEBHOOK_SECRET: str = ""
    FCM_SERVER_KEY: str = ""

    # OAuth
    GOOGLE_CLIENT_ID: str = ""
    GOOGLE_CLIENT_SECRET: str = ""

    # DigiLocker
    DIGILOCKER_CLIENT_ID: str = ""
    DIGILOCKER_CLIENT_SECRET: str = ""
    DIGILOCKER_REDIRECT_URI: str = ""

    # Features
    ENABLE_AI_FORM_FILL: bool = True
    ENABLE_CAREER_TWIN: bool = True
    ENABLE_AGENT_MARKETPLACE: bool = True
    ENABLE_WHATSAPP_NOTIFICATIONS: bool = False

    # Service URLs
    AUTH_SERVICE_URL: str = "http://localhost:8001"
    PROFILE_SERVICE_URL: str = "http://localhost:8002"
    OPPORTUNITY_SERVICE_URL: str = "http://localhost:8003"
    APPLICATION_SERVICE_URL: str = "http://localhost:8004"
    DOCUMENT_SERVICE_URL: str = "http://localhost:8005"
    AGENT_SERVICE_URL: str = "http://localhost:8006"
    NOTIFICATION_SERVICE_URL: str = "http://localhost:8007"
    AI_SERVICE_URL: str = "http://localhost:8008"
    PAYMENT_SERVICE_URL: str = "http://localhost:8009"

    # CORS
    CORS_ORIGINS: str = "http://localhost:3000,http://localhost:8080"

    # Kafka
    KAFKA_BOOTSTRAP_SERVERS: str = "localhost:9092"
    KAFKA_GROUP_ID: str = "fillformai-consumers"

    @property
    def cors_origins_list(self) -> List[str]:
        return [o.strip() for o in self.CORS_ORIGINS.split(",")]

    @property
    def is_production(self) -> bool:
        return self.APP_ENV == "production"


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
