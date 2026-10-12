from __future__ import annotations

import threading
from dataclasses import dataclass
from pathlib import Path

from cachetools import TTLCache

from file_service import metrics
from file_service.validation import object_path

CACHE_MAX_ITEMS = 1024
CACHE_MAX_FILE_BYTES = 1024 * 1024  # larger files aren't worth holding in pod memory


@dataclass(frozen=True)
class StoredFile:
    content: bytes
    content_type: str
    size: int


class FileNotFound(Exception):
    pass


class Storage:
    def __init__(self, local_path: str = "", gcs_bucket: str = "", cache_ttl_seconds: int = 0) -> None:
        self.local_path = local_path
        self.gcs_bucket = gcs_bucket
        self._gcs_client = None
        # Short-lived per-pod cache of hot files: keeps backend latency spikes off the
        # read path. Files may be up to cache_ttl_seconds stale; 0 disables it.
        self._cache = TTLCache(maxsize=CACHE_MAX_ITEMS, ttl=cache_ttl_seconds) if cache_ttl_seconds > 0 else None
        self._cache_lock = threading.Lock()  # handlers run in a threadpool

    def get_file(self, user_id: str, file_id: str) -> StoredFile:
        rel = object_path(user_id, file_id)
        if self._cache is None:
            return self._fetch(rel)
        with self._cache_lock:
            cached = self._cache.get(rel)
        if cached is not None:
            metrics.CACHE_LOOKUPS.labels("hit").inc()
            return cached
        metrics.CACHE_LOOKUPS.labels("miss").inc()
        stored = self._fetch(rel)
        if stored.size <= CACHE_MAX_FILE_BYTES:
            with self._cache_lock:
                self._cache[rel] = stored
        return stored

    def _fetch(self, rel: str) -> StoredFile:
        if self.local_path:
            return self._get_local(rel)
        if self.gcs_bucket:
            return self._get_gcs(rel)
        raise RuntimeError("Set LOCAL_STORAGE_PATH or GCS_BUCKET")

    def _get_local(self, rel: str) -> StoredFile:
        root = Path(self.local_path).resolve()
        path = (root / rel).resolve()
        # is_relative_to, not a string prefix check: /data-other must not pass for /data
        if not path.is_relative_to(root) or not path.is_file():
            raise FileNotFound(rel)
        content = path.read_bytes()
        return StoredFile(
            content=content,
            content_type=_guess_content_type(path.name),
            size=len(content),
        )

    def _get_gcs(self, rel: str) -> StoredFile:
        from google.api_core.exceptions import NotFound
        from google.cloud import storage

        if self._gcs_client is None:
            self._gcs_client = storage.Client()
        blob = self._gcs_client.bucket(self.gcs_bucket).blob(rel)
        # One round trip: download directly (content_type comes back with it) rather than
        # exists() + download, which doubles latency and its tail on every request.
        try:
            content = blob.download_as_bytes()
        except NotFound:
            raise FileNotFound(rel)
        return StoredFile(
            content=content,
            content_type=blob.content_type or _guess_content_type(rel),
            size=len(content),
        )


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