from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import logging

from file_service.validation import object_path

log = logging.getLogger(__name__)


@dataclass(frozen=True)
class StoredFile:
    content: bytes
    content_type: str
    size: int


class FileNotFound(Exception):
    pass


class Storage:
    def __init__(self, local_path: str = "", gcs_bucket: str = "") -> None:
        self.local_path = local_path
        self.gcs_bucket = gcs_bucket
        self._gcs_client = None

    def get_file(self, user_id: str, file_id: str) -> StoredFile:
        rel = object_path(user_id, file_id)
        if self.local_path:
            return self._get_local(rel)
        if self.gcs_bucket:
            return self._get_gcs(rel)
        raise RuntimeError("Set LOCAL_STORAGE_PATH or GCS_BUCKET")

    def _get_local(self, rel: str) -> StoredFile:
        path = (Path(self.local_path) / rel).resolve()
        if not str(path).startswith(str(Path(self.local_path).resolve())):
            raise FileNotFound(rel)
        if not path.is_file():
            raise FileNotFound(rel)
        content = path.read_bytes()
        return StoredFile(
            content=content,
            content_type=_guess_content_type(path.name),
            size=len(content),
        )

    def _get_gcs(self, rel: str) -> StoredFile:
        from google.cloud import storage

        if self._gcs_client is None:
            self._gcs_client = storage.Client()
        bucket = self._gcs_client.bucket(self.gcs_bucket)
        blob = bucket.blob(rel)
        if not blob.exists():
            raise FileNotFound(rel)
        content = blob.download_as_bytes()
        return StoredFile(
            content=content,
            content_type=blob.content_type or _guess_content_type(rel),
            size=len(content),
        )


def build_storage(local_path: str, gcs_bucket: str) -> Storage:
    log.info("storage_backend", extra={"backend": "local" if local_path else "gcs", "path": local_path, "bucket": gcs_bucket})
    return Storage(local_path, gcs_bucket)


def _guess_content_type(name: str) -> str:
    lower = name.lower()
    if lower.endswith(".json"):
        return "application/json"
    if lower.endswith(".pdf"):
        return "application/pdf"
    if lower.endswith((".txt", ".csv", ".log")):
        return "text/plain; charset=utf-8"
    if lower.endswith(".png"):
        return "image/png"
    if lower.endswith((".jpg", ".jpeg")):
        return "image/jpeg"
    return "application/octet-stream"