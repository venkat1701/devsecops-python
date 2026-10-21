from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    app_name: str = "TaskBoard API"
    app_version: str = "1.1.0"
    database_url: str = "postgresql+psycopg://taskboard:taskboard@localhost:5432/taskboard"
    cors_origins: list[str] = ["*"]
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

settings = Settings()
