from pathlib import Path

import pytest
from fastapi.testclient import TestClient


@pytest.fixture()
def storage_root(tmp_path: Path) -> Path:
    user = tmp_path / "users" / "user-1" / "files"
    user.mkdir(parents=True)
    (user / "profile.json").write_text('{"name":"Ada"}', encoding="utf-8")
    (user / "notes.txt").write_text("hello", encoding="utf-8")
    return tmp_path


@pytest.fixture()
def client(storage_root: Path, monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("APP_ENV", "test")
    monkeypatch.setenv("LOCAL_STORAGE_PATH", str(storage_root))
    monkeypatch.delenv("GCS_BUCKET", raising=False)

    from file_service.config import get_settings

    get_settings.cache_clear()

    from file_service.main import app

    with TestClient(app) as test_client:
        yield test_client

    get_settings.cache_clear()