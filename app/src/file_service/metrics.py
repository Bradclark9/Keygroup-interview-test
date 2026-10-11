"""Prometheus metrics behind the SLOs: success rate and % of requests within 300ms.

Scraped from /metrics by Prometheus (Google Managed Prometheus on real GKE).
One uvicorn worker per pod, so the default in-process registry is accurate.
"""

from __future__ import annotations

from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

REQUESTS = Counter(
    "http_requests_total",
    "HTTP requests by route and status code",
    ["method", "route", "status"],
)

# 0.3 is a bucket boundary so "within 300ms" is an exact count, not an estimate
LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency",
    ["method", "route"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.2, 0.3, 0.5, 1.0, 2.5, 5.0),
)


def observe(method: str, route: str, status: int, seconds: float) -> None:
    REQUESTS.labels(method, route, str(status)).inc()
    LATENCY.labels(method, route).observe(seconds)


def render() -> tuple[bytes, str]:
    return generate_latest(), CONTENT_TYPE_LATEST
