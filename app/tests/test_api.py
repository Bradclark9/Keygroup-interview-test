def test_healthz(client):
    res = client.get("/healthz")
    assert res.status_code == 200
    assert res.text == "ok"


def test_get_file_success(client):
    res = client.get("/v1/users/user-1/files/profile.json")
    assert res.status_code == 200
    assert res.content == b'{"name":"Ada"}'
    assert res.headers["content-type"] == "application/json"


def test_get_file_not_found(client):
    res = client.get("/v1/users/user-1/files/missing.json")
    assert res.status_code == 404


def test_path_traversal_rejected(client):
    res = client.get("/v1/users/user-1/files/..%2Fsecrets")
    assert res.status_code in (400, 404, 422)