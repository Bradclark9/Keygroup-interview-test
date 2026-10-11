import re

from fastapi import HTTPException, status

# Strict IDs: no path traversal, no unexpected characters
_ID_PATTERN = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$")


def validate_id(value: str, field: str) -> str:
    if not _ID_PATTERN.match(value):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid {field}: must be 1-128 chars of [A-Za-z0-9._-]",
        )
    if ".." in value or "/" in value or "\\" in value:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid {field}: path separators not allowed",
        )
    return value


def object_path(user_id: str, file_id: str) -> str:
    return f"users/{user_id}/files/{file_id}"
