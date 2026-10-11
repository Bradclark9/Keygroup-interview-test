"""Per-request log lines: the raw data behind the SLOs.

Each request (except /healthz) is written to stdout as one JSON line in GKE's
structured-logging format. The cluster's logging agent ships stdout to Cloud
Logging, where "severity" becomes the entry severity and the rest jsonPayload.
"""

from __future__ import annotations

import json
import sys


def build_entry(method: str, path: str, status: int, latency_ms: float) -> dict:
    latency_ms = round(latency_ms, 2)
    return {
        "severity": "ERROR" if status >= 500 else "INFO",
        "message": f"{method} {path} {status} {latency_ms}ms",
        "method": method,
        "path": path,
        "status": status,
        "latency_ms": latency_ms,
    }


def record(method: str, path: str, status: int, latency_ms: float) -> None:
    sys.stdout.write(json.dumps(build_entry(method, path, status, latency_ms)) + "\n")
