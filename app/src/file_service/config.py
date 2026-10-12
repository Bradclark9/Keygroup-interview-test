from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # GCS bucket holding user files (objects: users/{id}/files/{file_id})
    gcs_bucket: str = Field(default="", alias="GCS_BUCKET")

    # When set, use local filesystem instead of GCS (no cloud creds needed)
    local_storage_path: str = Field(default="", alias="LOCAL_STORAGE_PATH")

    # Per-pod cache of hot files, in seconds (0 = off)
    cache_ttl_seconds: int = Field(default=30, alias="CACHE_TTL_SECONDS")


@lru_cache
def get_settings() -> Settings:
    return Settings()
