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
def make_client(monkeypatch: pytest.MonkeyPatch):
    """Build a TestClient for the app with the given env, on a fresh storage backend."""
    from file_service import main
    from file_service.config import get_settings

    def _make(**env: str) -> TestClient:
        for key in ("LOCAL_STORAGE_PATH", "GCS_BUCKET"):
            monkeypatch.delenv(key, raising=False)
        monkeypatch.setenv("CACHE_TTL_SECONDS", "0")  # each test sees the backend as-is
        for key, value in env.items():
            monkeypatch.setenv(key, value)
        get_settings.cache_clear()
        main._storage = None  # the app builds its backend once; rebuild it from this env
        return TestClient(main.app)

    yield _make

    get_settings.cache_clear()
    main._storage = None


@pytest.fixture()
def client(storage_root: Path, make_client):
    with make_client(LOCAL_STORAGE_PATH=str(storage_root)) as test_client:
        yield test_client
