from file_service.metrics import LATENCY, REQUESTS

ROUTE = "/v1/users/{user_id}/files/{file_id}"


def _requests(status: str) -> float:
    return REQUESTS.labels("GET", ROUTE, status)._value.get()


def _within_300ms() -> float:
    sample = next(
        s for s in LATENCY.collect()[0].samples
        if s.name.endswith("_bucket") and s.labels == {"method": "GET", "route": ROUTE, "le": "0.3"}
    )
    return sample.value


def test_requests_counted_by_route_template_and_status(client):
    ok, missing, fast = _requests("200"), _requests("404"), _within_300ms()

    client.get("/v1/users/user-1/files/profile.json")
    client.get("/v1/users/user-1/files/missing.json")

    assert _requests("200") == ok + 1
    assert _requests("404") == missing + 1
    assert _within_300ms() == fast + 2


def test_metrics_endpoint_exposes_slo_series(client):
    client.get("/v1/users/user-1/files/profile.json")
    body = client.get("/metrics").text
    assert 'http_requests_total{method="GET",route="/v1/users/{user_id}/files/{file_id}",status="200"}' in body
    assert 'http_request_duration_seconds_bucket{le="0.3"' in body


def test_health_and_metrics_are_not_counted(client):
    before = sum(s.value for s in REQUESTS.collect()[0].samples if s.name == "http_requests_total")
    client.get("/healthz")
    client.get("/metrics")
    after = sum(s.value for s in REQUESTS.collect()[0].samples if s.name == "http_requests_total")
    assert after == before
