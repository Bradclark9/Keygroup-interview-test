from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = Field(default="local", alias="APP_ENV")
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")

    # GCS bucket holding user files (objects: users/{id}/files/{file_id})
    gcs_bucket: str = Field(default="", alias="GCS_BUCKET")

    # When set, use local filesystem instead of GCS (no cloud creds needed)
    local_storage_path: str = Field(default="", alias="LOCAL_STORAGE_PATH")

    @property
    def use_local_storage(self) -> bool:
        return bool(self.local_storage_path)


@lru_cache
def get_settings() -> Settings:
    return Settings()