import json

from file_service import request_log


def test_requests_are_logged_with_status_and_latency(client, capsys):
    client.get("/v1/users/user-1/files/profile.json")
    client.get("/v1/users/user-1/files/missing.json")

    lines = [json.loads(line) for line in capsys.readouterr().out.splitlines()]
    assert [(l["path"], l["status"], l["severity"]) for l in lines] == [
        ("/v1/users/user-1/files/profile.json", 200, "INFO"),
        ("/v1/users/user-1/files/missing.json", 404, "INFO"),
    ]
    assert all(l["latency_ms"] >= 0 for l in lines)


def test_healthz_is_not_logged(client, capsys):
    client.get("/healthz")
    assert capsys.readouterr().out == ""


def test_server_errors_are_logged_as_errors():
    entry = request_log.build_entry("GET", "/x", 502, 12.345)
    assert entry == {
        "severity": "ERROR",
        "message": "GET /x 502 12.35ms",
        "method": "GET",
        "path": "/x",
        "status": 502,
        "latency_ms": 12.35,
    }
