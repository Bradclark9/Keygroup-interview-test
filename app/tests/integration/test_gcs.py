"""Integration tests: the real google-cloud-storage code path against a GCS API (floci).

Unit tests serve files from a local folder; these upload real objects to the bucket and read
them back through Storage and through the API. Run with `make integration-test`, which sets
GCS_BUCKET (terraform output) and STORAGE_EMULATOR_HOST (floci).
"""

import os
import uuid

import pytest
from google.cloud import storage

from file_service.storage import FileNotFound, Storage

pytestmark = pytest.mark.integration

BUCKET = os.environ.get("GCS_BUCKET", "")


@pytest.fixture(scope="module")
def bucket():
    assert BUCKET and os.environ.get("STORAGE_EMULATOR_HOST"), (
        "set GCS_BUCKET and STORAGE_EMULATOR_HOST (make integration-test does this)"
    )
    return storage.Client().bucket(BUCKET)


@pytest.fixture()
def user_id(bucket):
    """A unique user with two files in the bucket, removed after the test."""
    user = f"it-{uuid.uuid4().hex[:8]}"
    blobs = [
        (f"users/{user}/files/report.json", b'{"total": 42}', "application/json"),
        (f"users/{user}/files/notes.txt", b"hello from gcs", "text/plain"),
    ]
    for name, data, content_type in blobs:
        bucket.blob(name).upload_from_string(data, content_type=content_type)
    yield user
    for name, _, _ in blobs:
        bucket.blob(name).delete()


def test_storage_reads_object_and_content_type_from_gcs(user_id):
    stored = Storage(gcs_bucket=BUCKET).get_file(user_id, "report.json")
    assert stored.content == b'{"total": 42}'
    assert stored.content_type == "application/json"
    assert stored.size == len(b'{"total": 42}')


def test_storage_missing_object_raises_not_found(user_id):
    with pytest.raises(FileNotFound):
        Storage(gcs_bucket=BUCKET).get_file(user_id, "missing.txt")


def test_api_serves_files_from_gcs(user_id, make_client):
    with make_client(GCS_BUCKET=BUCKET) as client:
        report = client.get(f"/v1/users/{user_id}/files/report.json")
        notes = client.get(f"/v1/users/{user_id}/files/notes.txt")
        missing = client.get(f"/v1/users/{user_id}/files/missing.txt")
        other_user = client.get("/v1/users/it-nobody/files/report.json")

    assert (report.status_code, report.json()) == (200, {"total": 42})
    assert report.headers["content-type"] == "application/json"
    assert (notes.status_code, notes.content) == (200, b"hello from gcs")
    assert notes.headers["content-type"].startswith("text/plain")
    assert missing.status_code == 404
    assert other_user.status_code == 404  # one user's path never reaches another's files


def test_cache_serves_repeat_reads_after_object_changes(bucket, user_id):
    gcs = Storage(gcs_bucket=BUCKET, cache_ttl_seconds=30)
    assert gcs.get_file(user_id, "notes.txt").content == b"hello from gcs"
    bucket.blob(f"users/{user_id}/files/notes.txt").upload_from_string(b"changed", content_type="text/plain")
    assert gcs.get_file(user_id, "notes.txt").content == b"hello from gcs"
    assert Storage(gcs_bucket=BUCKET).get_file(user_id, "notes.txt").content == b"changed"
