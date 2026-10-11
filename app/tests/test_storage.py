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