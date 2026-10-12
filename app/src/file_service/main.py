from __future__ import annotations

import time

from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.responses import PlainTextResponse

from file_service import __version__, metrics, request_log
from file_service.config import Settings, get_settings
from file_service.storage import FileNotFound, Storage
from file_service.validation import validate_id

app = FastAPI(title="File Retrieval Service", version=__version__)

_storage = None


def _init_storage(settings: Settings):
    global _storage
    if _storage is None:
        _storage = Storage(settings.local_storage_path, settings.gcs_bucket, settings.cache_ttl_seconds)
    return _storage


_UNOBSERVED = {"/healthz", "/metrics"}


# Status + latency of every request feed the SLOs (success rate, < 300ms):
# as Prometheus metrics and as one structured log line.
@app.middleware("http")
async def observe_request(request: Request, call_next):
    start = time.perf_counter()
    status = 500
    try:
        response = await call_next(request)
        status = response.status_code
        return response
    finally:
        if request.url.path not in _UNOBSERVED:
            seconds = time.perf_counter() - start
            route = getattr(request.scope.get("route"), "path", "unmatched")
            metrics.observe(request.method, route, status, seconds)
            request_log.record(request.method, request.url.path, status, seconds * 1000)


@app.get("/healthz", response_class=PlainTextResponse)
async def healthz() -> str:
    return "ok"


@app.get("/metrics", include_in_schema=False)
async def prometheus_metrics() -> Response:
    body, content_type = metrics.render()
    return Response(content=body, media_type=content_type)


# Plain `def`: storage calls block, so FastAPI runs this in its threadpool instead of
# on the event loop, where one slow GCS read would stall every other request.
@app.get("/v1/users/{user_id}/files/{file_id}")
def get_user_file(user_id: str, file_id: str) -> Response:
    settings = get_settings()
    storage = _init_storage(settings)
    user_id = validate_id(user_id, "user_id")
    file_id = validate_id(file_id, "file_id")
    try:
        stored = storage.get_file(user_id, file_id)
    except FileNotFound:
        raise HTTPException(status_code=404, detail="File not found")
    except Exception:
        raise HTTPException(status_code=502, detail="Storage error")
    return Response(content=stored.content, media_type=stored.content_type)
