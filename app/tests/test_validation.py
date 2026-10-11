import pytest
from fastapi import HTTPException

from file_service.validation import object_path, validate_id


def test_validate_id_accepts_safe_values():
    assert validate_id("cust-1", "customer_id") == "cust-1"
    assert validate_id("file_01.json", "file_id") == "file_01.json"


@pytest.mark.parametrize(
    "value",
    ["../etc/passwd", "a/b", "a\\b", "", "bad id", "../../x"],
)
def test_validate_id_rejects_unsafe_values(value: str):
    with pytest.raises(HTTPException) as exc:
        validate_id(value, "file_id")
    assert exc.value.status_code == 400


def test_object_path_layout():
    assert object_path("u1", "f1") == "users/u1/files/f1"
