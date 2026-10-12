from pathlib import Path

import pytest

from file_service.storage import FileNotFound, Storage


def test_local_storage_reads_file(tmp_path: Path):
    target = tmp_path / "users" / "u1" / "files"
    target.mkdir(parents=True)
    (target / "doc.txt").write_bytes(b"abc")

    storage = Storage(local_path=str(tmp_path))
    stored = storage.get_file("u1", "doc.txt")
    assert stored.content == b"abc"
    assert stored.size == 3
    assert "text/plain" in stored.content_type


def test_local_storage_missing_file(tmp_path: Path):
    storage = Storage(local_path=str(tmp_path))
    with pytest.raises(FileNotFound):
        storage.get_file("u1", "missing.txt")

def test_local_storage_rejects_sibling_directory(tmp_path: Path):
    # /data-other shares the /data string prefix but is outside the storage root
    root = tmp_path / "data"
    sibling = tmp_path / "data-other"
    root.mkdir()
    sibling.mkdir()
    (sibling / "secret.txt").write_bytes(b"nope")

    storage = Storage(local_path=str(root))
    with pytest.raises(FileNotFound):
        storage._get_local("../data-other/secret.txt")


def _write(root: Path, name: str, data: bytes) -> None:
    target = root / "users" / "u1" / "files"
    target.mkdir(parents=True, exist_ok=True)
    (target / name).write_bytes(data)


def test_cache_serves_repeat_reads_without_hitting_storage(tmp_path: Path):
    _write(tmp_path, "doc.txt", b"v1")
    storage = Storage(local_path=str(tmp_path), cache_ttl_seconds=30)
    assert storage.get_file("u1", "doc.txt").content == b"v1"

    _write(tmp_path, "doc.txt", b"v2")  # backend changes...
    assert storage.get_file("u1", "doc.txt").content == b"v1"  # ...cached copy served


def test_cache_disabled_with_zero_ttl(tmp_path: Path):
    _write(tmp_path, "doc.txt", b"v1")
    storage = Storage(local_path=str(tmp_path), cache_ttl_seconds=0)
    storage.get_file("u1", "doc.txt")
    _write(tmp_path, "doc.txt", b"v2")
    assert storage.get_file("u1", "doc.txt").content == b"v2"


def test_cache_skips_missing_and_large_files(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    import file_service.storage as storage_module

    monkeypatch.setattr(storage_module, "CACHE_MAX_FILE_BYTES", 2)
    storage = Storage(local_path=str(tmp_path), cache_ttl_seconds=30)

    with pytest.raises(FileNotFound):
        storage.get_file("u1", "late.txt")
    _write(tmp_path, "late.txt", b"ok")  # uploaded after a miss: visible at once
    assert storage.get_file("u1", "late.txt").content == b"ok"

    _write(tmp_path, "big.txt", b"large")
    storage.get_file("u1", "big.txt")
    _write(tmp_path, "big.txt", b"LARGE")  # over the size cap, so never cached
    assert storage.get_file("u1", "big.txt").content == b"LARGE"


def test_cache_hits_and_misses_are_counted(tmp_path: Path):
    from file_service.metrics import CACHE_LOOKUPS

    hits, misses = (CACHE_LOOKUPS.labels(r)._value.get() for r in ("hit", "miss"))
    _write(tmp_path, "doc.txt", b"v1")
    storage = Storage(local_path=str(tmp_path), cache_ttl_seconds=30)
    storage.get_file("u1", "doc.txt")
    storage.get_file("u1", "doc.txt")
    assert CACHE_LOOKUPS.labels("miss")._value.get() == misses + 1
    assert CACHE_LOOKUPS.labels("hit")._value.get() == hits + 1
